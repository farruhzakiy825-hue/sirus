import json,sys,html
d=json.load(open(sys.argv[1])); out=sys.argv[2]
bars=d['bars']; objs=d['objs']
W,H=1100,620; L,R,T,B=10,330,20,30
t0=bars[0][0]; tN=d['now']+14*300
lo=min(b[3] for b in bars); hi=max(b[2] for b in bars)
for o in objs:
  if o['ty'] in (1,2,3) and t0<=max(o['t1'],o['t2']):
    for p in (o['p1'],o['p2'] if o['ty']!=3 else o['p1']):
      if abs(p-(lo+hi)/2) < (hi-lo)*1.5: lo=min(lo,p); hi=max(hi,p)
pad=(hi-lo)*0.05; lo-=pad; hi+=pad
X=lambda t: L+(t-t0)/(tN-t0)*(W-L-R)
Y=lambda p: T+(hi-p)/(hi-lo)*(H-T-B)
s=[f'<rect width="{W}" height="{H}" fill="#11151c"/>']
col={'org':'#888','him':'#dc143c','tgt':'#1e90ff','gold':'#3c3419','deep':'#2d2346','pl_':'#4682b4','zn_':'#552828'}
def c_of(n):
  for k,v in col.items():
    if k in n: return v
  return '#aaa'
for o in objs:
  n=o['n']
  if o['ty']==2:
    x1,x2=sorted([X(max(o['t1'],t0)),X(o['t2'])]); y1,y2=sorted([Y(o['p1']),Y(o['p2'])])
    fill = '#3c3419' if 'gold' in n else ('#2d2346' if 'deep' in n else ('#5a2525' if 'zn_' in n else '#333'))
    if 'zn_' in n:
      fill = '#5a2525' if o['tx']=='' else fill
    s.append(f'<rect x="{x1}" y="{y1}" width="{max(1,x2-x1)}" height="{max(1,y2-y1)}" fill="{fill}" opacity="0.8"/>')
for i,b in enumerate(bars):
  t,o_,h,l,c=b; cx=X(t+150); w=(X(300)-X(0))*0.6; colr='#3cb371' if c>=o_ else '#e5675e'
  s.append(f'<line x1="{cx}" x2="{cx}" y1="{Y(h)}" y2="{Y(l)}" stroke="{colr}"/>')
  s.append(f'<rect x="{cx-w/2}" y="{Y(max(o_,c))}" width="{w}" height="{max(1,abs(Y(o_)-Y(c)))}" fill="{colr}"/>')
for o in objs:
  n=o['n']
  if o['ty']==1:
    x1=X(max(o['t1'],t0)); x2=X(o['t2'])
    dash='4 3' if ('tgt' in n or 'pl_' in n) else ('2 3' if 'org' in n else '')
    sw = 2.5 if 'H1_' in n else 1.5
    s.append(f'<line x1="{x1}" x2="{x2}" y1="{Y(o["p1"])}" y2="{Y(o["p1"])}" stroke="{c_of(n)}" stroke-width="{sw}" stroke-dasharray="{dash}"/>')
  if o['ty']==3:
    s.append(f'<text x="{X(o["t1"])+3}" y="{Y(o["p1"])+4}" fill="{c_of(n)}" font-size="11" font-family="sans-serif">{html.escape(o["tx"])}</text>')
s.append(f'<line x1="{L}" x2="{W-R}" y1="{Y(d["bid"])}" y2="{Y(d["bid"])}" stroke="#fff" stroke-width="0.5" stroke-dasharray="1 2"/>')
panel=[o['tx'] for o in sorted([o for o in objs if o['ty']==4], key=lambda o:int(o['n'].split('_')[-1]))]
ph=18*len(panel)+10
s2=[f'<rect width="{W}" height="{ph}" fill="#0b0e13"/>']+[f'<text x="10" y="{18*(i+1)}" fill="#e6e8ec" font-size="13" font-family="sans-serif">{html.escape(t)}</text>' for i,t in enumerate(panel)]
svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H+ph}"><g>{"".join(s2)}</g><g transform="translate(0,{ph})">{"".join(s)}</g></svg>'
open(out,'w').write(f'<!doctype html><html><body style="margin:0;background:#11151c">{svg}</body></html>')
