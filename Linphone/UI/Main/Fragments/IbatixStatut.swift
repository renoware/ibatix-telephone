// ibatix : pastille d'état (Disponible / Ne pas déranger / Renvoi) sur l'avatar de l'en-tête.
// Le statut vit dans Odoo (celui que règle l'écran Standard) : l'app le lit et le change par
// <odoo_url>/telephonie/app/statut avec la clé personnelle remise par le QR code ([ibatix] cle).

import SwiftUI
import linphonesw

struct IbatixCollegue: Decodable, Identifiable {
	let id: Int
	let nom: String
	let poste: String
	let statut: String
	let libelle: String
}

private struct IbatixEtat: Decodable {
	let ok: Bool?
	let error: String?
	let statut: String?
	let libelle: String?
	let renvoi_user_id: IbatixEntierOuFaux?
	let fin_journee: IbatixTexteOuFaux?
	let collegues: [IbatixCollegue]?
}

// Odoo renvoie false à la place d'une valeur absente
private struct IbatixEntierOuFaux: Decodable {
	let valeur: Int?
	init(from decoder: Decoder) throws {
		valeur = try? decoder.singleValueContainer().decode(Int.self)
	}
}

private struct IbatixTexteOuFaux: Decodable {
	let valeur: String?
	init(from decoder: Decoder) throws {
		valeur = try? decoder.singleValueContainer().decode(String.self)
	}
}

@MainActor
final class IbatixStatutModel: ObservableObject {
	static let shared = IbatixStatutModel()

	@Published var configure = false
	@Published var statut = "dispo"
	@Published var libelle = ""
	@Published var renvoiUserId: Int?
	@Published var finJournee: String?
	@Published var collegues: [IbatixCollegue] = []
	@Published var enCours = false
	@Published var erreur: String?

	private(set) var odooUrl = ""
	private(set) var cle = ""

	static func couleur(_ statut: String) -> Color {
		switch statut {
		case "dnd": return Color.orangeAway
		case "renvoi": return Color.blueInfo500
		default: return Color.greenSuccess500
		}
	}

	/// Lit odoo_url et la clé dans la configuration Linphone (posées par le QR), puis le statut.
	func rafraichir() {
		CoreContext.shared.doOnCoreQueue { core in
			let url = core.config?.getString(section: "ibatix", key: "odoo_url", defaultString: "") ?? ""
			let cle = core.config?.getString(section: "ibatix", key: "cle", defaultString: "") ?? ""
			Task { @MainActor in
				self.odooUrl = url.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
				self.cle = cle
				self.configure = !self.odooUrl.isEmpty && !cle.isEmpty
				if self.configure {
					IbatixCorrespondantsModel.shared.relancer()
					await self.envoyer(nil)
				}
			}
		}
	}

	func poser(_ corps: [String: Any]) {
		Task { await envoyer(corps) }
	}

	private func envoyer(_ corps: [String: Any]?) async {
		guard configure, let url = URL(string: odooUrl + "/telephonie/app/statut") else { return }
		var requete = URLRequest(url: url, timeoutInterval: 10)
		requete.setValue("Bearer " + cle, forHTTPHeaderField: "Authorization")
		if let corps = corps {
			requete.httpMethod = "POST"
			requete.setValue("application/json", forHTTPHeaderField: "Content-Type")
			requete.httpBody = try? JSONSerialization.data(withJSONObject: corps)
		}
		enCours = true
		defer { enCours = false }
		do {
			let (data, reponse) = try await URLSession.shared.data(for: requete)
			let code = (reponse as? HTTPURLResponse)?.statusCode ?? 0
			let etat = try? JSONDecoder().decode(IbatixEtat.self, from: data)
			if code == 401 {
				erreur = String(localized: "ibatix_statut_cle_refusee")
				return
			}
			guard code == 200, let etat = etat, let statut = etat.statut else {
				erreur = etat?.error ?? String(localized: "ibatix_statut_erreur")
				return
			}
			erreur = nil
			self.statut = statut
			libelle = etat.libelle ?? ""
			renvoiUserId = etat.renvoi_user_id?.valeur
			finJournee = etat.fin_journee?.valeur
			collegues = etat.collegues ?? []
		} catch {
			erreur = String(localized: "ibatix_statut_erreur")
			Log.warn("[ibatix] statut : \(error.localizedDescription)")
		}
	}
}

/// Pastille ronde posée sur l'avatar de l'en-tête.
struct IbatixPastille: View {
	@ObservedObject var modele = IbatixStatutModel.shared
	var taille: CGFloat

	var body: some View {
		if modele.configure {
			Circle()
				.fill(IbatixStatutModel.couleur(modele.statut))
				.frame(width: taille, height: taille)
				.overlay(Circle().stroke(Color.white, lineWidth: 2))
				.accessibilityLabel(modele.libelle)
		}
	}
}

/// Feuille « Mon statut » ouverte en touchant l'avatar.
struct IbatixStatutFeuille: View {
	@ObservedObject var modele = IbatixStatutModel.shared
	@Environment(\.dismiss) private var fermer
	@State private var choixRenvoi = false

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("ibatix_statut_titre")
				.default_text_style_800(styleSize: 20)
			if !modele.libelle.isEmpty {
				Text(modele.libelle)
					.default_text_style(styleSize: 14)
					.foregroundStyle(Color.grayMain2c500)
			}

			if choixRenvoi {
				listeCollegues
			} else {
				options
			}

			if let erreur = modele.erreur {
				Text(erreur)
					.default_text_style(styleSize: 13)
					.foregroundStyle(Color.redDanger500)
			}
			Spacer(minLength: 0)
		}
		.padding(20)
		.overlay(alignment: .topTrailing) {
			if modele.enCours {
				ProgressView().padding(20)
			}
		}
		.onAppear { modele.rafraichir() }
	}

	private var options: some View {
		VStack(spacing: 8) {
			ligne(statut: "dispo", titre: String(localized: "ibatix_statut_dispo"),
				  detail: String(localized: "ibatix_statut_dispo_detail")) {
				modele.poser(["statut": "dispo"]); fermer()
			}
			ligne(statut: "dnd", titre: String(localized: "ibatix_statut_dnd_heure"),
				  detail: String(localized: "ibatix_statut_dnd_detail")) {
				modele.poser(["statut": "dnd", "heures": 1]); fermer()
			}
			if let fin = modele.finJournee {
				ligne(statut: "dnd", titre: String(format: String(localized: "ibatix_statut_dnd_soir"), fin),
					  detail: String(localized: "ibatix_statut_dnd_detail")) {
					modele.poser(["statut": "dnd", "fin_journee": true]); fermer()
				}
			}
			ligne(statut: "dnd", titre: String(localized: "ibatix_statut_dnd_sans_fin"),
				  detail: String(localized: "ibatix_statut_dnd_detail")) {
				modele.poser(["statut": "dnd"]); fermer()
			}
			ligne(statut: "renvoi", titre: String(localized: "ibatix_statut_renvoi"),
				  detail: String(localized: "ibatix_statut_renvoi_detail"), chevron: true) {
				withAnimation { choixRenvoi = true }
			}
		}
	}

	private var listeCollegues: some View {
		VStack(alignment: .leading, spacing: 8) {
			Button {
				withAnimation { choixRenvoi = false }
			} label: {
				Label(String(localized: "ibatix_statut_retour"), systemImage: "chevron.left")
					.default_text_style_600(styleSize: 15)
			}
			if modele.collegues.isEmpty {
				Text("ibatix_statut_aucun_collegue")
					.default_text_style(styleSize: 14)
			}
			ScrollView {
				VStack(spacing: 8) {
					ForEach(modele.collegues) { c in
						ligne(statut: c.statut, titre: c.nom, detail: String(format: String(localized: "ibatix_statut_poste"), c.poste, c.libelle),
							  coche: modele.statut == "renvoi" && modele.renvoiUserId == c.id) {
							modele.poser(["statut": "renvoi", "renvoi_user_id": c.id]); fermer()
						}
					}
				}
			}
		}
	}

	private func ligne(statut: String, titre: String, detail: String, coche: Bool? = nil,
					   chevron: Bool = false, action: @escaping () -> Void) -> some View {
		let actif = coche ?? (modele.statut == statut && !chevron && statut == "dispo")
		return Button(action: action) {
			HStack(spacing: 12) {
				Circle()
					.fill(IbatixStatutModel.couleur(statut))
					.frame(width: 12, height: 12)
				VStack(alignment: .leading, spacing: 2) {
					Text(titre)
						.default_text_style_600(styleSize: 15)
						.multilineTextAlignment(.leading)
					Text(detail)
						.default_text_style(styleSize: 12.5)
						.foregroundStyle(Color.grayMain2c500)
						.multilineTextAlignment(.leading)
						.fixedSize(horizontal: false, vertical: true)
				}
				Spacer()
				if actif {
					Image(systemName: "checkmark").foregroundStyle(Color.orangeMain500)
				} else if chevron {
					Image(systemName: "chevron.right").foregroundStyle(Color.grayMain2c400)
				}
			}
			.padding(.vertical, 12)
			.padding(.horizontal, 14)
			.background(RoundedRectangle(cornerRadius: 12).fill(actif ? Color.orangeMain100 : Color.gray100))
		}
		.buttonStyle(.plain)
		.disabled(modele.enCours)
	}
}

// ibatix : Récents enrichis. Les numéros de l'historique sont envoyés à <odoo_url>/telephonie/app/correspondants
// (même clé que le statut) ; Odoo répond, aux droits du commercial, le nom et la piste en cours de chacun.
// Rien n'est écrit sur le téléphone : les fiches restent en mémoire et sont redemandées au retour au premier plan.

struct IbatixFiche: Decodable, Equatable {
	let type: String
	let nom: String
	let detail: String
}

private struct IbatixReponseCorrespondants: Decodable {
	let correspondants: [String: IbatixFiche]?
}

@MainActor
final class IbatixCorrespondantsModel: ObservableObject {
	static let shared = IbatixCorrespondantsModel()

	@Published private(set) var fiches: [String: IbatixFiche] = [:]
	private var demandes = Set<String>()
	private var derniers: [String] = []

	func fiche(_ numero: String?) -> IbatixFiche? {
		guard let numero = numero, !numero.isEmpty else { return nil }
		return fiches[numero]
	}

	/// Demande les numéros pas encore connus (100 au plus par envoi, la limite d'Odoo).
	func charger(_ numeros: [String]) {
		derniers = numeros
		var vus = Set<String>()
		let nouveaux = numeros.filter { !$0.isEmpty && !demandes.contains($0) && vus.insert($0).inserted }
		let statut = IbatixStatutModel.shared
		guard !nouveaux.isEmpty, statut.configure, let url = URL(string: statut.odooUrl + "/telephonie/app/correspondants") else { return }
		let lot = Array(nouveaux.prefix(100))
		demandes.formUnion(lot)
		var requete = URLRequest(url: url, timeoutInterval: 10)
		requete.httpMethod = "POST"
		requete.setValue("Bearer " + statut.cle, forHTTPHeaderField: "Authorization")
		requete.setValue("application/json", forHTTPHeaderField: "Content-Type")
		requete.httpBody = try? JSONSerialization.data(withJSONObject: ["numeros": lot])
		Task {
			do {
				let (data, reponse) = try await URLSession.shared.data(for: requete)
				guard (reponse as? HTTPURLResponse)?.statusCode == 200,
					  let recus = try JSONDecoder().decode(IbatixReponseCorrespondants.self, from: data).correspondants else {
					demandes.subtract(lot)
					return
				}
				fiches.merge(recus) { _, nouveau in nouveau }
				if nouveaux.count > lot.count {
					charger(derniers)
				}
			} catch {
				demandes.subtract(lot)
				Log.warn("[ibatix] correspondants : \(error.localizedDescription)")
			}
		}
	}

	/// Retour au premier plan ou clé enfin connue : tout redemander (noms et étapes ont pu changer).
	func relancer() {
		demandes.removeAll()
		charger(derniers)
	}
}
