//+------------------------------------------------------------------+
//| SirusV9 - 01_Konstantalar                                        |
//| Bozorni O'QISH qoidalari: hamma uchun bir xil, sozlama emas.     |
//| Har biri V8 dan sinalgan qiymat; manbasi izohda.                 |
//| O'zgartirish faqat O'lchov (60) dalili bilan.                    |
//+------------------------------------------------------------------+

//--- Barlar va ATR
#define V9_BARS_MAX           300     // har TF uchun yopilgan barlar (M1 5 soat, M5 25 soat, H1 12 kun)
#define V9_BARS_H4            200     // H4: 33 kun
#define V9_BARS_MIN           60      // shundan kam bo'lsa TF "tayyor emas" - KUT
#define V9_ATR_N              14      // ATR davri (oddiy o'rtacha TR)

//--- 10 HODISALAR (V8 18_Event_Engine, 20b_Structure_Lock, 20_Market_Brain)
#define V9_SWING_LEN_M1       3       // M1 swing: har tomonda 3 bar (18:34)
#define V9_SWING_LEN_HTF      2       // M5..H4 swing: 2 bar (18:36)
#define V9_BREAK_BUF_ATR      0.05    // BOS: swingdan ATR x 0.05 narida yopilish (18:589)
#define V9_SINDI_BUF_ATR      0.15    // SINDI: HIMOYAdan ATR x 0.15 narida yopilish (20:1157 HIDDEN-BUG fix)
#define V9_FAIL_BACK_ATR      0.10    // SOXTA: keyingi 2 yopilishdan biri ATR x 0.1 orqaga qaytsa (20:148)
#define V9_FAIL_BARS          2       // SOXTA tekshiruvi: 2 ta yopilish
#define V9_Q_WEAK_BODY        0.30    // break shami tanasi < ATR x 0.3 = KUCHSIZ (20b:150)
#define V9_Q_STRONG_BODY      0.80    // >= ATR x 0.8 = KUCHLI
#define V9_SWEEP_MIN_ATR      0.10    // sweep: kamida ATR x 0.1 teshish (18:446)
#define V9_SWEEP_MAX_ATR      1.00    // undan chuqur teshib qaytsa - SOXTA BREAK (18:447)
#define V9_TAKEN_CLOSE_ATR    0.05    // swing narisida yopilish = olindi
#define V9_DISP_BODY_ATR      1.20    // displacement: tana >= ATR x 1.2 (17:301)
#define V9_DISP_RATIO         0.60    // ... tana / diapazon >= 0.6
#define V9_DISP_CLOSE_POS     0.75    // ... yopilish diapazonning chekka 25% ida
#define V9_DISP_STRONG_ATR    1.80    // KUCHLI displacement
#define V9_EV_MAX             400     // har TF uchun hodisa halqasi
#define V9_SW_MAX             320     // har TF uchun swinglar (>= V9_BARS_MAX: to'lmaydi)
#define V9_PEND_MAX           4       // tasdiq kutayotgan breaklar

//--- 20 LIKVIDLIK (V8 20a_Liquidity_Map)
#define V9_POOL_MAX           120
#define V9_POOL_MERGE_ATR15   0.20    // ATR(M15) x 0.2 ichidagi darajalar bitta hovuz (20a:82)
#define V9_POOL_WIN_ATR15     8.0     // oyna: max(ATR(M15) x 8, ATR(H1) x 4) (20a)
#define V9_POOL_WIN_ATRH1     4.0
#define V9_POOL_TAKEN_CLOSES  2       // OLINDI = 2 ketma-ket M5 yopilish narida (20a:406)
#define V9_POOL_SWEEP_ATR5    0.10    // SWEEP = M5 ATR x 0.1 teshib, ichkarida yopilish
#define V9_POOL_KEEP_TAKEN_S  86400   // olingan hovuz 24 soat eslab qolinadi (TUGADI uchun)
#define V9_ASIA_FROM_UTC      0       // Osiyo sessiyasi 00:00-06:00 UTC
#define V9_ASIA_TO_UTC        6

//--- 30 OYOQ (POYDEVOR 3.2-3.4)
#define V9_STAGE_NEW          0.33    // yurgani < 33% = YANGI
#define V9_STAGE_LATE         0.66    // >= 66% = KECH
#define V9_STAGE_WAVES_LATE   3       // 3+ turtki = KECH
#define V9_LEN_NEW_ATR15      1.5     // maqsad yo'q: uzunlik < 1.5 ATR (bir pog'ona katta TF; M5 -> M15) = YANGI (17: EARLY)
#define V9_LEN_LATE_ATR15     2.5     // >= 2.5 ATR = KECH (17: LATE)
#define V9_PB_SHALLOW         0.23    // qaytish zonalari (HIMOYA dan o'lchanadi)
#define V9_PB_GOLD_LO         0.38
#define V9_PB_GOLD_HI         0.62
#define V9_PB_DEEP_HI         0.79
#define V9_TARGET_GAP_ATR     0.10    // maqsad EKSTREMUM dan kamida ATR x 0.1 narida
#define V9_REV_RETEST_ATR     0.35    // reversal 4: MSS darajasiga ATR x 0.35 gacha qaytish (20b)
#define V9_REV_HL_ATR         0.20    // reversal 5: higher low origin dan ATR x 0.2 yuqorida

//--- 40 XARITA (V8 20g_HTF_Zones, 20i)
#define V9_ZONE_MAX           80
#define V9_Z_BASE_RANGE       0.80    // baza shami diapazoni <= ATR x 0.8
#define V9_Z_BASE_BODY        0.50    // ... tanasi <= diapazonning yarmi
#define V9_Z_LEAVE_ATR        1.50    // 3 bar ichida ATR x 1.5 uzoqlashish
#define V9_Z_LEAVE_BARS       3
#define V9_Z_MIN_W_ATR        0.20    // zona kengligi kamida ATR x 0.2
#define V9_Z_MAX_VISITS       3       // 3 tashrifdan keyin eskirgan (20g)
#define V9_Z_WIN_ATRH1        6.0     // narxdan ATR(H1) x 6 ichidagi zonalar
#define V9_DR_EQ_LO           0.45    // dealing range: 45-55% muvozanat
#define V9_DR_EQ_HI           0.55

//--- 50 QADAM (V8 17_Candle_Engine, 18 live sweep)
#define V9_Q_LIVE_DISP_ATR    0.80    // shakllanayotgan M1: tana >= ATR x 0.8 (17:542)
#define V9_Q_REJ_WICK         0.50    // rad etish: dum >= diapazon x 0.5
#define V9_Q_REJ_CLOSE        0.60    // ... yopilish joyi >= 0.6
#define V9_Q_INDEC_BODY       0.25    // noaniq: tana <= diapazon x 0.25
#define V9_Q_INDEC_RANGE      0.70    // ... diapazon <= ATR x 0.7
#define V9_Q_REAL_BODY        0.30    // haqiqiy tana >= ATR x 0.3
#define V9_PRESS_THR          0.25    // bosim chegarasi
#define V9_LSW_MIN_ATR1       0.15    // jonli sweep: ATR(M1) x 0.15 teshish (18:1078)
#define V9_LSW_WINDOW_S       45      // ... 45 s ichida qaytish
#define V9_LSW_VALID_S        120     // ... 120 s amal qiladi
#define V9_LSW_NEAR_ATR5      1.0     // ... narxdan ATR(M5) x 1 ichidagi swinglar
#define V9_TICK_RING          512

//--- 95 PANEL
#define V9_DRAW_MS            250     // chizish oralig'i
#define V9_OBJ                "SV9_"  // obyekt prefiksi
