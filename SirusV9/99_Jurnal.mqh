//+------------------------------------------------------------------+
//| SirusV9 - 99_Jurnal                                              |
//| KO'Z JURNALI: har M5 bar yopilganda robot nima ko'rganini bitta  |
//| qatorga yozadi - egasi chart oldida o'tirmasa ham keyin tekshirib|
//| bo'ladi. Fayl: Common\Files\SirusV9_Kozlar_<symbol>_<sana>.csv   |
//| (soya savdolar: SirusV9_Soya_<symbol>_<sana>.csv, 70_Soya).      |
//| Faqat o'qiydi, hech narsa o'zgartirmaydi.                        |
//+------------------------------------------------------------------+

//--- CSV uchun: faqat oddiy belgilar (Excel ANSI da to'g'ri ochsin). Maydonlarda ';' bo'lmaydi - u ajratuvchi.
string V9Ascii(const string text)
{
   string s = text;
   StringReplace(s, "·", "|");
   StringReplace(s, "▲", "UP");
   StringReplace(s, "▼", "DN");
   StringReplace(s, "—", "-");
   StringReplace(s, "…", "...");
   return s;
}

string V9JrDir(const int d)
{
   if(d > 0) return "BUY";
   if(d < 0) return "SELL";
   return "-";
}

string V9JrPoolSide(const int side)
{
   int i = V9PoolNearestSide(side);
   if(i < 0)
      return "-";
   return V9PoolName(i) + " " + V9Px(g_pool[i].price) + StringFormat(" (sinf %d)", g_pool[i].cls);
}

string V9JrLastEvent()
{
   return V9Ascii(V9LastEventText());
}

string V9JrHeader()
{
   string h = "vaqt;narx;spread;m5_yon;m5_bosqich;m5_yurgan_pct;m5_uzunlik_atr;m5_qaytish_pct;m5_zona;m5_origin;m5_himoya;";
   h = h + "m5_maqsad;m5_maqsad_nomi;m5_turtki;m5_tugildi;m5_tugilish;m5_tasdiq;burilish;teskari_belgi;xarita;";
   h = h + "h1_holat;h4_holat;h1_yon;h1_bosqich;h1_himoya;range_pct;katta_kech;devor_tepa;devor_past;hovuz_tepa;hovuz_past;";
   h = h + "qadam;qadam_sabab;bosim;oxirgi_hodisa;soya_cb;soya_n;olchov_buy;olchov_sell";
   return h;
}

//--- Yangi M5 bar ochilganda (oldingi yopilgandan keyin) chaqiriladi.
void V9JrKoz()
{
   if(!g_ready[V9_M5] || !g_ready[V9_H1])
      return;
   string L = V9TimeStr(TimeCurrent()) + ";" + V9Px(V9Bid()) + ";" + V9Px(V9Spread()) + ";";
   if(g_lv[V9_M5].ok)
   {
      MqlDateTime bt;
      TimeToStruct(g_lv[V9_M5].bornT, bt);
      L = L + V9JrDir(g_lv[V9_M5].dir) + ";" + V9StageName(g_lv[V9_M5].stage) + ";" +
          ((g_lv[V9_M5].progress >= 0.0) ? StringFormat("%.0f", g_lv[V9_M5].progress * 100.0) : "-") + ";" +
          StringFormat("%.2f", g_lv[V9_M5].lenAtr) + ";" + StringFormat("%.0f", g_lv[V9_M5].pullback * 100.0) + ";" +
          V9ZoneName(g_lv[V9_M5].zone) + ";" + V9Px(g_lv[V9_M5].origin) + ";" + V9Px(g_lv[V9_M5].himoya) + ";" +
          ((g_lv[V9_M5].targetIdx >= 0) ? V9Px(g_lv[V9_M5].target) : "-") + ";" +
          ((g_lv[V9_M5].targetIdx >= 0) ? V9PoolName(g_lv[V9_M5].targetIdx) : "-") + ";" +
          IntegerToString(g_lv[V9_M5].waves) + ";" + StringFormat("%02d:%02d", bt.hour, bt.min) + ";" +
          ((g_lv[V9_M5].birthType == EV_MSS) ? "MSS" : "BOS") + ";" + (g_lv[V9_M5].confirmed ? "ha" : "yo'q") + ";" +
          IntegerToString(g_lv[V9_M5].revStage) + ";" + IntegerToString(g_lv[V9_M5].counter) + ";" +
          V9MapRelName(g_lv[V9_M5].mapRel) + ";";
   }
   else
      L = L + "-;-;-;-;-;-;-;-;-;-;-;-;-;-;-;-;-;-;";
   L = L + V9MapStateName(g_mapState[V9_H1]) + ";" + V9MapStateName(g_mapState[V9_H4]) + ";";
   if(g_lv[V9_H1].ok)
      L = L + V9JrDir(g_lv[V9_H1].dir) + ";" + V9StageName(g_lv[V9_H1].stage) + ";" + V9Px(g_lv[V9_H1].himoya) + ";";
   else
      L = L + "-;-;-;";
   L = L + (g_drOk ? StringFormat("%.0f", g_drPos * 100.0) : "-") + ";" + (g_bigLate ? "ha" : "yo'q") + ";";
   L = L + V9ZoneText(V9ZoneNearest(1)) + ";" + V9ZoneText(V9ZoneNearest(-1)) + ";";
   L = L + V9JrPoolSide(1) + ";" + V9JrPoolSide(-1) + ";";
   L = L + V9JrDir(g_qd.dir) + ";" + g_qd.why + ";" + V9JrDir(g_qd.pressure) + ";";
   L = L + V9JrLastEvent() + ";" + V9SyNowText(SY_CB) + ";" + V9SyNowText(SY_N) + ";";
   L = L + V9OlVerdictName(V9OlVerdict(0, g_olCellNow[1])) + ";" + V9OlVerdictName(V9OlVerdict(0, g_olCellNow[0]));
   V9FileAppend(V9DailyFile("Kozlar"), V9JrHeader(), V9Ascii(L));
}
