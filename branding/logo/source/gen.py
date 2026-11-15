# Geometry generator for Direction B explorations (512 canvas)
BG="#051424"
def line_x(p, q, y):  # x on line pq at y
    (x1,y1),(x2,y2)=p,q
    return x1+(x2-x1)*(y-y1)/(y2-y1)
def inter_chev(p,q,yc,s,side):  # intersect line pq with chevron y=yc+s*|x-256| on side (-1 left,+1 right)
    (x1,y1),(x2,y2)=p,q
    # param t: x=x1+t(x2-x1), y=y1+t(y2-y1); y=yc+s*side*(x-256)
    t=(yc+s*side*(x1-256)-y1)/((y2-y1)-s*side*(x2-x1))
    return (x1+t*(x2-x1), y1+t*(y2-y1))
def pts(ps): return " ".join(f"{x:.1f},{y:.1f}" for x,y in ps)
def mirror(ps): return [(512-x,y) for x,y in ps]

def base(apex=80, foot=432, outer=96, leg=80, c1=176, gap=28, s=0.55):
    A=(256,apex); OL=(outer,foot); IL=(outer+leg,foot)
    # inner line parallel to outer through IL
    dx=(256-outer)/(foot-apex)
    inner_apex_y = foot-(256-(outer+leg))/dx
    IA=(256,inner_apex_y)
    peakL=[A, inter_chev(A,OL,c1,s,-1), (256,c1)]
    bodyL=[(256,c1+gap), inter_chev(A,OL,c1+gap,s,-1), OL, IL, IA]
    return dict(A=A,OL=OL,IL=IL,IA=IA,peakL=peakL,bodyL=bodyL,dx=dx,foot=foot)

def svg(inner, defs=""):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512"><defs>{defs}</defs><rect width="512" height="512" fill="{BG}"/>{inner}</svg>'

# 1. Ascent Prism (refined B, faceted legs)
g=base()
def leg_split(bodyL):
    top_c, top_o, OL, IL, IA = bodyL
    midtop=((top_c[0]+top_o[0])/2,(top_c[1]+top_o[1])/2)
    midfoot=((OL[0]+IL[0])/2, OL[1])
    outer=[top_o, OL, midfoot, midtop]
    inner=[top_c, midtop, midfoot, IL, IA]
    return outer, inner
oL,iL=leg_split(g['bodyL'])
c1 = (f'<polygon points="{pts(g["peakL"])}" fill="#818CF8"/><polygon points="{pts(mirror(g["peakL"]))}" fill="#38BDF8"/>'
      f'<polygon points="{pts(oL)}" fill="#818CF8"/><polygon points="{pts(iL)}" fill="#6366F1"/>'
      f'<polygon points="{pts(mirror(oL))}" fill="#7DD3FC"/><polygon points="{pts(mirror(iL))}" fill="#0EA5E9"/>')
open("1_ascent_prism.svg","w").write(svg(c1))

# 2. Rank (stacked chevrons = discipline insignia + level up)
g2=base(apex=64, foot=448, outer=92, leg=84, c1=136, gap=20)
A,OL=g2['A'],g2['OL']
chevL=[(256,156), inter_chev(A,OL,156,0.55,-1), inter_chev(A,OL,196,0.55,-1), (256,196)]
bodyL=[(256,216), inter_chev(A,OL,216,0.55,-1), OL, g2['IL'], g2['IA']]
c2=(f'<polygon points="{pts(g2["peakL"])}" fill="#6366F1"/><polygon points="{pts(mirror(g2["peakL"]))}" fill="#38BDF8"/>'
    f'<polygon points="{pts(chevL)}" fill="#6366F1"/><polygon points="{pts(mirror(chevL))}" fill="#38BDF8"/>'
    f'<polygon points="{pts(bodyL)}" fill="#6366F1"/><polygon points="{pts(mirror(bodyL))}" fill="#38BDF8"/>')
open("2_rank.svg","w").write(svg(c2))

# 3. Kinetic split (vertical axis as negative cut, right half steps up)
off=26; half=7
L1=[(x-half,y) for x,y in g['peakL']]; L2=[(x-half,y) for x,y in g['bodyL']]
R1=[(x+half,y-off) for x,y in mirror(g['peakL'])]; R2=[(x+half,y-off) for x,y in mirror(g['bodyL'])]
c3=(f'<g transform="translate(0,13)"><polygon points="{pts(L1)}" fill="#6366F1"/><polygon points="{pts(L2)}" fill="#6366F1"/>'
    f'<polygon points="{pts(R1)}" fill="#38BDF8"/><polygon points="{pts(R2)}" fill="#38BDF8"/></g>')
open("3_kinetic.svg","w").write(svg(c3))

# 4. Dawn Summit (rising sun in the counter: daily cadence, fajr, new day)
sun=('<clipPath id="hz"><rect x="0" y="0" width="512" height="432"/></clipPath>'
     '<linearGradient id="sun" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FBBF24"/><stop offset="1" stop-color="#F59E0B"/></linearGradient>')
c4=(f'<polygon points="{pts(g["peakL"])}" fill="#6366F1"/><polygon points="{pts(mirror(g["peakL"]))}" fill="#38BDF8"/>'
    f'<polygon points="{pts(g["bodyL"])}" fill="#6366F1"/><polygon points="{pts(mirror(g["bodyL"]))}" fill="#38BDF8"/>'
    f'<circle cx="256" cy="432" r="46" fill="url(#sun)" clip-path="url(#hz)"/>')
open("4_dawn.svg","w").write(svg(c4, sun))
