// Minimal MQL5 -> C++ shim for syntax/type checking and synthetic runtime tests.
#pragma once
#include <string>
#include <vector>
#include <cmath>
#include <cstdio>
#include <cstdint>
#include <cassert>
#include <map>
#include <algorithm>
#include <stdexcept>
typedef std::string string;
typedef long long datetime;
typedef unsigned int color;

typedef unsigned int uint;
#define DBL_MAX_ 1e308
struct MqlRates { datetime time; double open, high, low, close; long long tick_volume; int spread; long long real_volume; };
struct MqlDateTime { int year, mon, day, hour, min, sec, day_of_week, day_of_year; };
template<class T> struct MqlArray {
  std::vector<T> v;
  T& operator[](int i){ if(i<0||i>=(int)v.size()) throw std::out_of_range("MqlArray index"); return v[i]; }
  const T& operator[](int i) const { if(i<0||i>=(int)v.size()) throw std::out_of_range("MqlArray index"); return v[i]; }
};
template<class T> int ArrayResize(MqlArray<T>& a, int n){ a.v.resize(n); return n; }
template<class T> int ArraySize(const MqlArray<T>& a){ return (int)a.v.size(); }
template<class T> bool ArraySetAsSeries(MqlArray<T>&, bool){ return true; }
enum ENUM_TIMEFRAMES { PERIOD_M1=1, PERIOD_M5=5, PERIOD_M15=15, PERIOD_H1=60, PERIOD_H4=240, PERIOD_D1=1440, PERIOD_W1=10080 };
enum { SYMBOL_BID=1, SYMBOL_ASK=2 };
enum { INIT_SUCCEEDED=0 };
enum { OBJ_TREND=1, OBJ_RECTANGLE, OBJ_TEXT, OBJ_LABEL };
enum { OBJPROP_SELECTABLE=1, OBJPROP_HIDDEN, OBJPROP_RAY_RIGHT, OBJPROP_COLOR, OBJPROP_STYLE, OBJPROP_WIDTH, OBJPROP_BACK, OBJPROP_FILL,
       OBJPROP_ANCHOR, OBJPROP_TEXT, OBJPROP_FONT, OBJPROP_FONTSIZE, OBJPROP_CORNER, OBJPROP_XDISTANCE, OBJPROP_YDISTANCE };
enum { STYLE_SOLID=0, STYLE_DASH, STYLE_DOT, STYLE_DASHDOT };
enum { ANCHOR_LEFT=0, ANCHOR_LEFT_UPPER };
enum { CORNER_LEFT_UPPER=0 };
#define clrGold 1u
#define clrWhiteSmoke 2u
#define clrDarkGray 3u
#define clrMediumSeaGreen 4u
#define clrTomato 5u
#define clrGray 6u
#define clrCrimson 7u
#define clrDodgerBlue 8u
#define clrSteelBlue 9u
inline color RGBc(int r,int g,int b){ return (color)(r|(g<<8)|(b<<16)); }

template<class A,class B> auto MathMax(A a,B b) -> decltype(a+b) { return a>b?a:b; }
template<class A,class B> auto MathMin(A a,B b) -> decltype(a+b) { return a<b?a:b; }
template<class A> A MathAbs(A a){ return a<0?-a:a; }
inline double MathRound(double x){ return std::round(x); }

// ---- synthetic market (filled by the test) ----
struct SimBar { datetime t; double o,h,l,c; };
extern std::map<int, std::vector<SimBar>> g_sim;   // tf minutes -> bars (closed + forming as last)
extern datetime g_simNow; extern double g_simBid, g_simAsk;
extern int g_digits; extern double g_point;
#define _Symbol string("XAUUSD")
#define _Digits g_digits
#define _Point g_point
inline int PeriodSeconds(ENUM_TIMEFRAMES tf=PERIOD_M5){ return (int)tf*60; }
inline std::vector<SimBar>& SimTf(ENUM_TIMEFRAMES tf){ return g_sim[(int)tf]; }
// series index s: 0 = forming (last element)
inline int CopyRates(const string&, ENUM_TIMEFRAMES tf, int start, int count, MqlArray<MqlRates>& r){
  auto& v = SimTf(tf); int n=(int)v.size(); int newest = n-1-start; if(newest<0) return -1;
  int oldest = std::max(0, newest-count+1); r.v.clear();
  for(int i=oldest;i<=newest;i++){ MqlRates x{v[i].t,v[i].o,v[i].h,v[i].l,v[i].c,0,0,0}; r.v.push_back(x); }
  return (int)r.v.size();
}
inline int CopyRates(const string&, ENUM_TIMEFRAMES tf, datetime from, datetime to, MqlArray<MqlRates>& r){
  auto& v = SimTf(tf); r.v.clear();
  for(auto& b: v){ if(b.t>=from && b.t<=to && b.t+PeriodSeconds(tf)<=g_simNow){ MqlRates x{b.t,b.o,b.h,b.l,b.c,0,0,0}; r.v.push_back(x);} }
  return (int)r.v.size();
}
inline const SimBar* SimAt(ENUM_TIMEFRAMES tf, int s){ auto& v=SimTf(tf); int i=(int)v.size()-1-s; if(i<0||i>=(int)v.size()) return nullptr; return &v[i]; }
inline datetime iTime(const string&, ENUM_TIMEFRAMES tf, int s){ auto b=SimAt(tf,s); return b?b->t:0; }
inline double iOpen(const string&, ENUM_TIMEFRAMES tf, int s){ auto b=SimAt(tf,s); return b?b->o:0; }
inline double iHigh(const string&, ENUM_TIMEFRAMES tf, int s){ auto b=SimAt(tf,s); return b?b->h:0; }
inline double iLow(const string&, ENUM_TIMEFRAMES tf, int s){ auto b=SimAt(tf,s); return b?b->l:0; }
inline double SymbolInfoDouble(const string&, int p){ return p==SYMBOL_BID? g_simBid : g_simAsk; }
inline datetime TimeCurrent(){ return g_simNow; }
inline datetime TimeTradeServer(){ return g_simNow; }
inline datetime TimeGMT(){ return g_simNow; }
inline void TimeToStruct(datetime t, MqlDateTime& d){ long long s=t%86400; if(s<0)s+=86400; d.hour=(int)(s/3600); d.min=(int)((s%3600)/60); d.sec=(int)(s%60); d.year=2026; d.mon=1; d.day=1; d.day_of_week=1; d.day_of_year=1; }
extern ulong g_us; inline ulong GetMicrosecondCount(){ return g_us; } inline uint GetTickCount(){ return (uint)(g_us/1000); }

inline string DoubleToString(double v, int d){ char b[64]; snprintf(b,64,"%.*f",d,v); return b; }
inline string IntegerToString(long long v){ return std::to_string(v); }
template<class T> T fmtArg(T v){ return v; }
inline const char* fmtArg(const std::string& s){ return s.c_str(); }
template<class... A> string StringFormat(const string& f, A... a){ char b[2048]; snprintf(b,2048,f.c_str(), fmtArg(a)...); return b; }
template<class... A> void PrintFormat(const string& f, A... a){ (void)StringFormat(f,a...); }
inline void Print(const string&){}

// objects
struct SimObj { int type; datetime t[2]; double p[2]; string text; };
extern std::map<string,SimObj> g_objs;
inline int ObjectFind(long, const string& n){ return g_objs.count(n)?0:-1; }
inline bool ObjectCreate(long, const string& n, int type, int, datetime t1, double p1, datetime t2=0, double p2=0){ if(g_objs.count(n)) return false; g_objs[n]=SimObj{type,{t1,t2},{p1,p2},""}; return true; }
inline bool ObjectMove(long, const string& n, int i, datetime t, double p){ if(!g_objs.count(n)) return false; g_objs[n].t[i]=t; g_objs[n].p[i]=p; return true; }
inline bool ObjectSetInteger(long, const string& n, int, long long){ return g_objs.count(n)>0; }
inline bool ObjectSetString(long, const string& n, int prop, const string& v){ if(!g_objs.count(n)) return false; if(prop==OBJPROP_TEXT) g_objs[n].text=v; return true; }
inline bool ObjectDelete(long, const string& n){ return g_objs.erase(n)>0; }
inline int ObjectsDeleteAll(long, const string& pre){ int c=0; for(auto it=g_objs.begin(); it!=g_objs.end();){ if(it->first.rfind(pre,0)==0){ it=g_objs.erase(it); c++; } else ++it; } return c; }
inline void ChartRedraw(long){}
enum ENUM_CHART_PROPERTY_DOUBLE { CHART_PRICE_MAX=1, CHART_PRICE_MIN };
enum ENUM_CHART_PROPERTY_INTEGER { CHART_HEIGHT_IN_PIXELS=1 };
extern double g_chartMax, g_chartMin;
inline double ChartGetDouble(long, ENUM_CHART_PROPERTY_DOUBLE p, int sub=0){ return p==CHART_PRICE_MAX? g_chartMax : g_chartMin; }
inline long ChartGetInteger(long, ENUM_CHART_PROPERTY_INTEGER, int sub=0){ return 620; }
