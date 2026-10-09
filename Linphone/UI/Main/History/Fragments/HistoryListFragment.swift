/*
 * Copyright (c) 2010-2023 Belledonne Communications SARL.
 *
 * This file is part of linphone-iphone
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

// swiftlint:disable line_length

import SwiftUI
import linphonesw

struct HistoryListFragment: View {
	
	@ObservedObject var contactsManager = ContactsManager.shared
	@ObservedObject private var telecomManager = TelecomManager.shared
	
	@EnvironmentObject var historyListViewModel: HistoryListViewModel
	
	@Binding var showingSheet: Bool
	@Binding var text: String
	
	// ibatix : filtre Tous / Manqués et fiches Odoo des correspondants
	@ObservedObject private var ibatixCorrespondants = IbatixCorrespondantsModel.shared
	@State private var ibatixManquesSeuls = false
	
	private var ibatixAppels: [HistoryModel] {
		historyListViewModel.callLogs.filter { !ibatixManquesSeuls || ($0.status == .Missed && !$0.isOutgoing) }
	}
	
	var body: some View {
		VStack {
			Picker("", selection: $ibatixManquesSeuls) {
				Text("ibatix_recents_tous").tag(false)
				Text("ibatix_recents_manques").tag(true)
			}
			.pickerStyle(.segmented)
			.padding(.horizontal, 20)
			.padding(.top, 12)
			
			List {
				ForEach(ibatixAppels) { historyModel in
					HistoryRow(historyModel: historyModel, showingSheet: $showingSheet)
				}
				
				if !historyListViewModel.callLogsFilter.isEmpty {
					if !contactsManager.lastSearch.isEmpty {
						HStack(alignment: .center) {
							Text("contacts_list_all_contacts_title")
								.default_text_style_800(styleSize: 16)
							
							Spacer()
						}
					}
					
					ContactsListFragment(showingSheet: .constant(false), startCallFunc: { addr in
						withAnimation {
							telecomManager.doCallOrJoinConf(address: addr)
						}
					})
					
					if !contactsManager.lastSearchSuggestions.isEmpty {
						HStack(alignment: .center) {
							Text("generic_address_picker_suggestions_list_title")
								.default_text_style_800(styleSize: 16)
							
							Spacer()
						}
						
						suggestionsList
					}
				}
			}
			.safeAreaInset(edge: .top, content: {
				Spacer()
					.frame(height: 12)
			})
			.listStyle(.plain)
			.overlay(
				VStack {
					if ibatixAppels.isEmpty &&
						(
							historyListViewModel.callLogsFilter.isEmpty ||
							(!historyListViewModel.callLogsFilter.isEmpty &&
							 contactsManager.lastSearch.isEmpty &&
							 contactsManager.lastSearchSuggestions.isEmpty)
						) {
						Spacer()
						Image("illus-belledonne")
							.resizable()
							.scaledToFit()
							.clipped()
							.padding(.all)
						Text(!text.isEmpty ? "list_filter_no_result_found" : "history_list_empty_history")
							.default_text_style_800(styleSize: 16)
							.multilineTextAlignment(.center)
						Spacer()
						Spacer()
					}
				}
					.padding(.all)
			)
			.onDisappear {
				if !historyListViewModel.callLogsFilter.isEmpty {
					historyListViewModel.resetFilterCallLogs()
				}
			}
			.task(id: historyListViewModel.callLogs.count) {
				ibatixCorrespondants.charger(historyListViewModel.callLogs.compactMap { $0.isConf ? nil : $0.addressLinphone.username })
			}
		}
		.navigationTitle("")
		.navigationBarHidden(true)
	}
	
	var suggestionsList: some View {
		ForEach(0..<contactsManager.lastSearchSuggestions.count, id: \.self) { index in
			Button {
				if let address = contactsManager.lastSearchSuggestions[index].address {
					withAnimation {
						telecomManager.doCallOrJoinConf(address: address)
					}
				}
			} label: {
				HStack {
					if index < contactsManager.lastSearchSuggestions.count
						&& contactsManager.lastSearchSuggestions[index].address != nil {
						if contactsManager.lastSearchSuggestions[index].address!.domain != AppServices.corePreferences.defaultDomain {
							Image(uiImage: contactsManager.textToImage(
								firstName: String(contactsManager.lastSearchSuggestions[index].address!.asStringUriOnly().dropFirst(4)),
								lastName: ""))
							.resizable()
							.frame(width: 45, height: 45)
							.clipShape(Circle())
							
							Text(String(contactsManager.lastSearchSuggestions[index].address!.asStringUriOnly().dropFirst(4)))
								.default_text_style(styleSize: 16)
								.lineLimit(1)
								.frame(maxWidth: .infinity, alignment: .leading)
								.foregroundStyle(Color.orangeMain500)
						} else {
							if let address = contactsManager.lastSearchSuggestions[index].address {
								let nameTmp = address.displayName
								?? address.username
								?? String(address.asStringUriOnly().dropFirst(4))
								
								Image(uiImage: contactsManager.textToImage(
									firstName: nameTmp,
									lastName: ""))
								.resizable()
								.frame(width: 45, height: 45)
								.clipShape(Circle())
								
								Text(nameTmp)
									.default_text_style(styleSize: 16)
									.lineLimit(1)
									.frame(maxWidth: .infinity, alignment: .leading)
									.foregroundStyle(Color.orangeMain500)
							}
						}
					} else {
						Image("profil-picture-default")
							.resizable()
							.frame(width: 45, height: 45)
							.clipShape(Circle())
						
						Text("username_error")
							.default_text_style(styleSize: 16)
							.frame(maxWidth: .infinity, alignment: .leading)
							.foregroundStyle(Color.orangeMain500)
					}
				}
			}
			.buttonStyle(.borderless)
			.listRowSeparator(.hidden)
		}
	}
}

struct HistoryRow: View {
	@ObservedObject var contactsManager = ContactsManager.shared
	@ObservedObject private var telecomManager = TelecomManager.shared
	
	@EnvironmentObject var historyListViewModel: HistoryListViewModel
	
	@ObservedObject var historyModel: HistoryModel
	@ObservedObject private var ibatixCorrespondants = IbatixCorrespondantsModel.shared
	
	@Binding var showingSheet: Bool
	
	// ibatix : nom et piste venus d'Odoo, sinon ce que Linphone connaît
	private var ibatixFiche: IbatixFiche? {
		historyModel.isConf ? nil : ibatixCorrespondants.fiche(historyModel.addressLinphone.username)
	}
	private var nomAffiche: String {
		if let fiche = ibatixFiche, fiche.type != "inconnu" || historyModel.avatarModel?.friend == nil {
			return fiche.nom
		}
		return historyModel.addressName
	}
	private var manque: Bool {
		historyModel.status == .Missed && !historyModel.isOutgoing
	}

	var body: some View {
		HStack {
			HStack {
				if !historyModel.isConf {
					if historyModel.avatarModel != nil && (ibatixFiche == nil || historyModel.avatarModel?.friend != nil) {
						Avatar(contactAvatarModel: historyModel.avatarModel!, avatarSize: 50)
					} else {
						if !nomAffiche.isEmpty {
							Image(uiImage: contactsManager.textToImage(
								firstName: nomAffiche,
								lastName: nomAffiche.components(separatedBy: " ").count > 1
								? nomAffiche.components(separatedBy: " ")[1]
								: ""))
							.resizable()
							.frame(width: 50, height: 50)
							.clipShape(Circle())
						} else {
							VStack {
								Image("profil-picture-default")
									.renderingMode(.template)
									.resizable()
									.frame(width: 28, height: 28)
									.foregroundStyle(Color.grayMain2c600)
							}
							.frame(width: 50, height: 50)
							.background(Color.grayMain2c200)
							.clipShape(Circle())
						}
					}
				} else {
					VStack {
						Image("video-conference")
							.renderingMode(.template)
							.resizable()
							.frame(width: 28, height: 28)
							.foregroundStyle(Color.grayMain2c600)
					}
					.frame(width: 50, height: 50)
					.background(Color.grayMain2c200)
					.clipShape(Circle())
				}
				
				VStack(spacing: 0) {
					Spacer()
					if !historyModel.isConf {
						Text(nomAffiche)
							.default_text_style(styleSize: 14)
							.foregroundStyle(manque ? Color.redDanger500 : Color.grayMain2c700)
							.frame(maxWidth: .infinity, alignment: .leading)
							.lineLimit(1)
						if let detail = ibatixFiche?.detail, !detail.isEmpty {
							Text(detail)
								.default_text_style_300(styleSize: 12)
								.frame(maxWidth: .infinity, alignment: .leading)
								.lineLimit(1)
						}
					} else {
						Text(historyModel.subject)
							.default_text_style(styleSize: 14)
							.frame(maxWidth: .infinity, alignment: .leading)
							.lineLimit(1)
					}
					
					HStack {
						Image(historyListViewModel.getCallIconResId(callStatus: historyModel.status, isOutgoing: historyModel.isOutgoing))
							.resizable()
							.frame(
								width: historyListViewModel.getCallIconResId(callStatus: historyModel.status, isOutgoing: historyModel.isOutgoing).contains("rejected") ? 12 : 8,
								height: historyListViewModel.getCallIconResId(callStatus: historyModel.status, isOutgoing: historyModel.isOutgoing).contains("rejected") ? 6 : 8)
						Text(historyListViewModel.getCallTime(startDate: historyModel.startDate))
							.default_text_style_300(styleSize: 12)
							.frame(maxWidth: .infinity, alignment: .leading)
						
						Spacer()
					}
					
					Spacer()
				}
				
				if !historyModel.isConf {
					Image("phone")
						.renderingMode(.template)
						.resizable()
						.frame(width: 25, height: 25)
						.foregroundStyle(Color.grayMain2c600)
						.padding(.all, 10)
						.padding(.trailing, 5)
						.highPriorityGesture(
							TapGesture()
								.onEnded { _ in
									withAnimation {
										doCall(historyModel: historyModel)
										SharedMainViewModel.shared.displayedCall = nil
									}
								}
						)
				}
			}
		}
		.frame(height: ibatixFiche?.detail.isEmpty == false ? 62 : 50)
		.buttonStyle(.borderless)
		.listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
		.listRowSeparator(.hidden)
		.background(.white)
		.onTapGesture {
			withAnimation {
				SharedMainViewModel.shared.displayedCall = historyModel
			}
		}
		.onLongPressGesture(minimumDuration: 0.2) {
			historyListViewModel.selectedCall = historyModel
			showingSheet.toggle()
		}
	}
	
	func doCall(historyModel: HistoryModel) {
		telecomManager.doCallOrJoinConf(address: historyModel.addressLinphone)
	}
}

#Preview {
	HistoryListFragment(showingSheet: .constant(false), text: .constant(""))
}

// swiftlint:enable line_length
