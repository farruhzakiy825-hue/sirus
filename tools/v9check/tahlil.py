#!/usr/bin/env python3
"""V9 tester natijalari tahlili.

python3 tahlil.py <Soya.csv> <Kozlar.csv> <Olchov.csv>

1. Soya savdo:
   - T (V9.05+, trailing): har gipoteza x chiqish bo'yicha R, t, bootstrap, MFE; topish (2/3) va tasdiqlash (1/3) davrlari,
     docs/GIPOTEZALAR.md dagi mezon bilan;
   - eski CB / N / Q (V9.04): TP ulushi va zararsizlik uchun kerakli ulush.
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


def boot_p(v, iters=2000, seed=7):
    """Qayta tanlashda o'rtacha <= 0 chiqish ulushi (bir tomonli p)."""
    import random
    rnd = random.Random(seed)
    n = len(v)
    bad = 0
    for _ in range(iters):
        if sum(v[rnd.randrange(n)] for _ in range(n)) <= 0.0:
            bad += 1
    return bad / iters


def maxdd(v):
    eq = pk = dd = 0.0
    for x in v:
        eq += x
        pk = max(pk, eq)
        dd = min(dd, eq - pk)
    return dd


def soya_t(path):
    print("=== SOYA T (R da) ===")
    R = read(path)
    ex = [r for r in R if r["hodisa"] != "KIRISH"]
    if not ex:
        print("yopilgan savdo yo'q")
        return
    times = sorted(r["vaqt"] for r in R)
    t0 = dt.datetime.strptime(times[0], "%Y-%m-%d %H:%M:%S")
    t1 = dt.datetime.strptime(times[-1], "%Y-%m-%d %H:%M:%S")
    cut = t0 + (t1 - t0) * 2 / 3
    print(f"davr: {t0:%Y-%m-%d} .. {t1:%Y-%m-%d}; topish < {cut:%Y-%m-%d} <= tasdiqlash")
    # Kirish vaqti = chiqish vaqti - daqiqa.
    for r in ex:
        r["_t"] = dt.datetime.strptime(r["vaqt"], "%Y-%m-%d %H:%M:%S") - dt.timedelta(minutes=int(r["daqiqa"]))
        r["_r"] = float(r["natija_R"])
        r["_mfe"] = float(r["mfe_R"])
    keys = sorted(set((r["gipoteza"], r["chiqish"]) for r in ex))
    passed = []
    for k in keys:
        v = [r for r in ex if (r["gipoteza"], r["chiqish"]) == k]
        v.sort(key=lambda r: r["_t"])
        allr = [r["_r"] for r in v]
        disc = [r["_r"] for r in v if r["_t"] < cut]
        conf = [r["_r"] for r in v if r["_t"] >= cut]
        line = f"{k[0]}_{k[1]}: n={len(allr):4d} yutgan={sum(x > 0 for x in allr) / len(allr):.0%} jami={sum(allr):+7.1f}R"
        if len(allr) >= 2:
            m, t = mean_t(allr)
            line += f" o'rtacha={m:+.3f}R t={t:+.1f} maxDD={maxdd(allr):.1f}R"
        line += f" | MFE>=2R {sum(r['_mfe'] >= 2 for r in v) / len(v):.0%} >=5R {sum(r['_mfe'] >= 5 for r in v) / len(v):.0%}"
        print(line)
        ok1 = ok2 = False
        if len(disc) >= 2:
            m1, t1_ = mean_t(disc)
            ok1 = len(disc) >= 60 and m1 > 0 and t1_ >= 2.6
            print(f"     topish:      n={len(disc):4d} o'rtacha={m1:+.3f}R t={t1_:+.1f} boot_p={boot_p(disc):.3f} {'O`TDI' if ok1 else '-'}")
        if len(conf) >= 2:
            m2, t2 = mean_t(conf)
            ok2 = len(conf) >= 25 and m2 > 0 and t2 >= 1.65
            print(f"     tasdiqlash:  n={len(conf):4d} o'rtacha={m2:+.3f}R t={t2:+.1f} boot_p={boot_p(conf):.3f} {'O`TDI' if ok2 else '-'}")
        if ok1 and ok2:
            passed.append(f"{k[0]}_{k[1]}")
    print("MEZONDAN O'TGANLAR:", ", ".join(passed) if passed else "yo'q")


def soya(path):
    head = open(path, encoding="latin-1").readline()
    if "gipoteza" in head:
        soya_t(path)
        return
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
