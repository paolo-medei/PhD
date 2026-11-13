import pyreadstat
import pandas as pd

pd.set_option("display.width", 250)
pd.set_option("display.max_columns", 60)
D = "/home/claude/v20home/Desktop/ASF_DATA/_unzipped/"
df, meta = pyreadstat.read_dta(D + "UGA_2013_UNPS_v02_M_STATA14/Stata/GSEC15B.dta")
d = df[df.duplicated(["hhid", "itmcd"], keep=False)]
print(d.drop(columns=["h15bq2c"]).to_string())
print(df[df.h15bq3a == 2][["itmcd", "untcd", "h15bq4", "h15bq5", "h15bq8", "h15bq10"]].describe())
print(df[df.h15bq3a == 2][df.itmcd.isin([117,118,119,121,124,125,148])].to_string())
df, meta = pyreadstat.read_dta(D + "UGA_2019_UNPS_v03_M_STATA14/UGA_2019_UNPS_v03_M_STATA14/HH/gsec15b.dta", metadataonly=True)
print(meta.value_labels[meta.variable_to_label["CEB03"]])
