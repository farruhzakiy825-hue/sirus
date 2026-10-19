#include <array>
#include "v9.cpp"
#include <random>
std::map<int, std::vector<SimBar>> g_sim; datetime g_simNow=0; double g_simBid=0, g_simAsk=0;
double g_chartMax=0, g_chartMin=0; int g_digits=3; double g_point=0.001; ulong g_us=0; std::map<string,SimObj> g_objs;
static const int TFS[7]={1,5,15,60,240,1440,10080};
static int fails=0;
#define CHECK(c, msg) do{ if(!(c)){ if(fails<25) printf("FAIL t=%lld: %s\n",(long long)g_simNow,msg); fails++; } }while(0)

void simTick(datetime t, double p){
  g_simNow=t; g_simBid=p; g_simAsk=p+0.24;
  for(int tf: TFS){ auto& v=g_sim[tf]; datetime b = t - (t % (tf*60));
    if(v.empty() || v.back().t!=b) v.push_back(SimBar{b,p,p,p,p});
    else { auto& x=v.back(); x.h=std::max(x.h,p); x.l=std::min(x.l,p); x.c=p; } }
}

void updChart(){ auto& v=g_sim[5]; int n=(int)v.size(); if(n<2) return; double hi=-1e18, lo=1e18; for(int i=std::max(0,n-110);i<n;i++){ hi=std::max(hi,v[i].h); lo=std::min(lo,v[i].l);} g_chartMax=hi; g_chartMin=lo; }
void checkInvariants(){
  for(int tfi=0; tfi<V9_TF_N; tfi++){
    if(!g_ready[tfi]) continue;
    int n=g_nbar[tfi];
    // swings: no look-ahead
    int len=(tfi==V9_M1)?V9_SWING_LEN_M1:V9_SWING_LEN_HTF;
    for(int s=0;s<g_nsw[tfi];s++) CHECK(g_sw[tfi][s].bi+len<=n-1, "swing look-ahead");
    // pending age
    for(int p=0;p<V9_PEND_MAX;p++) if(g_pend[tfi][p].on) CHECK(n-1-g_pend[tfi][p].bi < V9_FAIL_BARS, "stale pending");
    SLegState& L=g_leg[tfi];
    if(L.dir!=0){
      int d=L.dir; double atr=g_bar[tfi][n-1].atr; double c=g_bar[tfi][n-1].c;
      CHECK(L.originBi>=0 && L.originBi<n && L.himoyaBi>=0 && L.himoyaBi<n && L.extBi>=0 && L.extBi<n, "leg index range");
      CHECK(d*(L.ext-L.himoya)>=-1e-9, "ext behind himoya");
      CHECK(d*(L.ext-L.origin)>=-1e-9, "ext behind origin");
      CHECK(d*(c-L.himoya) >= -V9_SINDI_BUF_ATR*atr-1e-9, "close beyond himoya but leg alive (SINDI missed)");
      CHECK(L.waves>=1, "waves");
    }
    SLegView& v=g_lv[tfi];
    if(v.ok){
      CHECK(v.stage>=STG_TUGILDI && v.stage<=STG_TUGADI, "stage range");
      CHECK(v.zone>=PBZ_YURISH && v.zone<=PBZ_SINOV, "zone range");
      if(v.targetIdx>=0){ CHECK(v.dir*(v.target-v.ext)>0, "target not ahead of extreme"); CHECK(g_pool[v.targetIdx].side==v.dir, "target side"); }
      if(v.zone!=PBZ_SINOV) CHECK(v.pullback>=-1e-9 && v.pullback<=1.0+1e-9, "pullback range outside SINOV");
      CHECK(v.revStage==0 || (v.revStage>=3 && v.revStage<=6), "revStage");
    }
  }
  for(int i=0;i<g_npool;i++){ CHECK(g_pool[i].cls>=1&&g_pool[i].cls<=5,"pool cls"); CHECK(g_pool[i].side==1||g_pool[i].side==-1,"pool side"); }
  for(int z=0;z<g_nzone;z++) CHECK(g_zone[z].lo<g_zone[z].hi, "zone lo<hi");
  CHECK((int)g_objs.size()<400, "too many objects");
}

// --- scenario tests on M5 directly ---
void setBars(int tfi, const std::vector<std::array<double,4>>& b){
  g_nbar[tfi]=(int)b.size(); double sum=0; std::vector<double> tr;
  for(size_t i=0;i<b.size();i++){ auto& x=g_bar[tfi][i]; x.t=1000000+ (datetime)i*300; x.tc=x.t+300; x.o=b[i][0]; x.h=b[i][1]; x.l=b[i][2]; x.c=b[i][3];
    double t=x.h-x.l; if(i>0){ t=std::max(t,std::fabs(x.h-b[i-1][3])); t=std::max(t,std::fabs(x.l-b[i-1][3])); } tr.push_back(t); sum+=t; if(i>=V9_ATR_N) sum-=tr[i-V9_ATR_N]; x.atr=sum/std::min((int)i+1,V9_ATR_N); }
  g_ready[tfi]=true;
}
// zigzag helper: from price a to b in k bars with small noise, bar range ~1
void leg(std::vector<std::array<double,4>>& v, double a, double b, int k){
  for(int i=0;i<k;i++){ double o=a+(b-a)*i/k, c=a+(b-a)*(i+1)/k; double h=std::max(o,c)+0.3, l=std::min(o,c)-0.3; v.push_back({o,h,l,c}); }
}
void scenarios(){
  // A: down move then up trend with higher lows
  std::vector<std::array<double,4>> v;
  leg(v,110,100,10); leg(v,100,106,6); leg(v,106,103,4); leg(v,103,110,6); leg(v,110,107,4); leg(v,107,115,6); leg(v,115,112,3);
  setBars(V9_M5,v); V9EventsRebuild(V9_M5);
  SLegState L=g_leg[V9_M5];
  printf("A: dir=%d origin=%.2f himoya=%.2f ext=%.2f waves=%d conf=%d birth=%s\n",L.dir,L.origin,L.himoya,L.ext,L.waves,L.confirmed,V9EvName(L.birthType).c_str());
  CHECK(L.dir==1,"A: up leg expected"); CHECK(L.himoya>L.origin,"A: himoya trailed above origin"); CHECK(L.waves>=2,"A: >=2 pushes");
  double him=L.himoya;
  // B: a strong bar closing well below himoya, then continuation down -> MSS bear leg, confirmed
  auto vb=v; vb.push_back({112,112.3,him-3,him-2.5}); leg(vb,him-2.5,him-6,3);
  setBars(V9_M5,vb); V9EventsRebuild(V9_M5); L=g_leg[V9_M5];
  printf("B: dir=%d origin=%.2f himoya=%.2f birth=%s conf=%d\n",L.dir,L.origin,L.himoya,V9EvName(L.birthType).c_str(),L.confirmed);
  CHECK(L.dir==-1 && L.birthType==EV_MSS && L.confirmed,"B: confirmed bear MSS leg");
  CHECK(std::fabs(L.origin-115.3)<0.5,"B: new leg origin at old extreme");
  // C: same break but next bar closes back above old himoya -> SOXTA, old leg restored, EV_FAILED recorded
  auto vc=v; vc.push_back({112,112.3,him-3,him-2.5}); vc.push_back({him-2.5,him+2.0,him-2.6,him+1.8}); leg(vc,him+1.8,him+3,2);
  setBars(V9_M5,vc); V9EventsRebuild(V9_M5); L=g_leg[V9_M5];
  bool failed = V9EvFindNewest(V9_M5, EV_FAILED, 0, 0)>=0;
  printf("C: dir=%d himoya=%.2f failedEvent=%d\n",L.dir,L.himoya,failed);
  CHECK(L.dir==1 && failed,"C: fake break restored the up leg");
  CHECK(std::fabs(L.himoya-him)<1e-9,"C: himoya restored");
  // D: deep sweep of a swing high closing back -> EV_SWEEP or EV_FAKE bearish
  auto vd=v; double sh=0; for(int s=0;s<g_nsw[V9_M5];s++){}
  setBars(V9_M5,v); V9EventsRebuild(V9_M5); int si=g_refHi[V9_M5]; sh=g_sw[V9_M5][si].price; (void)sh;
  vd.push_back({112,sh+0.5,111.5,111.8}); setBars(V9_M5,vd); V9EventsRebuild(V9_M5);
  int e=V9EvFindNewest(V9_M5, EV_SWEEP, -1, 0); printf("D: refHi=%.2f sweep found=%d\n", sh, e>=0);
  CHECK(e>=0,"D: sweep of swing high recorded");
  for(int t=0;t<V9_TF_N;t++){ g_ready[t]=false; g_nbar[t]=0; }
}


void dumpJson(const char* path){
  FILE* f=fopen(path,"w"); fprintf(f,"{\"bars\":[");
  auto& v=g_sim[5]; int n=(int)v.size(); int from=std::max(0,n-110);
  for(int i=from;i<n;i++) fprintf(f,"%s[%lld,%.3f,%.3f,%.3f,%.3f]",i>from?",":"",(long long)v[i].t,v[i].o,v[i].h,v[i].l,v[i].c);
  fprintf(f,"],\"objs\":[");
  bool first=true;
  for(auto& o: g_objs){ std::string t=o.second.text; for(auto& ch: t) if(ch=='"') ch='\''; 
    fprintf(f,"%s{\"n\":\"%s\",\"ty\":%d,\"t1\":%lld,\"p1\":%.3f,\"t2\":%lld,\"p2\":%.3f,\"tx\":\"%s\"}",first?"":",",o.first.c_str(),o.second.type,(long long)o.second.t[0],o.second.p[0],(long long)o.second.t[1],o.second.p[1],t.c_str()); first=false; }
  fprintf(f,"],\"now\":%lld,\"bid\":%.3f}",(long long)g_simNow,g_simBid); fclose(f);
}
int main(int argc,char**argv){
  scenarios();
  int seed = argc>1?atoi(argv[1]):42; double gapP = argc>2?atof(argv[2]):0.0;
  std::mt19937 rng(seed); std::normal_distribution<double> N(0,1);
  // 30 days of M1 with regime-switching drift
  double p=4100; datetime t0=1700006400; // a Monday-ish midnight
  int days= argc>4?atoi(argv[4]):30; double drift=0; int regimeLeft=0;
  OnInit();
  long ticks=0; double maxms=0;
  for(int i=0;i<days*1440;i++){
    if(regimeLeft--<=0){ regimeLeft=60+rng()%600; double r=(rng()%100)/100.0; drift = (r<0.35)?0.0:((r<0.67)?0.06:-0.06); }
    double vol=0.55*(1+ (regimeLeft%3));
    if(gapP>0 && (rng()%100000)/100000.0<gapP) p += ((rng()%2)?1.0:-1.0)*(5.0+(double)(rng()%20));
    double o=p, c=p+drift+N(rng)*vol; double h=std::max(o,c)+std::fabs(N(rng))*0.35, l=std::min(o,c)-std::fabs(N(rng))*0.35;
    datetime t=t0+(datetime)i*60;
    double path[4]={o, (rng()%2)?h:l, 0, c}; path[2]=(path[1]==h)?l:h;
    for(int k=0;k<4;k++){ simTick(t+k*15, path[k]); if(i>=13*1440){ g_us+=1000; ulong a=g_us; updChart(); OnTick(); (void)a; ticks++; checkInvariants(); } }
    p=c;
  }
  printf("ticks=%ld fails=%d pools=%d zones=%d objs=%zu\n",ticks,fails,g_npool,g_nzone,g_objs.size());
  for(int tfi=0;tfi<V9_TF_N;tfi++) if(g_lv[tfi].ok) printf("%s: %s | %s\n",V9TFName(tfi).c_str(),V9LegShort(tfi).c_str(),V9LegBirthText(tfi).c_str());
  // print panel
  for(auto& o: g_objs) if(o.first.rfind("SV9_pn_",0)==0) printf("PANEL %s\n",o.second.text.c_str());
  if(argc>3) dumpJson(argv[3]);
  return fails?1:0;
}
