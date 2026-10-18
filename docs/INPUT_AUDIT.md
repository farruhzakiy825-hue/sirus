# Input auditi (13-paket, 2026-10-18)

Master reja XVIII: "Hech bir mavjud inputning ma'nosi tasdiqlanmasdan o'zgartirilmaydi. Nomi o'xshash inputlar
bir xil vazifani bajaradi deb taxmin qilinmaydi." Shu sababli bu audit **faqat o'lchaydi va ogohlantiradi**.
Inputlarning ma'nosi o'zgartirilmagan. Bitta dublikat birlashtirildi (pastda).

Usul: barcha `.mqh` va `.mq5` fayllarining statik tahlili. Izohlar va satrlar olib tashlangan, har input nomi butun so'z
sifatida qidirilgan. Kompilyator yoki tester ishlatilmagan.

## 1. Raqamlar

| | Soni |
|---|---|
| Jami input | **3066** |
| `01_Inputs.mqh` da | 2825 (92%) |
| Qolgan 24 faylda | 241 (miya modullari o'z inputlari bilan) |
| bool / int / double | 1050 / 1033 / 848 |
| Kodda **umuman o'qilmaydigan** (o'lik) | **0** |
| Sukut bo'yicha **o'chiq** bool kalit | 133 |
| Faqat o'chiq kalit ortida o'qiladigan input | 66 (pastda) |
| Log / print kalitlari | ~229 |
| Panel / rang / shrift | ~155 |

Xulosa: inputlar ko'pligining sababi o'lik sozlamalar emas. Asosiy sabablar uchta:
- bir xil savol uchun bir nechta **parallel oila** bor;
- log kalitlari ko'p (~229);
- vizual sozlamalar ko'p (~155).

## 2. Parallel oilalar (bitta savolga bir nechta javob)

| Savol | Inputlar | Izoh |
|---|---|---|
| Sessiya soatlari | `Session*Hour` (5), `Legacy*StartHour` (3), `AsiaSession*` / `LondonNYSession*` (4), `NYKillzone*` (2), `MBAsia*` (2) | Bular 5 ta mustaqil to'plam va hammasi qat'iy broker soatida. 12-paketdagi sessiya likvidligi UTC va DST'ni o'zi hisoblaydi. Server UTC+0 bo'lmasa, qat'iy soatlar siljiydi; ishga tushishdagi audit endi bu haqda ogohlantiradi |
| Maksimal spread | `UnifiedMaxSpreadPoints`, `RiskMaxSpreadPoints`, `P4MiniMaxSpread`, `RC*MaxSpread` (3), `ClientSafetyMaxSpread*` (3), `AftershockMaxSpread`, `BrokerSyncMaxSpread`, `AutoHighHunterMaxSpread`, `AutoBalancedSpreadLimit`, `RebateTPMaxSpreadPoints` | 14 ta chegara. Amalda eng qattig'i ishlaydi |
| Birinchi lot chegarasi | `StartLot`, `LotForBalancedMode`, `LotForHighHunterMode`, `P4Mini*FirstLot` (4), `RC*MaxFirstLot` (3) | 8-paketdan beri bazaviy lot bitta (`EntryBaseLot`). Qolganlari faqat yuqori chegara |
| Pog'ona soni | `MaxOrders`, `P4Mini*MaxOrders` (3), `RC*MaxOrders` (3), `LadderMaxOrdersCap`, `CashbackSizingRungs` | Amalda eng kichigi ishlaydi |
| Grid masofasi | `GridDistancePoints`, `Balanced*` / `Hunter*GridDistance*`, `AdaptiveGridDistance`, `AsiaGridDistanceFactor` va boshqalar (15) | Rejim va sessiya bo'yicha alohida |
| Cashback $/lot | `RebateUSDPerLot` (20e), `CashbackPerLot` (25) | **Birlashtirildi**: ikkalasidan biri yetadi (13-paket) |

Uchta "preset" qatlam bir-birini takrorlaydi: **P4Mini**, **RC** (Release Control) va **ClientSafety**. Uchalasi ham
lot, pog'ona, spread va basket SL'ni alohida cheklaydi. Taklif: sinovdan keyin bitta qatlamga birlashtirish. Buni
egasining qarorisiz qilmayman.

## 3. Rejimlar: Balanced va High Hunter

`G_ACTIVE_MODE` faqat eski qatlamni o'zgartiradi:
- skaner bali (`MinScore*`, Hunter +1 grade);
- micro lot;
- range kengligi;
- grid masofasi;
- Hunter D1 filtri;
- jarima shiftining Hunter termi.

**Miya qatlamlari (17–26) rejimni o'qimaydi.** Ikkala rejimda hakam, veto, zonalar, grid xavfi va pozitsiya miyasi bir
xil ishlaydi. Cashback va oddiy rejim farqi 8-paketda tekshirilgan: miya ikkalasida ham to'liq.

## 4. Sukut bo'yicha o'chiq kalitlar (133)

Ularning ko'pi log va panel kalitlari (`*PrintOnUse`, `Show*`). Savdoga ta'sir qiladiganlari quyidagilar:
- **qattiq bloklar:** `*HardBlock`, `Deep*Strict*`, `Deep*BlockGrid*`. Ular ataylab o'chirilgan: bloklar jarima yoki
  kutishga aylantirilgan;
- **rejimlar:** `EnableRebateMode` (cashback). Siz uni yoqasiz;
- **qo'shimcha chiqishlar:** `EnableSmartPartialClose`, `EnableLadderedPartialClose`, `EnableSmartEarlyExit`,
  `DeepExitEnableAutoClose`, `EnableSZREscapeMode`. Bular egasining "zararda yopish faqat IMPOSSIBLE yoki SL" qoidasi
  bilan to'qnashishi mumkin, shuning uchun o'chiq qolgani to'g'ri;
- **eski yoki litsenziya:** `UseLegacyUpgradePack`, `EnableLicenseAccountGuard`, `P4MiniUseLicenseControl`,
  `ReleaseRequireLicenseForClient`.

## 5. Faqat o'chiq kalit ortida o'qiladigan inputlar (66)

Ular kalit yoqilganda ishlaydi, shuning uchun o'lik emas. Asosiy guruhlar:
- **cashback** (`Rebate*`): `EnableRebateMode` yoqilganda ishlaydi. Siz shu rejimdasiz, demak ular kerak;
- **o'chiq qattiq bloklar** (`ImpulseEnd*`, `BlowOff*`, `ZoneWallHardBlock*`, `CounterImpulse*`);
- **o'chiq chiqishlar** (`DeepExit*`, `PartialClose*`, `BasketBE*`);
- **litsenziya** (`License*`, `P4Mini*Expire*`, `P4MiniAllow*`). Server litsenziyasi olib tashlangan, bular qoldiq.
  Taklif: olib tashlash.

## 6. Ishga tushishda ogohlantirish (yangi, `InputAuditReport`)

Jurnalga `[SIRUS INPUT AUDIT] ...` yoziladi va panelning oxirgi ogohlantirishiga tushadi. Hech narsa o'zgartirilmaydi.
Tekshiriladigan holatlar:
- cashback rejimida trailing yoqilgan (qoida: cashback'da qat'iy TP);
- `CashbackSizingRungs` > `MaxOrders`;
- `StartLot` > `MaxLot`;
- `MinFirstEntryLotFactor` > 1;
- basket SL o'chiq yoki 50% emas (qoida: 50%);
- `EnableGridNeverBelowPrevious` o'chiq (qoida: ko'r-ko'rona dolivka yo'q);
- ikki cashback $/lot inputi har xil qiymatda;
- kichik dollar hisob (< $500) oddiy rejimda (qoida: kichik dollar hisob faqat cashback). Cent hisob (USC) bu
  tekshiruvga kirmaydi;
- ~~broker serveri UTC+0 emas~~ - 14-paketdan beri: qo'lda berilgan `SessionServerUTCOffset` broker soatiga mos emas.

## 7. Takliflar (egasining qarori kerak)

1. **Preset qatlamlari** (P4Mini, RC, ClientSafety) — bitta qatlamga birlashtirish.
2. **Sessiya soatlari** — 5 to'plam o'rniga bitta UTC va DST sessiya dvigateli (12-paketdagidek).
3. **Maksimal spread** — 14 chegara o'rniga bitta samarali chegara va rejim koeffitsienti.
4. **Litsenziya qoldiqlari** — olib tashlash.
5. **Log kalitlari** (~229) — bitta `G_VERBOSE` va guruh kalitlari (tester uchun allaqachon `TesterQuietLogs` bor).

Hech biri savdo mantiqini o'zgartirmaydi, faqat sozlamalarni soddalashtiradi. Har biri alohida paket bo'lishi va
oldin-keyin taqqoslanishi kerak.

## 8. Natija: 14-paket (2026-10-18) - beshala taklif bajarildi

| Taklif | Natija |
|---|---|
| 1. Preset qatlamlari | Bitta **Safety layer** (`EnableSafetyLayer`, `SafetySymbolKeyword`, `SafetyMaxFirstLot` 0.25, `SafetyMaxGridLot` 1.00, `SafetyWidenGridOnRisk`, `SafetyDDWarnPercent` 10, `SafetyDDDangerPercent` 16, `SafetyOrdersWarn` 4, `SafetyGridWidenFactor` 1.25, `SafetyGridDangerFactor` 1.65). Pog'ona lotini kesish olib tashlandi (egasining qoidasi) |
| 2. Sessiya soatlari | Bitta UTC + DST dvigateli; 18 ta qat'iy soat inputi o'rniga `EnableDSTAdjust` va `SessionServerUTCOffset` (99 = avtomatik) |
| 3. Maksimal spread | `UnifiedMaxSpreadPoints` x `HunterSpreadFactor` (Hunter rejimida), `CleanSpreadPoints`, `CriticalSpreadPoints` |
| 4. Litsenziya qoldiqlari | Olib tashlandi (License*, P4Mini litsenziya, Release*, rental ogohlantirishlari) |
| 5. Log kalitlari | 217 kalit -> 7 guruh: `LogEntryEvents`, `LogGridEvents`, `LogExitEvents`, `LogRiskEvents`, `LogBrainEvents`, `LogSystemEvents`, `LogDiagnostics` (o'chiq) |

Inputlar soni: **3066 -> ~2760**. O'qilmaydigan input: 0. Ishga tushishdagi audit: "server UTC+0 emas" ogohlantirishi
o'rniga endi faqat qo'lda berilgan `SessionServerUTCOffset` haqiqiy broker soatiga mos kelmasa ogohlantiradi.
