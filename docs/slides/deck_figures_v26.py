# Figures added to the "Research Update" deck in v26 (22 November 2026): robustness of the three
# margins, processing tested on dairy only, and the Step II preview (producer side).
# Every number is read from results_reference/RESULTS_v26_2026-11-22.xlsx (no number typed by hand):
#   ROB_01 robustness, VC_08 processed by quintile, VC_12 processed dairy,
#   S2A_01 farm-gate vs consumer price, S2A_02 producers and sales, S2A_03 who buys.
# Run from anywhere: python3 docs/slides/deck_figures_v26.py  -> docs/slides/fig_*_v26.png
import os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager as fm
from matplotlib.lines import Line2D
from matplotlib.patches import Patch
import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
REF = os.path.join(HERE, '..', '..', 'results_reference', 'RESULTS_v26_2026-11-22.xlsx')
X = pd.read_excel(REF, sheet_name=None)
for f in fm.findSystemFonts():
    if 'Carlito' in f: fm.fontManager.addfont(f)
plt.rcParams.update({'font.family': 'Carlito', 'font.size': 20, 'axes.edgecolor': '#8FA3BF',
                     'axes.labelcolor': '#4A5A74', 'xtick.color': '#4A5A74', 'ytick.color': '#4A5A74'})
INK = '#002060'; INK2 = '#4A5A74'; GRID = '#E3E8EF'
CC = {'MWI': 'Malawi', 'ETH': 'Ethiopia', 'UGA': 'Uganda', 'TZA': 'Tanzania', 'NGA': 'Nigeria'}
C = {'Malawi': '#0B7A39', 'Ethiopia': '#E08A2E', 'Uganda': '#7a4fc0', 'Tanzania': '#1d4f91', 'Nigeria': '#d6457f'}
W, H = 10.8, 6.12
out = lambda n: os.path.join(HERE, n)


def sheet(prefix):
    """Sheet whose name starts with prefix (Excel cuts names at 31 characters)."""
    k = [n for n in X if n.startswith(prefix)]
    assert len(k) == 1, prefix
    return X[k[0]]


def spread(items, gap):
    items = sorted(items, key=lambda t: t[1]); res = []; prev = -1e9
    for name, y in items:
        y2 = max(y, prev + gap); res.append((name, y2)); prev = y2
    return res


def r0(v):
    """Round half up (Python's format rounds 94.5 to 94): the slide text uses the same numbers."""
    import math
    return int(math.floor(v + 0.5))


def clean(ax):
    for s in ['top', 'right', 'left']: ax.spines[s].set_visible(False)
    ax.tick_params(length=0); ax.set_axisbelow(True)


# ---------- Robustness: value-per-kilo share of the meat response, eleven specifications
rb = sheet('ROB_01')
SPECS = [('S0_base', 'Base (as Figure 2)'), ('S1_food_spend', 'Food spending as welfare'),
         ('S2_other_scale', 'Other household scale'), ('S3_cluster_fe', 'Village-cluster effects'),
         ('S4_trim_5_95', 'Trim unit values 5-95%'), ('S5_no_trim', 'No trimming'),
         ('S6_unweighted', 'Unweighted'), ('S7_rural', 'Rural households'), ('S8_urban', 'Urban households'),
         ('S9_iv_lag', 'IV: spending in previous round'), ('S10_beef_only', 'Beef only')]
fig, ax = plt.subplots(figsize=(W, H), dpi=200)
n = len(SPECS)
ax.axhspan(n - 1 - 0.45, n - 1 + 0.45, color='#EEF1F5', zorder=0)
for i, (sp, lab) in enumerate(SPECS):
    y = n - 1 - i
    for k, c in CC.items():
        r = rb[(rb.country == k) & (rb.spec == sp) & (rb['product'].isin(['meat_agg', 'beef (S10)']))]
        if len(r) and pd.notna(r.iloc[0].sh_qual):
            ax.scatter(100 * r.iloc[0].sh_qual, y, s=150, color=C[c], edgecolor='white', linewidth=1.2, zorder=3)
    ax.text(-0.3, y, lab, ha='right', va='center', fontsize=18, color=INK if i == 0 else INK2,
            fontweight='bold' if i == 0 else 'normal')
mx = 100 * rb[rb.spec.isin([s for s, _ in SPECS]) & rb['product'].isin(['meat_agg', 'beef (S10)'])].sh_qual.max()
ax.axvline(mx, color='#B5651D', lw=1.5, ls=(0, (4, 3)), zorder=1)
ax.text(mx - 0.25, -0.45, f'highest: {r0(mx)}% (beef only, Ethiopia)', color='#B5651D', fontsize=16, va='center', ha='right')
ax.set_xlim(0, 16); ax.set_ylim(-0.8, n - 0.3)
ax.set_xticks(range(0, 16, 5)); ax.set_xticklabels([f'{t}%' for t in range(0, 16, 5)], fontsize=18)
ax.set_yticks([]); ax.grid(axis='x', color=GRID, lw=1); clean(ax)
ax.set_xlabel('Value per kilo, % of the income response of meat spending', fontsize=17)
ax.legend(handles=[Line2D([], [], marker='o', ls='', ms=12, color=C[c], label=c) for c in CC.values()],
          loc='lower center', bbox_to_anchor=(0.32, 1.0), ncol=5, frameon=False, fontsize=17,
          handletextpad=0.1, columnspacing=0.8)
fig.subplots_adjust(left=0.33, right=0.97, top=0.9, bottom=0.13); fig.savefig(out('fig_robust_v26.png')); plt.close(fig)

# ---------- Processing, dairy only: households buying industrial dairy and its share of dairy spending
v8 = sheet('VC_08'); v12 = sheet('VC_12')
DC = ['NGA', 'MWI', 'TZA', 'UGA']
fig, axs = plt.subplots(1, 2, figsize=(W, H), dpi=200)
panels = [(axs[0], 'Households buying industrial dairy',
           {CC[k]: v8[(v8.country == k) & (v8.cat_lab == 'Industrial dairy')].sort_values('qt').pct_buying.tolist() for k in DC}, 60),
          (axs[1], 'Industrial dairy, share of dairy spending',
           {CC[k]: v12[v12.country == k].sort_values('qt').industrial_pct_of_dairy_spending.tolist() for k in DC}, 100)]
for ax, title, series, ymax in panels:
    xs = [1, 2, 3, 4, 5]
    for c, v in series.items():
        ax.plot(xs, v, color=C[c], lw=3, marker='o', ms=7, mec='white', mew=1.2, zorder=3)
    for name, y in spread([(c, v[-1]) for c, v in series.items()], ymax * 0.07):
        ax.text(5.2, y, f"{name} {r0(series[name][-1])}%", color=C[name], fontsize=17, fontweight='bold', va='center')
    ax.set_xlim(0.7, 7.6); ax.set_ylim(0, ymax)
    ax.set_xticks(xs); ax.set_xticklabels(['Q1', 'Q2', 'Q3', 'Q4', 'Q5'], fontsize=17)
    ticks = list(range(0, ymax + 1, 20))
    ax.set_yticks(ticks); ax.set_yticklabels([f'{t}%' for t in ticks], fontsize=16)
    ax.grid(axis='y', color=GRID, lw=1); clean(ax)
    ax.set_title(title, fontsize=19, color=INK, fontweight='bold', loc='left', pad=10)
fig.text(0.5, 0.015, 'Income fifth: Q1 poorest, Q5 richest.  Uganda: 2018-19 only.  '
         'Ethiopia lists no industrial dairy item', ha='center', fontsize=15, color=INK2)
fig.tight_layout(rect=(0, 0.05, 1, 1), w_pad=1.5); fig.savefig(out('fig_dairy_v26.png')); plt.close(fig)

# ---------- Step II A: farm-gate price as % of the consumer price
s1 = sheet('S2A_01')
rows = [('milk', 'ETH'), ('milk', 'TZA'), ('milk', 'UGA'), ('milk', 'NGA'), ('milk', 'MWI'),
        ('eggs', 'TZA'), ('eggs', 'UGA'), ('eggs', 'MWI')]
fig, ax = plt.subplots(figsize=(W, H), dpi=200)
y = 0; yt = []; yl = []
for i, (p, k) in enumerate(rows):
    if i == 5: y += 0.7
    r = s1[(s1['product'] == p) & (s1.country == k) & s1.farmgate_pct_of_consumer.notna()]
    v = r.farmgate_pct_of_consumer.tolist()
    ax.plot([min(v), max(v)], [-y, -y], color=C[CC[k]], lw=6, alpha=0.25, solid_capstyle='round', zorder=1)
    ax.scatter(v, [-y] * len(v), s=70, color=C[CC[k]], alpha=0.55, edgecolor='none', zorder=2)
    md = pd.Series(v).median()
    ax.scatter([md], [-y], s=260, color=C[CC[k]], edgecolor='white', linewidth=1.5, zorder=3)
    ax.text(md + 3.2, -y, f'{r0(md)}%', ha='left', va='center', fontsize=17, color=C[CC[k]], fontweight='bold',
            bbox=dict(facecolor='white', edgecolor='none', pad=0.5, alpha=0.85), zorder=4)
    thin = r.n_sellers_price.median() < 50
    yt.append(-y); yl.append(f"{CC[k]}{'*' if thin else ''}  ({', '.join(str(int(a))[2:] for a in r.year)})")
    y += 1
ax.axvline(100, color='#8FA3BF', lw=1.5, ls=(0, (4, 3)))
ax.text(100, 0.75, 'same price', ha='center', fontsize=15, color=INK2)
ax.text(-2, 0.75, 'Fresh milk', ha='right', fontsize=19, color=INK, fontweight='bold')
ax.text(-2, -5.7 + 0.95, 'Eggs', ha='right', fontsize=19, color=INK, fontweight='bold')
for t, l in zip(yt, yl): ax.text(-2, t, l, ha='right', va='center', fontsize=16, color=INK2)
ax.set_xlim(0, 112); ax.set_ylim(-y + 0.4, 1.2)
ax.set_xticks(range(0, 101, 20)); ax.set_xticklabels([f'{t}%' for t in range(0, 101, 20)], fontsize=17)
ax.set_yticks([]); ax.grid(axis='x', color=GRID, lw=1); clean(ax)
ax.set_xlabel('Farm-gate price, % of the price paid by buying households', fontsize=17)
fig.subplots_adjust(left=0.36, right=0.97, top=0.97, bottom=0.13); fig.savefig(out('fig_farmgate_v26.png')); plt.close(fig)

# ---------- Step II A: producers who sell milk by income fifth, and to whom they sell
s2 = sheet('S2A_02'); s3 = sheet('S2A_03')
fig, axs = plt.subplots(1, 2, figsize=(W, H), dpi=200, gridspec_kw={'width_ratios': [1.05, 1]})
ax = axs[0]; xs = [1, 2, 3, 4, 5]
series = {CC[k]: s2[(s2.country == k) & (s2['product'] == 'milk')].sort_values('qt').pct_of_producers_selling.tolist()
          for k in ['ETH', 'TZA', 'UGA', 'MWI']}
for c, v in series.items():
    ax.plot(xs, v, color=C[c], lw=3, marker='o', ms=7, mec='white', mew=1.2, zorder=3)
for name, yv in spread([(c, v[-1]) for c, v in series.items()], 6):
    ax.text(5.2, yv, f"{name} {r0(series[name][-1])}%", color=C[name], fontsize=16, fontweight='bold', va='center')
for name, yv in spread([(c, v[0]) for c, v in series.items()], 5):
    ax.text(0.8, yv, f"{r0(series[name][0])}%", color=C[name], fontsize=15, va='center', ha='right')
ax.set_xlim(0.2, 7.4); ax.set_ylim(0, 80)
ax.set_xticks(xs); ax.set_xticklabels(['Q1', 'Q2', 'Q3', 'Q4', 'Q5'], fontsize=16)
ax.set_yticks(range(0, 81, 20)); ax.set_yticklabels([f'{t}%' for t in range(0, 81, 20)], fontsize=15)
ax.grid(axis='y', color=GRID, lw=1); clean(ax)
ax.set_title('Milk producers who sell', fontsize=19, color=INK, fontweight='bold', loc='left', pad=10)
ax = axs[1]
CATS = [('pct_neighbours_relatives', 'Neighbours, relatives', '#8FA3BF'), ('pct_at_a_market', 'At a market', '#0B7A39'),
        ('pct_traders_shops_processors', 'Traders, shops, processors', '#002060'), ('pct_other', 'Other', '#CED5DF')]
BR = [('UGA', 'milk', 'Uganda, milk'), ('TZA', 'milk', 'Tanzania, milk'), ('MWI', 'milk', 'Malawi, milk'),
      ('UGA', 'eggs', 'Uganda, eggs'), ('MWI', 'eggs', 'Malawi, eggs')]
for i, (k, p, lab) in enumerate(BR):
    r = s3[(s3.country == k) & (s3['product'] == p)].iloc[0]; left = 0
    yrs = str(r.rounds).split()
    for key, _, col in CATS:
        w = r.get(key, 0); w = 0 if pd.isna(w) else w
        ax.barh(-i, w, left=left, height=0.7, color=col, edgecolor='white', linewidth=1)
        if w >= 12:
            ax.text(left + w / 2, -i, f'{r0(w)}', ha='center', va='center', fontsize=15, fontweight='bold',
                    color='white' if key != 'pct_neighbours_relatives' else INK)
        left += w
    ax.text(-2, -i + 0.06, lab, ha='right', va='center', fontsize=15, color=INK)
    ax.text(-2, -i - 0.3, f"{yrs[0]}-{yrs[-1][2:]}" if len(yrs) > 1 else yrs[0], ha='right', va='center',
            fontsize=12.5, color=INK2)
ax.set_xlim(0, 100); ax.set_ylim(-len(BR) + 0.4, 0.6); ax.axis('off')
ax.set_title('Who buys from producers (% of sellers)', fontsize=19, color=INK, fontweight='bold', loc='left', pad=10, x=-0.38)
ax.legend(handles=[Patch(color=col, label=l) for _, l, col in CATS[:3]], loc='upper center',
          bbox_to_anchor=(0.3, -0.02), ncol=1, frameon=False, fontsize=14.5, handlelength=0.9)
fig.text(0.02, 0.015, 'Income fifth of the producing household; mean over rounds', fontsize=14, color=INK2)
fig.tight_layout(rect=(0, 0.04, 1, 1), w_pad=8); fig.savefig(out('fig_producers_v26.png')); plt.close(fig)
print('ok')
