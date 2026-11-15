# Figures 1-3 of the "Research Update" deck (November 2026), five countries.
# Numbers copied from results_reference/RESULTS_v23_2026-11-13.xlsx
# (MWI/ETH/UGA/TZA/NGA _14_participation_quintile, MARGINS_01_three_margins, _20_basket_by_quintile).
# Run: python3 deck_figures_v23.py  -> fig_entry.png, fig_margins.png, fig_basket.png
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager as fm
import pandas as pd
for f in fm.findSystemFonts():
    if 'Carlito' in f: fm.fontManager.addfont(f)
plt.rcParams.update({'font.family':'Carlito','font.size':20,'axes.edgecolor':'#8FA3BF','axes.labelcolor':'#4A5A74',
                     'xtick.color':'#4A5A74','ytick.color':'#4A5A74','svg.fonttype':'none'})
INK='#002060'; INK2='#4A5A74'
C={'Malawi':'#0B7A39','Ethiopia':'#E08A2E','Uganda':'#7a4fc0','Tanzania':'#1d4f91','Nigeria':'#d6457f'}
W,H=10.8,6.12
# ---------- Fig A: meat buyers by quintile
buy={'Malawi':[5.6,13.7,23.2,36.0,61.0],'Ethiopia':[4.6,10.2,19.1,28.2,45.8],'Uganda':[19.9,33.0,41.6,50.8,60.9],
     'Tanzania':[15.4,31.1,45.0,58.6,71.1],'Nigeria':[35.2,51.1,57.5,65.1,67.4]}
fig,ax=plt.subplots(figsize=(W,H),dpi=200)
xs=[1,2,3,4,5]
for c,v in buy.items():
    ax.plot(xs,v,color=C[c],lw=3,marker='o',ms=8,mec='white',mew=1.5,zorder=3)
def spread(items,gap):
    items=sorted(items,key=lambda t:t[1]); out=[]; prev=-1e9
    for name,y in items:
        y2=max(y,prev+gap); out.append((name,y2)); prev=y2
    return out
for name,y in spread([(c,v[-1]) for c,v in buy.items()],4.2):
    ax.text(5.15,y,f"{name} {buy[name][-1]:.0f}%",color=C[name],fontsize=21,fontweight='bold',va='center')
for name,y in spread([(c,v[0]) for c,v in buy.items()],3.6):
    ax.text(0.85,y,f"{buy[name][0]:.0f}%",color=C[name],fontsize=20,va='center',ha='right')
ax.set_xlim(0.45,6.35); ax.set_ylim(0,80)
ax.set_xticks(xs); ax.set_xticklabels(['Q1\npoorest','Q2','Q3','Q4','Q5\nrichest'],fontsize=20)
ax.set_yticks([0,20,40,60,80]); ax.set_yticklabels(['0%','20%','40%','60%','80%'],fontsize=19)
ax.grid(axis='y',color='#E3E8EF',lw=1); ax.set_axisbelow(True)
for s in ['top','right','left']: ax.spines[s].set_visible(False)
ax.tick_params(length=0)
ax.set_ylabel('Households buying meat (7 days)',fontsize=20)
fig.tight_layout(); fig.savefig('fig_entry.png'); plt.close(fig)
# ---------- Fig B: three margins, meat
m=pd.DataFrame({'country':['Malawi','Ethiopia','Uganda','Tanzania','Nigeria'],
  'entry':[1.242193,1.092726,0.627480,0.680120,0.494994],'qty':[0.650000,0.676322,0.423849,0.604545,0.514269],
  'qual':[0.079397,0.140100,0.054170,0.069719,0.035964]})
m['tot']=m.entry+m.qty+m.qual
fig,ax=plt.subplots(figsize=(W,H),dpi=200)
cols={'entry':'#002060','qty':'#8FA3BF','qual':'#E08A2E'}
for i,r in m.iloc[::-1].reset_index(drop=True).iterrows():
    left=0
    for k in ['entry','qty','qual']:
        w=r[k]/r.tot*100
        ax.barh(i,w,left=left,height=0.62,color=cols[k],edgecolor='white',linewidth=2)
        if k!='qual':
            ax.text(left+w/2,i,f"{w:.0f}%",ha='center',va='center',color='white' if k=='entry' else INK,fontsize=21,fontweight='bold')
        else:
            ax.text(101.5,i,f"{w:.0f}%",ha='left',va='center',color='#B5651D',fontsize=22,fontweight='bold')
        left+=w
    ax.text(-2,i,r.country,ha='right',va='center',color=INK,fontsize=22)
    ax.text(122,i,f"{r.tot:.2f}",ha='left',va='center',color=INK2,fontsize=21)
n=len(m)
ax.text(101.5,n-0.35,'Quality',color='#B5651D',fontsize=20,fontweight='bold',ha='left')
ax.text(122,n-0.35,'Elasticity',color=INK2,fontsize=20,ha='left')
ax.set_xlim(-22,138); ax.set_ylim(-0.6,n+0.1)
ax.axis('off')
from matplotlib.patches import Patch
ax.legend(handles=[Patch(color=cols['entry'],label='Entry (new buyers)'),Patch(color=cols['qty'],label='Quantity (more kilos)'),
                   Patch(color=cols['qual'],label='Quality (price per kilo)')],loc='lower center',bbox_to_anchor=(0.45,-0.13),
          ncol=3,frameon=False,fontsize=20,handlelength=1.1)
fig.tight_layout(); fig.savefig('fig_margins.png'); plt.close(fig)
# ---------- Fig C: basket Q1 vs Q5
bask={
 'Malawi':{1:{'beef':9.5,'eggs':30.1,'goat_sheep':29.0,'milk':2.7,'milk_processed':1.1,'pork':20.0,'poultry':7.7},5:{'beef':21.4,'eggs':15.6,'goat_sheep':17.7,'milk':8.1,'milk_processed':8.4,'pork':5.9,'poultry':23.0}},
 'Ethiopia':{1:{'beef':54.4,'cheese':4.1,'eggs':6.8,'goat_sheep':17.1,'milk':14.2,'poultry':3.5},5:{'beef':38.8,'cheese':1.8,'eggs':5.5,'goat_sheep':38.2,'milk':8.3,'poultry':7.5}},
 'Uganda':{1:{'beef':54.4,'eggs':2.0,'goat_sheep':14.5,'milk':13.5,'milk_processed':0.6,'pork':13.3,'poultry':2.0},5:{'beef':45.9,'eggs':5.0,'goat_sheep':8.4,'milk':21.5,'milk_processed':2.0,'pork':7.2,'poultry':11.3}},
 'Tanzania':{1:{'beef':51.6,'eggs':2.4,'goat_sheep':18.2,'milk':11.8,'milk_processed':3.5,'pork':8.3,'poultry':4.3},5:{'beef':50.5,'eggs':6.0,'goat_sheep':7.6,'milk':13.2,'milk_processed':2.5,'pork':4.3,'poultry':16.0}},
 'Nigeria':{1:{'beef':58.2,'eggs':1.3,'goat_sheep':25.3,'milk':7.0,'milk_processed':4.0,'pork':1.6,'poultry':2.7},5:{'beef':50.4,'eggs':7.4,'goat_sheep':7.7,'milk':0.8,'milk_processed':14.2,'pork':1.0,'poultry':18.5}}}
cats=[('poultry','Poultry','#2a78d6'),('beef','Beef','#eb6834'),('goat_sheep','Goat & mutton','#1baf7a'),('pork','Pork','#eda100'),
      ('eggs','Eggs','#e87ba4'),('milk','Fresh milk','#008300'),('other','Other dairy','#6250d6')]
fig,ax=plt.subplots(figsize=(W,H),dpi=200)
ypos=[];labels=[];y=0
for c in ['Malawi','Ethiopia','Uganda','Tanzania','Nigeria']:
    for q in [1,5]:
        d=dict(bask[c][q]); d['other']=d.pop('milk_processed',0)+d.pop('cheese',0)
        tot=sum(d.values()); left=0
        for k,lab,col in cats:
            w=d.get(k,0)/tot*100
            ax.barh(-y,w,left=left,height=0.78,color=col,edgecolor='white',linewidth=1.5)
            if w>=9: ax.text(left+w/2,-y,f"{w:.0f}",ha='center',va='center',color='white' if k not in ('pork',) else INK,fontsize=17,fontweight='bold')
            left+=w
        ax.text(-1.5,-y,'Q1 poorest' if q==1 else 'Q5 richest',ha='right',va='center',fontsize=17,color=INK2)
        y+=1
    ax.text(-26,-(y-1.5),c,ha='right',va='center',fontsize=21,color=INK,fontweight='bold')
    y+=0.45
ax.set_xlim(-50,101); ax.set_ylim(-(y-0.2),1.0)
ax.axis('off')
ax.legend(handles=[Patch(color=col,label=lab) for k,lab,col in cats],loc='upper center',bbox_to_anchor=(0.5,1.07),ncol=7,frameon=False,
          fontsize=17,handlelength=1.0,columnspacing=1.0,handletextpad=0.4)
fig.tight_layout(); fig.savefig('fig_basket.png'); plt.close(fig)
print('ok')
