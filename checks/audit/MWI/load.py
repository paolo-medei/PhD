"""Loading helpers for the independent Malawi IHS rebuild (run with python -I)."""
import pandas as pd
import pyreadstat

D = "/home/claude/v20home/Desktop/ASF_DATA/_unzipped"
W1 = D + "/MWI_2010_IHS-III_v01_M_STATA8/MWI_2010_IHS-III_v01_M_STATA8/Full_Sample"
W2 = D + "/MWI_2016_IHS-IV_v04_M_STATA14/MWI_2016_IHS-IV_v04_M_STATA14"
W3 = D + "/MWI_2019_IHS-V_v06_M_Stata"
W4 = D + "/MWI_2024-2025_IHS-VI_v01_M_STATA14"
CONV = W3 + "/ihs_foodconversion_factor_2020.dta"

FILES = {
    "w1": dict(g1=W1 + "/Household/hh_mod_g1.dta", a=W1 + "/Household/hh_mod_a_filt.dta",
               b=W1 + "/Household/hh_mod_b.dta", agg=W1 + "/ihs3fc2M_consumption.dta", year=2010),
    "w2": dict(g1=W2 + "/household/hh_mod_g1.dta", a=W2 + "/household/hh_mod_a_filt.dta",
               b=W2 + "/household/hh_mod_b.dta", agg=W2 + "/consumption_aggregate/ihs4 consumption aggregate.dta",
               year=2016),
    "w3": dict(g1=W3 + "/HH_MOD_G1.dta", a=W3 + "/hh_mod_a_filt.dta", b=W3 + "/HH_MOD_B.dta",
               agg=W3 + "/ihs5_consumption_aggregate.dta", year=2019),
    "w4": dict(g1=W4 + "/hh_mod_g1.dta", a=W4 + "/hh_mod_a_filt.dta", b=W4 + "/hh_mod_b.dta",
               agg=W4 + "/ihs6_consumptionaggregates.dta", year=2024),
}

ITEMS = [501, 504, 505, 506, 507, 508, 509, 701, 702, 902]


def read(path, cols=None):
    df, meta = pyreadstat.read_dta(path, apply_value_formats=False, usecols=cols)
    return df, meta


def num(s):
    """Numeric coercion that tolerates strings with blanks."""
    if s.dtype == object or str(s.dtype) in ("str", "string"):
        s = s.astype("string").str.strip().replace("", pd.NA)
    return pd.to_numeric(s, errors="coerce").astype("float64")


def txt(s):
    return s.astype("string").fillna("").str.strip()


def load_g1(wave):
    f = FILES[wave]["g1"]
    df, meta = read(f)
    os_sfx = "_os" if wave == "w1" else "_oth"
    out = pd.DataFrame({
        "case_id": txt(df["case_id"]),
        "item": num(df["hh_g02"]),
        "g01": num(df["hh_g01"]),
    })
    for q in ["03", "04", "06", "07"]:
        out[f"q{q}"] = num(df[f"hh_g{q}a"])
        out[f"u{q}"] = txt(df[f"hh_g{q}b"])
        if f"hh_g{q}b_label" in df:
            out[f"ul{q}"] = num(df[f"hh_g{q}b_label"])
        out[f"t{q}"] = txt(df[f"hh_g{q}b{os_sfx}"]).str.upper()
    out["spend"] = num(df["hh_g05"])
    return out, meta
