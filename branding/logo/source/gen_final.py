import math, os
OUT=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)),"gen.py")).read().split('# 1. Ascent Prism')[0])
g=base(apex=72, foot=436, outer=92, leg=86, c1=170, gap=24)
tc,to,OL,IL,IA=g['bodyL']
mt=((tc[0]+to[0])/2,(tc[1]+to[1])/2); mf=((OL[0]+IL[0])/2,OL[1])
outerL=[to,OL,mf,mt]; innerL=[tc,mt,mf,IL,IA]
peakL=g['peakL']
# symbol bounds: x 92..420, y 72..436 -> width 328, height 364
SX,SY,SW,SH=92,72,328,364

PAL={
 'dark': dict(pk1="#FCD34D",pk2="#F59E0B",lo="#818CF8",li="#6366F1",ro="#7DD3FC",ri="#0EA5E9",text="#F8FAFC"),
 'light':dict(pk1="#F59E0B",pk2="#D97706",lo="#6366F1",li="#4F46E5",ro="#0EA5E9",ri="#0284C7",text="#051424"),
}
def symbol(p, mono=None, flat=False):
    if mono:
        return (f'<g fill="{mono}"><polygon points="{pts(peakL)}"/><polygon points="{pts(mirror(peakL))}"/>'
                f'<polygon points="{pts(g["bodyL"])}"/><polygon points="{pts(mirror(g["bodyL"]))}"/></g>')
    if flat:
        return (f'<polygon points="{pts(peakL)}" fill="{p["pk1"]}"/><polygon points="{pts(mirror(peakL))}" fill="{p["pk2"]}"/>'
                f'<polygon points="{pts(g["bodyL"])}" fill="{p["li"]}"/><polygon points="{pts(mirror(g["bodyL"]))}" fill="{p["ri"]}"/>')
    return (f'<g id="peak"><polygon points="{pts(peakL)}" fill="{p["pk1"]}"/><polygon points="{pts(mirror(peakL))}" fill="{p["pk2"]}"/></g>'
            f'<g id="body"><polygon points="{pts(outerL)}" fill="{p["lo"]}"/><polygon points="{pts(innerL)}" fill="{p["li"]}"/>'
            f'<polygon points="{pts(mirror(outerL))}" fill="{p["ro"]}"/><polygon points="{pts(mirror(innerL))}" fill="{p["ri"]}"/></g>')

# ---- custom wordmark (cap height 100, stroke 18) ----
T=18
def wm_A(x0):
    w=T/math.cos(math.atan(0.5)); W=100
    ia=100-((W/2-w)/0.5)
    return f'<polygon points="{pts([(x0+50,0),(x0+W,100),(x0+W-w,100),(x0+50,ia),(x0+w,100),(x0,100)])}"/>', W
def wm_X(x0):
    W=86; s=W/100; w=T/math.cos(math.atan(s))
    b1=[(x0,0),(x0+w,0),(x0+W,100),(x0+W-w,100)]
    b2=[(x0+W,0),(x0+W-w,0),(x0,100),(x0+w,100)]
    return f'<polygon points="{pts(b1)}"/><polygon points="{pts(b2)}"/>', W
def wm_I(x0):
    return f'<rect x="{x0}" y="0" width="{T}" height="100"/>', T
def wm_S(x0):
    TS=17; ry1,ry2=19.5,100/2-TS/2-19.5
    rx1,rx2=28,31; cx=x0+38
    c1y=TS/2+ry1; c2y=100-TS/2-ry2
    a=math.radians(-30); sx,sy=cx+rx1*math.cos(a), c1y+ry1*math.sin(a)
    b=math.radians(150); ex,ey=cx+rx2*math.cos(b), c2y+ry2*math.sin(b)
    d=f"M{sx:.1f},{sy:.1f} A{rx1},{ry1} 0 1,0 {cx},{c1y+ry1:.1f} A{rx2},{ry2} 0 1,1 {ex:.1f},{ey:.1f}"
    return f'<path d="{d}" fill="none" stroke="currentColor" stroke-width="{TS}" stroke-linecap="butt"/>', 76
def wordmark(color, track=30):
    x=0; parts=[]
    for f in (wm_A,wm_X,wm_I,wm_S):
        s,w=f(x); parts.append(s); x+=w+track
    return f'<g fill="{color}" color="{color}">{"".join(parts)}</g>', x-track
WM_W=wordmark("#000")[1]

def doc(vb, body, title, desc, bg=None):
    bgr=f'<rect x="{vb[0]}" y="{vb[1]}" width="{vb[2]}" height="{vb[3]}" fill="{bg}"/>' if bg else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{" ".join(str(round(v,1)) for v in vb)}" role="img" aria-labelledby="t d">'
            f'<title id="t">{title}</title><desc id="d">{desc}</desc>{bgr}{body}</svg>\n')
DESC="AXIS North Star mark: a faceted indigo and cyan A-shaped summit with a detached amber peak above it."
def save(name, s): open(os.path.join(OUT,name),"w").write(s)

pad=24
# icon only
for k in ('dark','light'):
    save(f"axis-icon-{'on-dark' if k=='dark' else 'on-light'}.svg", doc((SX-pad,SY-pad,SW+2*pad,SH+2*pad), symbol(PAL[k]), "AXIS icon", DESC))
save("axis-icon-mono-white.svg", doc((SX-pad,SY-pad,SW+2*pad,SH+2*pad), symbol(None,"#FFFFFF"), "AXIS icon (white)", DESC))
save("axis-icon-mono-obsidian.svg", doc((SX-pad,SY-pad,SW+2*pad,SH+2*pad), symbol(None,"#051424"), "AXIS icon (obsidian)", DESC))

# app icon, full bleed (OS applies its own mask)
save("axis-app-icon.svg", doc((0,0,512,512), symbol(PAL['dark']), "AXIS app icon", DESC, bg="#051424"))
# favicon / small sizes: flat facets, mark scaled up slightly for 16-32px
fav=f'<g transform="translate(256 262) scale(1.12) translate(-256 -254)">{symbol(PAL["dark"],flat=True)}</g>'
save("axis-favicon.svg", doc((0,0,512,512), f'<rect width="512" height="512" rx="112" fill="#051424"/>{fav}', "AXIS favicon", DESC))
# android adaptive foreground (mark inside the 66% safe zone) + monochrome themed icon
fg=f'<g transform="translate(256 256) scale(0.62) translate(-256 -254)">{symbol(PAL["dark"])}</g>'
save("axis-android-adaptive-foreground.svg", doc((0,0,512,512), fg, "AXIS adaptive icon foreground", DESC))
save("axis-android-adaptive-background.svg", doc((0,0,512,512), "", "AXIS adaptive icon background", "Obsidian background", bg="#051424"))
mfg=f'<g transform="translate(256 256) scale(0.62) translate(-256 -254)">{symbol(None,"#FFFFFF")}</g>'
save("axis-android-monochrome.svg", doc((0,0,512,512), mfg, "AXIS themed / notification icon", DESC))

# lockups: symbol height 364 -> wordmark cap height = 0.42 * symbol height
def horizontal(k, mono=None):
    p=PAL[k]; col=mono or p['text']
    sc=160/100  # wordmark cap height 160, baseline on the symbol's feet
    gapx=96
    wm,_=wordmark(col)
    wx=SX+SW+gapx; wy=SY+SH-150-(SH-150)/2*0.0 - (SH-150)/2  # vertically centred on symbol
    wy=SY+SH-160
    body=symbol(p, mono) + f'<g transform="translate({wx} {wy}) scale({sc})">{wm}</g>'
    W=SW+gapx+WM_W*sc
    return doc((SX-pad*2,SY-pad*2,W+pad*4,SH+pad*4), body, "AXIS logo (horizontal)", DESC)
def vertical(k, mono=None):
    p=PAL[k]; col=mono or p['text']; sc=1.1
    wm,_=wordmark(col); ww=WM_W*sc
    wx=256-ww/2; wy=SY+SH+80
    body=symbol(p, mono)+f'<g transform="translate({wx} {wy}) scale({sc})">{wm}</g>'
    x0=min(SX,wx); W=max(SW,ww)
    return doc((x0-pad*2,SY-pad*2,W+pad*4,SH+80+110+pad*4), body, "AXIS logo (vertical)", DESC)
save("axis-logo-horizontal-on-dark.svg", horizontal('dark'))
save("axis-logo-horizontal-on-light.svg", horizontal('light'))
save("axis-logo-horizontal-mono-white.svg", horizontal('dark',"#FFFFFF"))
save("axis-logo-horizontal-mono-obsidian.svg", horizontal('light',"#051424"))
save("axis-logo-vertical-on-dark.svg", vertical('dark'))
save("axis-logo-vertical-on-light.svg", vertical('light'))
for k,c in (('on-dark',"#F8FAFC"),('on-light',"#051424")):
    wm,_=wordmark(c); save(f"axis-wordmark-{k}.svg", doc((-20,-20,WM_W+40,140), wm, "AXIS wordmark", "Custom geometric AXIS wordmark"))
print("ok", WM_W)
