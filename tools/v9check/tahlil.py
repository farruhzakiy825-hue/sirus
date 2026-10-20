#!/usr/bin/env python3
"""V9 tester natijalari tahlili.

python3 tahlil.py <Soya.csv> <Kozlar.csv> <Olchov.csv>

1. Soya savdo: har rejim bo'yicha TP ulushi, o'rtacha yutuq / zarar, zararsizlik uchun kerakli TP ulushi.
2. O'lchov: kataklar z taqsimoti (tasodifda sd ~ 1, |z|>=2 ~ 4.6%) va har o'lchov bo'yicha alohida.
3. Oyoqlar: har oyoq BITTA namuna (M5 qatorlari bir-birini qoplaydi - ularni alohida sanash t ni sun'iy oshiradi).
   Oyoq yo'nalishida keyingi 30 / 60 / 240 daqiqadagi narx o'zgarishi.
"""
import csv
import collections
import datetime as dt
import math
import sys

STAGES = ["TUG'ILDI", "YANGI", "RIVOJ", "KECH", "TUGADI"]


def read(path):
    rows = list(csv.reader(open(path, encoding="latin-1"), delimiter=";"))
    h = rows[0]
    return [dict(zip(h, r)) for r in rows[1:] if len(r) == len(h)]


def mean_t(v):
    n = len(v)
    m = sum(v) / n
    sd = math.sqrt(sum((x - m) ** 2 for x in v) / (n - 1)) if n > 1 else 0.0
    return m, (m / (sd / math.sqrt(n)) if sd > 0 else 0.0)


def soya(path):
    print("=== SOYA SAVDO (punkt) ===")
    rows = list(csv.reader(open(path, encoding="latin-1"), delimiter=";"))[1:]
    tr = collections.defaultdict(list)
    for r in rows:
        if len(r) >= 10 and r[2] != "KIRISH":
            tr[r[1]].append((r[2], float(r[7])))
    for m in ("CB", "N", "Q"):
        t = tr.get(m, [])
        if not t:
            print(f"{m}: savdo yo'q")
            continue
        win = [p for k, p in t if k == "TP"]
        loss = [p for k, p in t if k != "TP"]
        aw = sum(win) / len(win) if win else 0.0
        al = sum(loss) / len(loss) if loss else 0.0
        be = -al / (-al + aw) if win and loss else 0.0
        kinds = dict(collections.Counter(k for k, _ in t))
        print(f"{m}: n={len(t)} {kinds} TP={len(win) / len(t):.1%} kerak={be:.1%} "
              f"o'rtacha yutuq={aw:.0f} zarar={al:.0f} savdo boshiga={sum(p for _, p in t) / len(t):+.0f} jami={sum(p for _, p in t):+.0f}")


def olchov(path):
    print("=== O'LCHOV ===")
    R = read(path)
    for tp in sorted(set(r["tp_turi"] for r in R)):
        S = [r for r in R if r["tp_turi"] == tp]
        zs = [float(r["z"]) for r in S if int(r["natija"]) >= 30]
        if not zs:
            continue
        m = sum(zs) / len(zs)
        sd = math.sqrt(sum((z - m) ** 2 for z in zs) / len(zs))
        print(f"{tp}: natija={sum(int(r['natija']) for r in S)} kataklar(n>=30)={len(zs)} z o'rtacha={m:+.2f} sd={sd:.2f} "
              f"|z|>=2: {sum(abs(z) >= 2 for z in zs)} (tasodifda ~{0.0455 * len(zs):.0f})")
        for dim, name in enumerate(("tomon-oyoq", "bosqich", "zona", "H1", "qadam")):
            agg = collections.defaultdict(lambda: [0, 0, 0.0])
            for r in S:
                k = r["katak"].split(" | ")[dim]
                n = int(r["natija"])
                a = agg[k]
                a[0] += n
                a[1] += int(r["tp"])
                a[2] += n * float(r["kutilgan"])
            line = []
            for k, (n, t, e) in sorted(agg.items()):
                if n:
                    p, e = t / n, e / n
                    z = (p - e) / math.sqrt(e * (1 - e) / n) if 0 < e < 1 else 0.0
                    line.append(f"{k} z={z:+.1f}")
            print(f"   {name}: " + " · ".join(line))


def oyoqlar(path):
    print("=== OYOQLAR (har oyoq bitta namuna) ===")
    R = read(path)
    T = [dt.datetime.strptime(r["vaqt"], "%Y-%m-%d %H:%M:%S") for r in R]
    P = [float(r["narx"]) for r in R]
    pos = {t: i for i, t in enumerate(T)}

    def fwd(i, mins):
        j = pos.get(T[i] + dt.timedelta(minutes=mins))
        return None if j is None else P[j] - P[i]

    legs = []
    cur = None
    for i, r in enumerate(R):
        if r["m5_yon"] not in ("BUY", "SELL"):
            cur = None
            continue
        key = (r["m5_yon"], r["m5_tugildi"], r["m5_origin"])
        if cur is None or cur["key"] != key:
            cur = {"key": key, "rows": [], "d": 1 if r["m5_yon"] == "BUY" else -1}
            legs.append(cur)
        cur["rows"].append(i)
    reach = collections.Counter(max((R[i]["m5_bosqich"] for i in L["rows"]),
                                    key=lambda s: STAGES.index(s) if s in STAGES else -1) for L in legs)
    print(f"oyoqlar: {len(legs)}; eng uzoq yetgan bosqich: {dict(reach)}")
    print("vaqt ulushi:", {k: f"{v / len(R):.0%}" for k, v in collections.Counter(r['m5_bosqich'] for r in R).items()})
    born = [R[L["rows"][0]] for L in legs]
    la = sorted(float(r["m5_uzunlik_atr"]) for r in born if r["m5_uzunlik_atr"])
    if la:
        print(f"tug'ilganda uzunlik ATR(M15) median: {la[len(la) // 2]:.2f}")

    def pick(stage):
        return lambda L: next((i for i in L["rows"] if R[i]["m5_bosqich"] == stage), None)

    tests = [("tug'ilish", lambda L: L["rows"][0])] + [("birinchi " + s, pick(s)) for s in STAGES[1:]]
    for mins in (30, 60, 240):
        for name, f in tests:
            v = []
            for L in legs:
                i = f(L)
                if i is not None:
                    x = fwd(i, mins)
                    if x is not None:
                        v.append(L["d"] * x)
            if len(v) >= 8:
                m, t = mean_t(v)
                print(f"   {name:18s} +{mins:3d}m n={len(v):4d} o'rtacha={m:+.2f}$ t={t:+.1f} yo'nalishda={sum(x > 0 for x in v) / len(v):.0%}")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    soya(sys.argv[1])
    olchov(sys.argv[3])
    oyoqlar(sys.argv[2])
