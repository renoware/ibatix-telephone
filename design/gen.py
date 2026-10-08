import sys, os
D=sys.argv[1]
R,r=67,4
PHONE="M231.88,175.08A56.26,56.26,0,0,1,176,224C96.6,224,32,159.4,32,80A56.26,56.26,0,0,1,80.92,24.12a16,16,0,0,1,16.62,9.52l21.12,47.15,0,.12A16,16,0,0,1,117.39,96c-.18.27-.37.52-.57.77L96,121.45c7.49,15.22,23.41,31,38.83,38.51l24.34-20.71a8.12,8.12,0,0,1,.75-.56,16,16,0,0,1,15.17-1.4l.13.06,47.11,21.11A16,16,0,0,1,231.88,175.08Z"

def logo(c):
    """Logo ibatix redessiné sur la grille 300 (mesures prises sur le PNG d'origine).
    c = couleurs {haut, droite, bas, crayon, mine, pointe}"""
    return f'''
  <path fill="{c['haut']}" d="M28,68 V{R} A{R},{R} 0 0 1 {28+R},0 H160 A{r},{r} 0 0 1 164,{r} V64 A{r},{r} 0 0 1 160,68 Z"/>
  <path fill="{c['droite']}" d="M204,{r} A{r},{r} 0 0 1 {204+r},0 H{271-R} A{R},{R} 0 0 1 271,{R} V133 A{r},{r} 0 0 1 267,137 H{204+r} A{r},{r} 0 0 1 204,133 Z"/>
  <path fill="{c['bas']}" d="M136,{170+r} A{r},{r} 0 0 1 {136+r},170 H267 A{r},{r} 0 0 1 271,{170+r} V{238-R} A{R},{R} 0 0 1 {271-R},238 H{136+r} A{r},{r} 0 0 1 136,{238-r} Z"/>
  <rect fill="{c['crayon']}" x="28" y="102" width="67" height="121" rx="{r}"/>
  <path fill="{c['mine']}" d="M28,246 H95 L61.5,300 Z"/>
  <path fill="{c['pointe']}" d="M46.0,275 H77.0 L61.5,300 Z"/>'''

COUL={'haut':'#063017','droite':'#00A653','bas':'#008D40','crayon':'#F8B31F','mine':'#F9CF85','pointe':'#0C0C0C'}
BLANC=dict(COUL, haut='#FFFFFF')

def logo_seul():
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="28 0 243 300" width="729" height="900">{logo(COUL)}</svg>'

def badge(cx,cy,rad,fond,glyphe,anneau=None,ep=0):
    s=''
    if anneau: s+=f'<circle cx="{cx}" cy="{cy}" r="{rad+ep}" fill="{anneau}"/>'
    s+=f'<circle cx="{cx}" cy="{cy}" r="{rad}" fill="{fond}"/>'
    k=rad*1.1/256
    s+=f'<g transform="translate({cx-128*k},{cy-128*k}) scale({k})"><path fill="{glyphe}" d="{PHONE}"/></g>'
    return s

def icone(fond_defs, fond, couleurs, logo_h, cx, cy, bad):
    k=logo_h/300; w=243*k
    x=cx-w/2-28*k; y=cy-logo_h/2
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs>{fond_defs}</defs><rect width="1024" height="1024" fill="{fond}"/>
<g transform="translate({x:.2f},{y:.2f}) scale({k:.5f})">{logo(couleurs)}</g>{bad}</svg>'''

V={}
# A : clair, logo couleur, pastille verte détourée
V['a']=icone('<linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#EAF6EF"/></linearGradient>',
  'url(#g)', COUL, 560, 492, 500, badge(712,712,128,'#00A653','#FFFFFF','#FFFFFF',22))
# B : sombre, bloc haut en blanc, pastille verte
V['b']=icone('<linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#0B3D20"/><stop offset="1" stop-color="#04210F"/></linearGradient>',
  'url(#g)', BLANC, 560, 492, 500, badge(712,712,128,'#00A653','#FFFFFF','#06301A',22))
# C : vert ibatix, combiné blanc en grand, logo réduit en blanc-crème
VERT_MONO={k:'#FFFFFF' for k in COUL}; VERT_MONO['pointe']='#00A653'
c_logo=f'<g transform="translate({512-243*0.62/2-28*0.62:.2f},150) scale(0.62)" opacity="0.95">{logo(dict(COUL,haut="#FFFFFF"))}</g>'
k=430/256
V['c']=f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#00B35A"/><stop offset="1" stop-color="#008D40"/></linearGradient></defs>
<rect width="1024" height="1024" fill="url(#g)"/>
<rect x="232" y="232" width="560" height="560" rx="150" fill="#063017"/>
<g transform="translate({512-243*1.55/2-28*1.55:.2f},{512-300*1.55/2:.2f}) scale(1.55)">{logo(BLANC)}</g>
</svg>'''
for n,s in V.items(): open(os.path.join(D,f'icone-{n}.svg'),'w').write(s)
open(os.path.join(D,'logo-ibatix.svg'),'w').write(logo_seul())
