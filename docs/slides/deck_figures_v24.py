# Figures of the "Research Update" deck, v24 (21 November 2026): five countries, fish included,
# and where households' animal foods come from.
# Every number is read from results_reference/RESULTS_v24_2026-11-21.xlsx (no number typed by hand):
#   <C>_14_participation_quintile, MARGINS_01_three_margins, <C>_20_basket_by_quintile,
#   VC_04_sources_by_quintile.
# Run from the repository root: python3 docs/slides/deck_figures_v24.py  -> docs/slides/fig_*_v24.png
import os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager as fm
from matplotlib.patches import Patch
import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
REF = os.path.join(HERE, '..', '..', 'results_reference', 'RESULTS_v24_2026-11-21.xlsx')
X = pd.read_excel(REF, sheet_name=None)
for f in fm.findSystemFonts():
    if 'Carlito' in f: fm.fontManager.addfont(f)
plt.rcParams.update({'font.family': 'Carlito', 'font.size': 20, 'axes.edgecolor': '#8FA3BF',
                     'axes.labelcolor': '#4A5A74', 'xtick.color': '#4A5A74', 'ytick.color': '#4A5A74'})
INK = '#002060'; INK2 = '#4A5A74'
CC = {'MWI': 'Malawi', 'ETH': 'Ethiopia', 'UGA': 'Uganda', 'TZA': 'Tanzania', 'NGA': 'Nigeria'}
C = {'Malawi': '#0B7A39', 'Ethiopia': '#E08A2E', 'Uganda': '#7a4fc0', 'Tanzania': '#1d4f91', 'Nigeria': '#d6457f'}
W, H = 10.8, 6.12
out = lambda n: os.path.join(HERE, n)


def spread(items, gap):
    items = sorted(items, key=lambda t: t[1]); res = []; prev = -1e9
    for name, y in items:
        y2 = max(y, prev + gap); res.append((name, y2)); prev = y2
    return res


def lines_by_quintile(series, ylabel, fname, ymax=100):
    """One line per country over quintiles 1-5, end labels like Figure 1."""
    fig, ax = plt.subplots(figsize=(W, H), dpi=200)
    xs = [1, 2, 3, 4, 5]
    for c, v in series.items():
        ax.plot(xs, v, color=C[c], lw=3, marker='o', ms=8, mec='white', mew=1.5, zorder=3)
    for name, y in spread([(c, v[-1]) for c, v in series.items()], ymax * 0.053):
        ax.text(5.15, y, f"{name} {series[name][-1]:.0f}%", color=C[name], fontsize=21, fontweight='bold', va='center')
    for name, y in spread([(c, v[0]) for c, v in series.items()], ymax * 0.045):
        ax.text(0.85, y, f"{series[name][0]:.0f}%", color=C[name], fontsize=20, va='center', ha='right')
    ax.set_xlim(0.45, 6.35); ax.set_ylim(0, ymax)
    ax.set_xticks(xs); ax.set_xticklabels(['Q1\npoorest', 'Q2', 'Q3', 'Q4', 'Q5\nrichest'], fontsize=20)
    ticks = list(range(0, ymax + 1, 20))
    ax.set_yticks(ticks); ax.set_yticklabels([f'{t}%' for t in ticks], fontsize=19)
    ax.grid(axis='y', color='#E3E8EF', lw=1); ax.set_axisbelow(True)
    for s in ['top', 'right', 'left']: ax.spines[s].set_visible(False)
    ax.tick_params(length=0)
    ax.set_ylabel(ylabel, fontsize=20)
    fig.tight_layout(); fig.savefig(out(fname)); plt.close(fig)


# ---------- Figure 1: households buying meat, by quintile
buy = {}
for k, c in CC.items():
    t = X[f'{k}_14_participation_quintile']; r = t[t['product'] == 'meat_agg'].iloc[0]
    buy[c] = [r[f'Q{q}'] for q in range(1, 6)]
lines_by_quintile(buy, 'Households buying meat (7 days)', 'fig_entry_v24.png', ymax=80)

# ---------- Figure 2: three margins, meat
m = X['MARGINS_01_three_margins']; m = m[m['product'] == 'meat_agg'].set_index('country')
m = m.loc[list(CC)]; m['name'] = [CC[k] for k in m.index]
fig, ax = plt.subplots(figsize=(W, H), dpi=200)
cols = {'e_entry': '#002060', 'e_qty': '#8FA3BF', 'e_qual': '#E08A2E'}
rows = m.iloc[::-1].reset_index(drop=True)
for i, r in rows.iterrows():
    left = 0; tot = r.e_entry + r.e_qty + r.e_qual
    for k in ['e_entry', 'e_qty', 'e_qual']:
        w = r[k] / tot * 100
        ax.barh(i, w, left=left, height=0.62, color=cols[k], edgecolor='white', linewidth=2)
        if k != 'e_qual':
            ax.text(left + w / 2, i, f"{w:.0f}%", ha='center', va='center', color='white' if k == 'e_entry' else INK,
                    fontsize=21, fontweight='bold')
        else:
            ax.text(101.5, i, f"{w:.0f}%", ha='left', va='center', color='#B5651D', fontsize=22, fontweight='bold')
        left += w
    ax.text(-2, i, r['name'], ha='right', va='center', color=INK, fontsize=22)
    ax.text(122, i, f"{tot:.2f}", ha='left', va='center', color=INK2, fontsize=21)
n = len(rows)
ax.text(101.5, n - 0.35, 'Per kilo', color='#B5651D', fontsize=20, fontweight='bold', ha='left')
ax.text(122, n - 0.35, 'Elasticity', color=INK2, fontsize=20, ha='left')
ax.set_xlim(-22, 138); ax.set_ylim(-0.6, n + 0.1); ax.axis('off')
ax.legend(handles=[Patch(color=cols['e_entry'], label='Entry (new buyers)'),
                   Patch(color=cols['e_qty'], label='Quantity (more kilos)'),
                   Patch(color=cols['e_qual'], label='Value per kilo')],
          loc='lower center', bbox_to_anchor=(0.45, -0.13), ncol=3, frameon=False, fontsize=20, handlelength=1.1)
fig.tight_layout(); fig.savefig(out('fig_margins_v24.png')); plt.close(fig)

# ---------- Figure 3: composition of ASF spending, Q1 vs Q5, fish included
cats = [('fish', 'Fish', '#1d8fb0'), ('poultry', 'Poultry', '#2a78d6'), ('beef', 'Beef', '#eb6834'),
        ('goat_sheep', 'Goat & mutton', '#1baf7a'), ('pork', 'Pork', '#eda100'), ('eggs', 'Eggs', '#e87ba4'),
        ('milk', 'Fresh milk', '#008300'), ('other', 'Other dairy', '#6250d6')]
cats[1] = ('poultry', 'Poultry', '#3b4cc0')
fig, ax = plt.subplots(figsize=(W, H), dpi=200)
y = 0
for k, c in CC.items():
    b = X[f'{k}_20_basket_by_quintile']
    for q in [1, 5]:
        d = b[b.qt == q].set_index('product')['share_of_asf_spend'].to_dict()
        d['other'] = d.pop('milk_processed', 0) + d.pop('cheese', 0)
        tot = sum(v for v in d.values() if pd.notna(v)); left = 0
        for key, lab, col in cats:
            w = (d.get(key, 0) or 0) / tot * 100
            ax.barh(-y, w, left=left, height=0.78, color=col, edgecolor='white', linewidth=1.5)
            if w >= 9:
                ax.text(left + w / 2, -y, f"{w:.0f}", ha='center', va='center',
                        color=INK if key == 'pork' else 'white', fontsize=17, fontweight='bold')
            left += w
        ax.text(-1.5, -y, 'Q1 poorest' if q == 1 else 'Q5 richest', ha='right', va='center', fontsize=17, color=INK2)
        y += 1
    ax.text(-26, -(y - 1.5), c, ha='right', va='center', fontsize=21, color=INK, fontweight='bold')
    y += 0.45
ax.set_xlim(-50, 101); ax.set_ylim(-(y - 0.2), 1.0); ax.axis('off')
ax.legend(handles=[Patch(color=col, label=lab) for k, lab, col in cats], loc='upper center',
          bbox_to_anchor=(0.5, 1.07), ncol=8, frameon=False, fontsize=16, handlelength=0.9,
          columnspacing=0.8, handletextpad=0.35)
fig.tight_layout(); fig.savefig(out('fig_basket_v24.png')); plt.close(fig)

# ---------- Figure 4: where milk, eggs and chicken come from, Q1 vs Q5
s = X['VC_04_sources_by_quintile']; s = s[s.households == 'all']
prods = [('Fresh milk', 'Fresh milk'), ('Eggs', 'Eggs'), ('Poultry', 'Chicken and other poultry')]
src = [('pct_purchased', 'Bought', '#002060'), ('pct_own', 'Own production', '#0B7A39'), ('pct_gift', 'Gift', '#E08A2E')]
fig, axs = plt.subplots(1, 3, figsize=(W, H), dpi=200, sharey=True)
for j, (lab, title) in enumerate(prods):
    ax = axs[j]; y = 0; ticks = []; tl = []
    for k, c in CC.items():
        for q in [1, 5]:
            r = s[(s.country == k) & (s.lab == lab) & (s.qt == q)]
            if len(r) and not (k == 'UGA' and lab == 'Poultry'):
                r = r.iloc[0]; tot = r.pct_purchased + r.pct_own + r.pct_gift; left = 0
                for key, _, col in src:
                    w = r[key] / tot * 100
                    ax.barh(-y, w, left=left, height=0.8, color=col, edgecolor='white', linewidth=1)
                    if key == 'pct_purchased' and w >= 14:
                        ax.text(left + w / 2, -y, f"{w:.0f}", ha='center', va='center', color='white',
                                fontsize=15, fontweight='bold')
                    left += w
            else:
                ax.text(50, -y, 'not weighed', ha='center', va='center', color=INK2, fontsize=14, style='italic')
            ticks.append(-y); tl.append(f"{c}  Q{q}" if q == 1 else "Q5")
            y += 1
        y += 0.5
    ax.set_title(title, fontsize=19, color=INK, fontweight='bold', pad=8)
    ax.set_xlim(0, 100); ax.set_xticks([])
    for sp in ax.spines.values(): sp.set_visible(False)
    ax.tick_params(length=0)
    if j == 0:
        ax.set_yticks(ticks); ax.set_yticklabels(tl, fontsize=15, color=INK2)
fig.legend(handles=[Patch(color=col, label=lab) for _, lab, col in src], loc='lower center', ncol=3,
           frameon=False, fontsize=18, bbox_to_anchor=(0.55, -0.01))
fig.tight_layout(rect=(0, 0.06, 1, 1)); fig.savefig(out('fig_sources_v24.png')); plt.close(fig)

# ---------- Figure 5: share of fresh milk that is bought, by quintile
milk = {}
for k, c in CC.items():
    t = s[(s.country == k) & (s.lab == 'Fresh milk')].sort_values('qt')
    milk[c] = t.pct_purchased.tolist()
lines_by_quintile(milk, 'Fresh milk consumed that is bought', 'fig_milk_bought_v24.png', ymax=100)
print('ok')
