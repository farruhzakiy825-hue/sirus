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
enum ENUM_TIMEFRAMES { PERIOD_CURRENT=0, PERIOD_M1=1, PERIOD_M5=5, PERIOD_M15=15, PERIOD_H1=60, PERIOD_H4=240, PERIOD_D1=1440, PERIOD_W1=10080 };
enum { SYMBOL_BID=1, SYMBOL_ASK=2 };
enum { INIT_SUCCEEDED=0 };
enum { OBJ_TREND=1, OBJ_RECTANGLE, OBJ_TEXT, OBJ_LABEL, OBJ_RECTANGLE_LABEL, OBJ_ARROW };
enum { OBJPROP_SELECTABLE=1, OBJPROP_HIDDEN, OBJPROP_RAY_RIGHT, OBJPROP_COLOR, OBJPROP_STYLE, OBJPROP_WIDTH, OBJPROP_BACK, OBJPROP_FILL,
       OBJPROP_ANCHOR, OBJPROP_TEXT, OBJPROP_FONT, OBJPROP_FONTSIZE, OBJPROP_CORNER, OBJPROP_XDISTANCE, OBJPROP_YDISTANCE,
       OBJPROP_BORDER_TYPE, OBJPROP_XSIZE, OBJPROP_YSIZE, OBJPROP_BGCOLOR, OBJPROP_ARROWCODE };
enum { BORDER_FLAT=0 };
enum { STYLE_SOLID=0, STYLE_DASH, STYLE_DOT, STYLE_DASHDOT };
enum ENUM_ANCHOR_POINT { ANCHOR_LEFT=0, ANCHOR_LEFT_UPPER, ANCHOR_RIGHT_UPPER, ANCHOR_CENTER, ANCHOR_RIGHT };
enum ENUM_ARROW_ANCHOR { ANCHOR_TOP=10, ANCHOR_BOTTOM };
enum { CORNER_LEFT_UPPER=0 };
#define clrBlack 0u
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
inline int PeriodSeconds(ENUM_TIMEFRAMES tf=PERIOD_CURRENT){ if(tf==PERIOD_CURRENT) tf=PERIOD_M5; return (int)tf*60; }
inline std::vector<SimBar>& SimTf(ENUM_TIMEFRAMES tf){ if(tf==PERIOD_CURRENT) tf=PERIOD_M5; return g_sim[(int)tf]; }
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
inline void TimeToStruct(datetime t, MqlDateTime& d){ long long s=t%86400; if(s<0)s+=86400; d.hour=(int)(s/3600); d.min=(int)((s%3600)/60); d.sec=(int)(s%60); d.year=2026; d.mon=1; d.day=1+(int)((t/86400)%28); d.day_of_week=1; d.day_of_year=(int)((t/86400)%365); }
extern ulong g_us; inline ulong GetMicrosecondCount(){ return g_us; } inline uint GetTickCount(){ return (uint)(g_us/1000); }

inline string DoubleToString(double v, int d){ char b[64]; snprintf(b,64,"%.*f",d,v); return b; }
inline string IntegerToString(long long v){ return std::to_string(v); }
template<class T> T fmtArg(T v){ return v; }
inline const char* fmtArg(const std::string& s){ return s.c_str(); }
template<class... A> string StringFormat(const string& f, A... a){ char b[2048]; snprintf(b,2048,f.c_str(), fmtArg(a)...); return b; }
template<class... A> void PrintFormat(const string& f, A... a){ (void)StringFormat(f,a...); }
inline void Print(const string&){}

// objects
struct SimObj { int type; datetime t[2]; double p[2]; string text; std::map<int,long long> ip; std::map<int,string> sp; long long seq=0; };
inline long long& SimSeq(){ static long long s=0; return s; }
extern std::map<string,SimObj> g_objs;
inline int ObjectFind(long, const string& n){ return g_objs.count(n)?0:-1; }
inline bool ObjectCreate(long, const string& n, int type, int, datetime t1, double p1, datetime t2=0, double p2=0){ if(g_objs.count(n)) return false; SimObj o; o.seq=++SimSeq(); o.type=type; o.t[0]=t1; o.t[1]=t2; o.p[0]=p1; o.p[1]=p2; g_objs[n]=o; return true; }
inline bool ObjectMove(long, const string& n, int i, datetime t, double p){ if(!g_objs.count(n)) return false; g_objs[n].t[i]=t; g_objs[n].p[i]=p; return true; }
inline bool ObjectSetInteger(long, const string& n, int prop, long long v){ if(!g_objs.count(n)) return false; g_objs[n].ip[prop]=v; return true; }
inline bool ObjectSetString(long, const string& n, int prop, const string& v){ if(!g_objs.count(n)) return false; if(prop==OBJPROP_TEXT) g_objs[n].text=v; g_objs[n].sp[prop]=v; return true; }
inline bool ObjectDelete(long, const string& n){ return g_objs.erase(n)>0; }
inline int ObjectsDeleteAll(long, const string& pre){ int c=0; for(auto it=g_objs.begin(); it!=g_objs.end();){ if(it->first.rfind(pre,0)==0){ it=g_objs.erase(it); c++; } else ++it; } return c; }
inline void ChartRedraw(long){}
enum ENUM_CHART_PROPERTY_DOUBLE { CHART_PRICE_MAX=1, CHART_PRICE_MIN };
enum ENUM_CHART_PROPERTY_INTEGER { CHART_HEIGHT_IN_PIXELS=1, CHART_WIDTH_IN_PIXELS, CHART_COLOR_BACKGROUND };
extern double g_chartMax, g_chartMin;
inline double ChartGetDouble(long, ENUM_CHART_PROPERTY_DOUBLE p, int =0){ return p==CHART_PRICE_MAX? g_chartMax : g_chartMin; }
inline long ChartGetInteger(long, ENUM_CHART_PROPERTY_INTEGER p, int =0){ if(p==CHART_WIDTH_IN_PIXELS) return 1400; if(p==CHART_COLOR_BACKGROUND) return 0x1C1511; return 760; }

enum { TERMINAL_SCREEN_DPI=1 }; inline long TerminalInfoInteger(int){ return 96; }
static string g_tfont; static int g_tsize=90;
inline bool TextSetFont(const string& f, int sz){ g_tfont=f; g_tsize = sz<0? -sz : sz*10; return true; }
inline int Utf8Len(const string& t){ int n=0; for(unsigned char c: t) if((c&0xC0)!=0x80) n++; return n; }
inline bool TextGetSize(const string& t, uint& w, uint& h){ double k = (g_tfont.find("Consolas")!=string::npos)?0.62:0.56; w=(uint)(Utf8Len(t)*g_tsize/10.0*1.333*k); h=(uint)(g_tsize/10.0*1.333); return true; }
inline int StringLen(const string& t){ return Utf8Len(t); }
inline string StringSubstr(const string& t, int start, int len=-1){ // utf8-aware
  std::vector<size_t> idx; for(size_t i=0;i<t.size();i++) if(((unsigned char)t[i]&0xC0)!=0x80) idx.push_back(i); idx.push_back(t.size());
  int n=(int)idx.size()-1; if(start>=n) return ""; int e = (len<0)? n : std::min(n,start+len); return t.substr(idx[start], idx[e]-idx[start]); }
inline double MathSqrt(double x){ return std::sqrt(x); }
enum { CHARTEVENT_CHART_CHANGE=9 };
enum { MQL_TESTER=1, MQL_OPTIMIZATION=2 }; extern int g_isTester; inline long MQLInfoInteger(int p){ return p==MQL_TESTER? g_isTester : 0; }
// files (real files under ./files)
enum { FILE_READ=1, FILE_WRITE=2, FILE_BIN=4, FILE_COMMON=8, FILE_TXT=16, FILE_ANSI=32, FILE_SHARE_READ=64 };
enum { INT_VALUE=4 }; const int INVALID_HANDLE=-1;
static FILE* g_fh[16];
inline int FileOpen(const string& n, int flags){ string p="files_"+n; FILE* f=fopen(p.c_str(), ((flags&FILE_WRITE)&&(flags&FILE_READ))?"a+b":((flags&FILE_WRITE)?"wb":"rb")); if(!f) return INVALID_HANDLE; for(int i=0;i<16;i++) if(!g_fh[i]){ g_fh[i]=f; return i; } fclose(f); return INVALID_HANDLE; }
inline void FileClose(int h){ if(h>=0&&g_fh[h]){ fclose(g_fh[h]); g_fh[h]=nullptr; } }
inline bool FileIsExist(const string& n, int){ string p="files_"+n; FILE* f=fopen(p.c_str(),"rb"); if(f){ fclose(f); return true;} return false; }
inline uint FileWriteInteger(int h, int v, int){ return (uint)fwrite(&v,4,1,g_fh[h])*4; }
inline uint FileWriteLong(int h, long long v){ return (uint)fwrite(&v,8,1,g_fh[h])*8; }
inline uint FileWriteDouble(int h, double v){ return (uint)fwrite(&v,8,1,g_fh[h])*8; }
inline uint FileWriteString(int h, const string& s){ return (uint)fwrite(s.data(),1,s.size(),g_fh[h]); }
inline int FileReadInteger(int h, int){ int v=0; if(fread(&v,4,1,g_fh[h])!=1) return 0; return v; }
inline long long FileReadLong(int h){ long long v=0; if(fread(&v,8,1,g_fh[h])!=1) return 0; return v; }
inline double FileReadDouble(int h){ double v=0; if(fread(&v,8,1,g_fh[h])!=1) return 0; return v; }
inline unsigned long long FileSize(int h){ long cur=ftell(g_fh[h]); fseek(g_fh[h],0,SEEK_END); long e=ftell(g_fh[h]); fseek(g_fh[h],cur,SEEK_SET); return (unsigned long long)e; }
inline bool FileSeek(int h, long long off, int origin){ return fseek(g_fh[h],(long)off,origin)==0; }
inline int StringReplace(string& s, const string& f, const string& r){ if(f.empty()) return 0; int c=0; size_t p=0; while((p=s.find(f,p))!=string::npos){ s.replace(p,f.size(),r); p+=r.size(); c++; } return c; }
