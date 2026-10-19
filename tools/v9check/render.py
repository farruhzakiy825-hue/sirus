# V9 chizmalarini (shim dagi obyektlar) HTML/SVG ga chiqaradi: shamlar, oyoq chiziqlari, panel, watermark.
import json, sys, html
d = json.load(open(sys.argv[1])); out = sys.argv[2]
W, H = 1400, 760
bars = d['bars']; objs = sorted(d['objs'], key=lambda o: o['seq'])
P = 300
t0 = bars[0][0]; tN = bars[-1][0] + 26 * P
lo, hi = d['cmin'], d['cmax']
pad = (hi - lo) * 0.08; lo -= pad; hi += pad
X = lambda t: (t - t0) / (tN - t0) * W
Y = lambda p: (hi - p) / (hi - lo) * H
def hexc(v):
    v = int(v); r = v & 255; g = (v >> 8) & 255; b = (v >> 16) & 255
    return '#%02x%02x%02x' % (r, g, b)
FONT = {'Bahnschrift SemiBold': "'Bahnschrift','Arial Narrow','DejaVu Sans Condensed',sans-serif;font-weight:600",
        'Bahnschrift Light': "'Bahnschrift','Arial Narrow','DejaVu Sans Condensed',sans-serif;font-weight:300",
        'Segoe UI': "'Segoe UI','Noto Sans','DejaVu Sans',sans-serif", 'Segoe UI Semibold': "'Segoe UI','Noto Sans','DejaVu Sans',sans-serif;font-weight:600",
        'Consolas': "'Consolas','DejaVu Sans Mono',monospace", 'Segoe UI Symbol': "'Segoe UI Symbol','DejaVu Sans',sans-serif"}
ANC = {1: ('start', 'hanging'), 2: ('end', 'hanging'), 3: ('middle', 'central'), 0: ('start', 'central'), 4: ('end', 'central')}
back, front, lines = [], [], []
def ip(o, k, dflt=0): return o['ip'].get(str(k), dflt)
# OBJPROP ids from shim enum order
SEL,HID,RAY,COL,STY,WID,BACK,FILL,ANCH,TXT,FNT,FSZ,CRN,XD,YD,BRD,XS,YS,BG = range(1,20)
for o in objs:
    ty = o['ty']
    if ty == 5:   # rectangle label
        el = f'<rect x="{ip(o,XD)}" y="{ip(o,YD)}" width="{ip(o,XS)}" height="{ip(o,YS)}" fill="{hexc(ip(o,BG))}" stroke="{hexc(ip(o,COL))}" stroke-width="1"/>'
        (back if ip(o,BACK) else front).append(el)
    elif ty == 4:   # label
        a = ANC.get(ip(o,ANCH), ('start','hanging')); f = FONT.get(o['sp'].get(str(FNT),'Segoe UI'), 'sans-serif')
        el = f'<text x="{ip(o,XD)}" y="{ip(o,YD)}" fill="{hexc(ip(o,COL))}" font-size="{ip(o,FSZ)*1.333:.1f}" style="font-family:{f}" text-anchor="{a[0]}" dominant-baseline="{a[1]}">{html.escape(o["tx"])}</text>'
        (back if ip(o,BACK) else front).append(el)
    elif ty == 1:   # trend line (chart)
        dash = {0:'',1:'6 4',2:'2 3',3:'6 3 2 3'}.get(ip(o,STY),'')
        lines.append(f'<line x1="{X(o["t1"])}" x2="{X(o["t2"])}" y1="{Y(o["p1"])}" y2="{Y(o["p1"])}" stroke="{hexc(ip(o,COL))}" stroke-width="{max(1,ip(o,WID))}" stroke-dasharray="{dash}"/>')
    elif ty == 3:   # chart text
        lines.append(f'<text x="{X(o["t1"])+3}" y="{Y(o["p1"])}" fill="{hexc(ip(o,COL))}" font-size="11" dominant-baseline="central" style="font-family:{FONT["Segoe UI"]}">{html.escape(o["tx"])}</text>')
candles = []
for b in bars:
    t, op, h, l, c = b; cx = X(t + P / 2); w = (X(P) - X(0)) * 0.62; col = '#2ecc80' if c >= op else '#ef5a5a'
    candles.append(f'<line x1="{cx}" x2="{cx}" y1="{Y(h)}" y2="{Y(l)}" stroke="{col}"/><rect x="{cx-w/2}" y="{Y(max(op,c))}" width="{w}" height="{max(1,abs(Y(op)-Y(c)))}" fill="{col}"/>')
svg = (f'<svg xmlns="http://www.w3.org/2000/svg" xml:space="preserve" style="white-space:pre" width="{W}" height="{H}"><rect width="{W}" height="{H}" fill="#11151c"/>'
       + ''.join(back) + ''.join(lines) + ''.join(candles) + ''.join(front) + '</svg>')
open(out, 'w').write(f'<!doctype html><html><head><meta charset="utf-8"></head><body style="margin:0;background:#11151c">{svg}</body></html>')
