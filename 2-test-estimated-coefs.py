#!/usr/bin/env python
# coding: utf-8

# In[165]:


import numpy as np
import pandas as pd
import openmatrix as omx
from pathlib import Path
from dbfread import DBF
import copy
from datetime import datetime
import os


# In[166]:


# import global TDM functions
import sys

sys.path.insert(0, "../Resources/2-Python/global-functions")
import BigQuery

client = BigQuery.getBigQueryClient_Confidential2023UtahHTS()


# ## Functions
# 

# In[167]:


def load_block_coefficients(file_path):
    # Initialize with a 'global' bucket for non-segmented variables
    coeffs = {"global": {}}

    with open(file_path, "r") as f:
        for line in f:
            # Strip out comments and whitespace
            line = line.split(";")[0].strip()
            if not line or "=" not in line:
                continue

            name, val = line.split("=")
            name = name.strip().lower()
            val = float(val.strip())

            # 1. Check if it is a segment-specific variable
            if name.endswith("_lo") or name.endswith("_hi"):
                parts = name.split("_")
                seg = f"{parts[-2]}_{parts[-1]}"  # e.g., 0veh_lo
                param = "_".join(parts[:-2])  # e.g., intra, logsum

                if seg not in coeffs:
                    coeffs[seg] = {}
                coeffs[seg][param] = val

            # 2. Otherwise, treat it as a global variable (like short_trip_factor)
            else:
                coeffs["global"][name] = val

    return coeffs


# In[168]:


# function used to apply range-based masking for external zones
def apply_range_mask(mask_array, range_str):
    for r in range_str.split(","):
        if "-" in r:
            start, end = map(int, r.split("-"))
            # This correctly maps TAZ 3563 to Index 3562
            mask_array[start - 1 : end] = True
        else:
            mask_array[int(r) - 1] = True


# In[169]:


# function to sum values in the household productions creation script
def sum_columns(hbw_productions, prefix_list, veh_suffixes):
    cols = []
    for prefix in prefix_list:
        for v in veh_suffixes:
            cols.append(f"P_{prefix}{v}")
    return hbw_productions[cols].sum(axis=1)


# In[170]:


# calculate size term for utility equation (size of destination in terms of nubmer of opportunities)
def get_size_term(seg_coeffs, df_se_input):
    # total employment
    total_emp = df_se_input["TOTEMP"].values.astype(float).copy()

    # precision-safe replacement logic
    epsilon = 1e-6
    for emp_type, coeff_key in [
        ("RETEMP", "retail_emp"),
        ("INDEMP", "industrial_emp"),
        ("OTHEMP", "other_emp"),
    ]:
        coeff = seg_coeffs.get(coeff_key, 1.0)

        if abs(coeff - 1.0) > epsilon:
            raw_emp = df_se_input[emp_type].values
            total_emp += raw_emp * (coeff - 1.0)

    # Ignore the divide by zero warning, let Python evaluate log(0) as -inf
    with np.errstate(divide="ignore", invalid="ignore"):
        ln_size = np.log(total_emp)

    return ln_size


# In[171]:


def export_run_for_dashboard(trips_data, df_se_full, run_name, file_name):
    """Rolls up the TAZ matrices to Large Districts and saves to a standalone CSV."""
    print(f"\n  -> Exporting '{run_name}' to CSV...")

    dist_lrg_array = df_se_full["DISTLRG"].values
    dist_records = []

    for seg, data in trips_data.items():
        # Melt the TAZ matrix
        df_taz = pd.DataFrame(data["trips"])
        df_taz["p_DistLrg"] = dist_lrg_array
        df_long = df_taz.melt(
            id_vars=["p_DistLrg"], var_name="a_taz", value_name="total_trips"
        )

        # Map a_taz index to a_DistLrg and group
        df_long["a_DistLrg"] = df_long["a_taz"].map(lambda x: dist_lrg_array[x])
        df_dist = df_long.groupby(["p_DistLrg", "a_DistLrg"], as_index=False)[
            "total_trips"
        ].sum()

        # Add identifiers
        df_dist["veh_inc"] = seg
        df_dist["Source"] = run_name
        dist_records.append(df_dist)

    df_final = pd.concat(dist_records, ignore_index=True)

    # Save to disk
    os.makedirs("intermediate/model_runs", exist_ok=True)
    out_path = f"intermediate/model_runs/{file_name}.csv"
    df_final.to_csv(out_path, index=False)
    print(f"  -> Saved successfully to {out_path}!")


# # File Paths & Inputs
# 

# In[172]:


path_inputs = Path.cwd() / "inputs"
path_outputs = Path.cwd() / "outputs"
path_start_files = path_inputs / "input_files/C28"

path_coeff_file = path_outputs / "coefficients_cal8_estimated3.block"
path_se_file = path_start_files / "SE_File.dbf"
path_pa_file = path_start_files / "pa_initial.dbf"
path_tel_file = path_start_files / "telecommute.dbf"
path_hh_files = [
    path_start_files / f"HH{i}_PercTrips_segment_hbw.dbf" for i in range(1, 7)
]
path_taz_file = path_start_files / "WFv1000_TAZ.dbf"

# Skims and Logsums (assuming they are already converted to OMX in this folder)
path_skm_hwy = path_start_files / "skm_auto_Pk.omx"
path_skm_walk = path_start_files / "Best_Walk_Skims.omx"
path_logsums = path_start_files / "HBW_logsums_Pk.omx"

# We load this once here just to get the segment names for loading matrices
initial_coeffs = load_block_coefficients(path_coeff_file)
segments = list(initial_coeffs.keys())
segments = list(initial_coeffs.keys())
if "global" in segments:
    segments.remove("global")


# In[173]:


used_zones = 3629
dummy_zones_str = "3563-3600"
external_zones_str = "3601-3629"


# In[174]:


# read dbf files
df_se = pd.DataFrame(iter(DBF(path_se_file)))
df_pa = pd.DataFrame(iter(DBF(path_pa_file)))
df_tel = pd.DataFrame(iter(DBF(path_tel_file)))
df_hh = [pd.DataFrame(iter(DBF(f))) for f in path_hh_files]
df_taz = pd.DataFrame(iter(DBF(path_taz_file)))

# Create dummy/external mask
mask_external_dummys = np.zeros(used_zones, dtype=bool)
apply_range_mask(mask_external_dummys, dummy_zones_str)
apply_range_mask(mask_external_dummys, external_zones_str)


# In[175]:


hts_hh_23 = client.query(
    "SELECT * FROM " + "wfrc-modeling-data.prd_tdm_hts_2023.hh"
).to_dataframe()
hts_person_23 = client.query(
    "SELECT * FROM " + "wfrc-modeling-data.prd_tdm_hts_2023.person"
).to_dataframe()
hts_trip_23 = client.query(
    "SELECT * FROM " + "wfrc-modeling-data.prd_tdm_hts_2023.trip_linked"
).to_dataframe()
hts_veh_23 = client.query(
    "SELECT * FROM " + "wfrc-modeling-data.prd_tdm_hts_2023.vehicle"
).to_dataframe()


# # Load Static Data
# 

# ## SE Data, Employment Ratios, District Math
# 

# In[176]:


if "N" in df_se.columns:
    df_se_indexed = df_se.set_index(df_se["N"] - 1)
else:
    df_se_indexed = df_se.copy()

df_se_full = df_se_indexed.reindex(np.arange(used_zones)).fillna(0)
if "N" in df_se_full.columns:
    df_se_full["N"] = np.arange(1, used_zones + 1)

# Employment Ratios
denom = (df_se_full["RETEMP"] + df_se_full["INDEMP"] + df_se_full["OTHEMP"]).values
retail_ratio = np.divide(
    df_se_full["RETEMP"].values,
    denom,
    out=np.zeros_like(denom, dtype=float),
    where=denom != 0,
)
ind_ratio = np.divide(
    df_se_full["INDEMP"].values,
    denom,
    out=np.zeros_like(denom, dtype=float),
    where=denom != 0,
)
other_ratio = np.divide(
    df_se_full["OTHEMP"].values,
    denom,
    out=np.zeros_like(denom, dtype=float),
    where=denom != 0,
)

# District Match boolean matrix
dist_lrg = df_se_full["DISTLRG"].values
district_match = dist_lrg[:, np.newaxis] == dist_lrg[np.newaxis, :]


# In[177]:


dist2_factor = initial_coeffs["global"]["beta_dist2"]
dist3_factor = initial_coeffs["global"]["beta_dist3"]
emp_factor = initial_coeffs["global"]["beta_emp"]


# ## Attractions and Productions
# 

# In[178]:


# Prepare Target Attractions
target_attractions = np.zeros(used_zones)
df_pa["Zone_Index"] = df_pa["Z"].astype(int) - 1
valid_pa = df_pa[df_pa["Zone_Index"] < used_zones]
target_attractions[valid_pa["Zone_Index"].values] = valid_pa["HBW_A"].values

# Prepare Trip Productions by Segment
zone_col = "Z"
hh_all = df_hh[0].copy()
for df in df_hh[1:]:
    hh_all = hh_all.merge(df, on=zone_col, suffixes=("", "_dup"))
    for col in df.columns:
        if col != zone_col and col + "_dup" in hh_all.columns:
            hh_all[col] += hh_all[col + "_dup"]
            hh_all.drop(columns=[col + "_dup"], inplace=True)
hbw_prods = hh_all.merge(df_pa[[zone_col, "HBW_P"]], on=zone_col)

# Calculate trips by segment
low_inc, high_inc = ["ILW0", "ILW1", "ILW2", "ILW3"], ["IHW0", "IHW1", "IHW2", "IHW3"]
hbw_prods["trips_0veh_lo"] = (
    sum_columns(hbw_prods, low_inc, ["V0"]) * hbw_prods["HBW_P"]
)
hbw_prods["trips_1veh_lo"] = (
    sum_columns(hbw_prods, low_inc, ["V1"]) * hbw_prods["HBW_P"]
)
hbw_prods["trips_2veh_lo"] = (
    sum_columns(hbw_prods, low_inc, ["V2", "V3"]) * hbw_prods["HBW_P"]
)
hbw_prods["trips_0veh_hi"] = (
    sum_columns(hbw_prods, high_inc, ["V0"]) * hbw_prods["HBW_P"]
)
hbw_prods["trips_1veh_hi"] = (
    sum_columns(hbw_prods, high_inc, ["V1"]) * hbw_prods["HBW_P"]
)
hbw_prods["trips_2veh_hi"] = (
    sum_columns(hbw_prods, high_inc, ["V2", "V3"]) * hbw_prods["HBW_P"]
)

# Zero out external/dummy zones
cols_to_zero = [
    "trips_0veh_lo",
    "trips_1veh_lo",
    "trips_2veh_lo",
    "trips_0veh_hi",
    "trips_1veh_hi",
    "trips_2veh_hi",
]


# In[179]:


# Telecommute Factors
pct_tel_hbw = df_tel["PCTTELHBW"].values.reshape(1, -1)
fac_tel_hbw = df_tel["FACTELHBW"].values.reshape(1, -1)


# ## Matrix Data
# 

# In[180]:


with (
    omx.open_file(path_skm_hwy, "r") as skm_hwy,
    omx.open_file(path_skm_walk, "r") as skm_walk,
):
    dist_mtx = np.array(skm_hwy["dist_GP"][:])
    hwy_time = np.array(skm_hwy["ivt_GP"][:]) + np.array(skm_hwy["ovt"][:])
    walk_gencost = np.array(skm_walk["GENCOST"][:])

log_file = {}
with omx.open_file(path_logsums, "r") as f:
    for seg in segments:
        log_file[seg] = np.array(f[seg][:])

# The heavy lifting: pre-calculate distance variables once!
dist_sq = dist_mtx * dist_mtx
dist_cu = dist_sq * dist_mtx
short_trip_factor = initial_coeffs["global"]["short_trip_factor"] / np.clip(
    dist_mtx, 1.0, None
)


# ## Observed Trips by VehOwn & Income
# 

# In[181]:


hts_trip_23_merge = hts_trip_23.copy()
hts_trip_23_merge = hts_trip_23_merge[
    [
        "unique_id",
        "hh_id",
        "person_id",
        "vehicle_id",
        "pCO_TAZID_USTMv4",
        "aCO_TAZID_USTMv4",
        "pSUBAREAID",
        "aSUBAREAID",
        "PURP7_t",
        "trip_weight",
        "distance_miles",
    ]
]

# filter to HBW
hts_trip_23_merge = hts_trip_23_merge[hts_trip_23_merge["PURP7_t"] == "HBW"]

# merge taz
hts_trip_23_merge = hts_trip_23_merge.merge(
    df_taz[["TAZID", "CO_TAZID"]],
    how="left",
    left_on="pCO_TAZID_USTMv4",
    right_on="CO_TAZID",
)
hts_trip_23_merge = hts_trip_23_merge.drop(columns="CO_TAZID").rename(
    columns={"TAZID": "pTAZID"}
)
hts_trip_23_merge = hts_trip_23_merge.merge(
    df_taz[["TAZID", "CO_TAZID"]],
    how="left",
    left_on="aCO_TAZID_USTMv4",
    right_on="CO_TAZID",
)
hts_trip_23_merge = hts_trip_23_merge.drop(columns="CO_TAZID").rename(
    columns={"TAZID": "aTAZID"}
)

# fitler to WF subarea
hts_trip_23_merge = hts_trip_23_merge[hts_trip_23_merge["pSUBAREAID"] == 1]
hts_trip_23_merge = hts_trip_23_merge[hts_trip_23_merge["aSUBAREAID"] == 1]

# vehicle ownership lookup table
vehown_lookup = (
    hts_veh_23.copy()
    .groupby("hh_id")["vehicle_id"]
    .count()
    .reset_index(name="veh_count")
)
vehown_lookup["vehown"] = vehown_lookup["veh_count"].clip(upper=2)
vehown_lookup = vehown_lookup[["hh_id", "vehown"]]

# income lookup table
income_lookup = hts_hh_23.copy()[["hh_id", "income_detailed"]]
income_lookup["income"] = np.select(
    [
        income_lookup["income_detailed"].isin([1, 2, 3, 4]),
        income_lookup["income_detailed"].isin([5, 6, 7, 8, 9, 10]),
    ],
    ["lo", "hi"],
    default="",
)

income_lookup = income_lookup[["hh_id", "income"]]

# merge vehown and income to trip table
hts_trip_23_merge = hts_trip_23_merge.merge(vehown_lookup, how="left", on="hh_id")
hts_trip_23_merge["vehown"] = hts_trip_23_merge["vehown"].fillna(0).astype(int)
hts_trip_23_merge = hts_trip_23_merge.merge(income_lookup, how="left", on="hh_id")

# calculate segment
hts_trip_23_merge["segment"] = np.where(
    hts_trip_23_merge["income"].notna() & (hts_trip_23_merge["income"] != ""),
    hts_trip_23_merge["vehown"].astype(str)
    + "veh_"
    + hts_trip_23_merge["income"].astype(str),
    "",
)

# filter to only known income trips
hts_trip_23_merge = hts_trip_23_merge[~(hts_trip_23_merge["segment"] == "")]


# In[182]:


# start final table
df_obs_vehown_inc = hts_trip_23_merge.copy()
df_obs_vehown_inc = df_obs_vehown_inc[["pTAZID", "aTAZID", "segment", "trip_weight"]]
df_obs_vehown_inc = df_obs_vehown_inc.rename(columns={"pTAZID": "i", "aTAZID": "j"})

# Define the 6 segments
segments = ["0veh_lo", "0veh_hi", "1veh_lo", "1veh_hi", "2veh_lo", "2veh_hi"]

# Pivot table
df_obs_pivot = df_obs_vehown_inc.pivot_table(
    index=["i", "j"],
    columns="segment",
    values="trip_weight",
    aggfunc="sum",
    fill_value=0,
)

# Make sure all 6 segment columns exist
for seg in segments:
    if seg not in df_obs_pivot.columns:
        df_obs_pivot[seg] = 0

# Reorder columns
df_obs_pivot = df_obs_pivot[segments]

# Add TOTAL column
df_obs_pivot["TOTAL"] = df_obs_pivot.sum(axis=1)

# Reset index if you want a flat dataframe
df_obs_pivot = df_obs_pivot.reset_index()


# ## Package Data
# 

# In[183]:


static_data = {
    "segments": segments,
    "dist_mtx": dist_mtx,
    "dist_sq": dist_sq,
    "dist_cu": dist_cu,
    "dist2_factor": dist2_factor,
    "dist3_factor": dist3_factor,
    "emp_factor": emp_factor,
    "short_trip_factor": short_trip_factor,
    "hwy_time": hwy_time,
    "walk_gencost": walk_gencost,
    "retail_ratio": retail_ratio,
    "ind_ratio": ind_ratio,
    "other_ratio": other_ratio,
    "log_file": log_file,
    "hbw_prods": hbw_prods,
    "target_attractions": target_attractions,
    "mask_external_dummys": mask_external_dummys,
    "district_match": district_match,
    "df_se_full": df_se_full,
    "pct_tel_hbw": pct_tel_hbw,
    "fac_tel_hbw": fac_tel_hbw,
    "UsedZones": used_zones,
    "df_obs_trips": df_obs_pivot,
}


# # Calibration
# 

# ## Observed Targets
# 

# In[184]:


# read in observed
df_obs = static_data["df_obs_trips"]

# Convert 1-based TAZ numbers to 0-based Python indices
i_idx = df_obs["i"].astype(int).values - 1
j_idx = df_obs["j"].astype(int).values - 1

# Fetch the distance for every i-j pair directly from our loaded dist_mtx
df_obs["skim_dist"] = dist_mtx[i_idx, j_idx]

observed_avg_dist = {}

# Calculate the observed average distance for each segment
for seg in segments:  # e.g., '0veh_lo', '0veh_hi', etc.
    # Make sure the column name exactly matches the segment string in your loop
    total_obs_trips = df_obs[seg].sum()

    if total_obs_trips > 0:
        # Sum of (trips * distance) / total trips
        avg_dist = (df_obs[seg] * df_obs["skim_dist"]).sum() / total_obs_trips
        observed_avg_dist[seg] = avg_dist
    else:
        observed_avg_dist[seg] = 0.0
    print(f"  Target for {seg}: {observed_avg_dist[seg]:.2f} miles")


# ## Master Calibration Loop (Optional Distance Calibration)
# 

# In[187]:


# --- CALIBRATION SETTINGS ---
calibrated_distance = (
    1  # 1 = Full Distance Calibration, 0 = Single Pass (Balancing Only)
)

print("\nInitializing Calibration...")

# Create a true, independent copy of the nested dictionary so we don't overwrite the original
current_coeffs = copy.deepcopy(initial_coeffs)

# calibration settings
max_calib_iterations = 20
learning_rate = 0.01  # How aggressively to adjust coefficients

for calib_iter in range(1, max_calib_iterations + 1):
    if calibrated_distance == 1:
        print(f"\n--- Starting Distance Calibration Iteration {calib_iter} ---")
    else:
        print("\n--- Running Destination Choice (Balancing Only) ---")

    # ------------------------------------------------------------------------
    # Recalculate Dynamic Variables (Size Terms depend on coefficients)
    # ------------------------------------------------------------------------
    size_terms = {
        seg: get_size_term(current_coeffs[seg], df_se_full) for seg in segments
    }
    adj_factors = np.zeros(used_zones)
    trips_data = {seg: {} for seg in segments}

    # ------------------------------------------------------------------------
    # Inner Iterative Balancing Loop
    # ------------------------------------------------------------------------
    for iterate in range(1, 11):
        total_trips_od = np.zeros((used_zones, used_zones))

        for seg in segments:
            c, st_vector = current_coeffs[seg], size_terms[seg]

            # -----------------------#
            # 1. Production alignment
            p_seg = hbw_prods[f"trips_{seg}"].values.copy()
            p_seg[mask_external_dummys[: len(p_seg)]] = 0

            # -----------------------#
            # 2. Utility calculation
            utility = (
                (c["logsum"] * log_file[seg][:])
                + short_trip_factor
                + ((c["hwy_dist"] - c["distcal"]) * dist_mtx)
                + (dist2_factor * dist_sq)
                + (dist3_factor * dist_cu)
                + (c["hwy_time"] * hwy_time)
                + (c["transit_cost"] * walk_gencost)
                + (emp_factor * st_vector[None, :])
                + adj_factors[None, :]
                + (c["retail_ratio"] * retail_ratio)[None, :]
                + (c["industrial_ratio"] * ind_ratio)[None, :]
                + (c["other_ratio"] * other_ratio)[None, :]
            )

            np.fill_diagonal(utility, utility.diagonal() + c["intra"])
            utility += np.where(district_match, c["intradist"], 0)

            # -----------------------#
            # 3. Exponentiate
            exp_u = np.exp(utility)
            exp_u[p_seg <= 0, :] = 0
            exp_u[:, df_se_full["TOTEMP"].values <= 0] = 0
            exp_u[:, mask_external_dummys] = 0

            # -----------------------#
            # 4. Probabilities
            row_sums = exp_u.sum(axis=1)[:, np.newaxis]
            share_mtx = np.divide(
                exp_u, row_sums, out=np.zeros_like(exp_u), where=row_sums != 0
            )

            # -----------------------#
            # 5. Calculate Trips
            trips_mtx = share_mtx * p_seg[:, np.newaxis]
            trips_data[seg]["trips"] = trips_mtx
            total_trips_od += trips_mtx

        # -----------------------#
        # 6. Attraction balancing
        current_attractions = total_trips_od.sum(axis=0)
        adj_mask = (target_attractions > 0) & (~mask_external_dummys)
        new_step = np.zeros_like(adj_factors)
        safe_mask = adj_mask & (current_attractions > 0)
        new_step[safe_mask] = np.log(
            target_attractions[safe_mask] / current_attractions[safe_mask]
        )
        adj_factors += new_step

        # -----------------------#
        # 7. Convergence Check
        abs_diff = np.abs(current_attractions - target_attractions)
        pct_diff = np.zeros_like(abs_diff)
        np.divide(
            abs_diff, target_attractions, out=pct_diff, where=target_attractions > 0
        )
        percent_converged = np.sum(
            ((pct_diff < 0.02) | (abs_diff <= 10)) & (target_attractions > 0)
        ) / np.sum(target_attractions > 0)

        if percent_converged > 0.99:
            break

    # ------------------------------------------------------------------------
    # Export for Dashboard (Saves Iteration 1 or the Single Pass)
    # ------------------------------------------------------------------------
    if calib_iter == 1:
        print("Exporting results for dashboard...")
        export_run_for_dashboard(
            trips_data=trips_data,
            df_se_full=df_se_full,
            run_name="Test 7: Estimation 3 (C28)",
            file_name="test_7_estimation3",
        )

    # ------------------------------------------------------------------------
    # Distance Calibration Logic
    # ------------------------------------------------------------------------
    if calibrated_distance == 1:
        total_error = 0
        for seg in segments:
            simulated_trips = trips_data[seg]["trips"]
            total_seg_trips = simulated_trips.sum()

            simulated_avg_dist = (
                np.sum(simulated_trips * dist_mtx) / total_seg_trips
                if total_seg_trips > 0
                else 0
            )
            target_dist = observed_avg_dist[seg]
            error = simulated_avg_dist - target_dist
            total_error += abs(error)

            print(
                f"  {seg}: Sim Avg Dist = {simulated_avg_dist:.2f} | Target = {target_dist:.2f} | Error = {error:.2f}"
            )

            # Adjust the 'distcal' coefficient
            current_coeffs[seg]["distcal"] += error * learning_rate

        print(f"Total Absolute Error for Iteration {calib_iter}: {total_error:.2f}")

        if total_error < 0.05:
            print("\nCalibration targets reached! Breaking out of loop.")
            break
    else:
        print("Destination choice balancing complete. (Single Pass)")
        break

# ========================================================================
# FINAL EXPORT (ONLY IF CALIBRATION ACTUALLY RAN)
# ========================================================================
if calibrated_distance == 1 and calib_iter > 1:
    print("\nWriting FINAL calibrated coefficients and trips to file...")

    # 1. Export Coefficients (.block)
    out_coeff_path = path_outputs / "coefficients_cal8_distance3.block"
    with open(out_coeff_path, "w") as f:
        f.write("; Calibrated HBW Destination Choice Coefficients\n")
        f.write(f"; Generated on {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        for seg in segments:
            f.write(f"; --- {seg} ---\n")
            for param, val in current_coeffs[seg].items():
                f.write(f"{param}_{seg} = {val:.6f}\n")
            f.write("\n")

    # 2. Export Final Trips (Dashboard)
    export_run_for_dashboard(
        trips_data=trips_data,
        df_se_full=df_se_full,
        run_name="Test 8: Distance 3 (C28)",
        file_name="test_8_distance3",
    )
    print(f"Final results saved! Coeffs at: {out_coeff_path}")


# # Compare Results
# 

# In[189]:


import pandas as pd
import numpy as np
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import ipywidgets as widgets
from IPython.display import display
import os

# =========================================================
# 1. LOAD OBSERVED DATA
# =========================================================
obs_df = pd.read_csv("intermediate/obs_dist_hbw_sum.csv")
obs_df["veh_inc_clean"] = obs_df["veh_inc"].str.replace("HBW_", "")

# Force integers for safe merging
obs_df["p_DistLrg"] = obs_df["p_DistLrg"].astype(int)
obs_df["a_DistLrg"] = obs_df["a_DistLrg"].astype(int)

# =========================================================
# 2. LOAD YOUR MODEL RUNS
# =========================================================
run_files = [
    "intermediate/model_runs/test_0_baseline.csv",  # baseline c28 results with old coefs/constants
    "intermediate/model_runs/test_1_distance.csv",  # baseline c28 plus calibrated distance coefs
    "intermediate/model_runs/test_2_dist_bins.csv",  # baseline c28 plus calibrated distance coefs by bin
    "intermediate/model_runs/test_3_estimation1.csv",  # round 1 of estimated coefficients -- provided by andy
    "intermediate/model_runs/test_4_distance1.csv",  # round 1 of estimated coefficients plus calibrated distance coefs
    "intermediate/model_runs/test_4_distance1a.csv",  # round 1 of estimated coefficients plus calibrated distance and calibrated intrazonal coefs
    "intermediate/model_runs/test_5_estimation2.csv",  # round 2 of estimated coefficients (includes new param short_trip_factor)
    "intermediate/model_runs/test_6_distance2.csv",  # round 2 of estimated coefficients plus calibrated distance coeffs
    "intermediate/model_runs/test_7_estimation3.csv",  # round 3 of estimated coefficients (using trip weight this time)
    "intermediate/model_runs/test_8_distance3.csv",  # round 3 of estimated coefficients plus calibrated distance coeffs
]

mod_dfs = []
for file in run_files:
    if os.path.exists(file):
        mod_dfs.append(pd.read_csv(file))
    else:
        print(f"Notice: {file} not found yet. Skipping.")

if len(mod_dfs) > 0:
    mod_df = pd.concat(mod_dfs, ignore_index=True)
    mod_df["veh_inc_clean"] = mod_df["veh_inc"].str.replace("HBW_", "")
    # Force integers for safe merging
    mod_df["p_DistLrg"] = mod_df["p_DistLrg"].astype(int)
    mod_df["a_DistLrg"] = mod_df["a_DistLrg"].astype(int)
else:
    print("No model runs found! Go run your calibration loop first.")
    mod_df = pd.DataFrame(
        columns=["Source", "veh_inc_clean", "p_DistLrg", "a_DistLrg", "total_trips"]
    )


# =========================================================
# 3. BUILD THE INTERACTIVE PLOTLY DASHBOARD (FACET GRID)
# =========================================================
# =========================================================
# 3. BUILD THE INTERACTIVE PLOTLY DASHBOARD (FACET GRID)
# =========================================================
def show_dashboard(mod_data, obs_data):
    if mod_data.empty:
        return

    sources = mod_data["Source"].unique().tolist()
    veh_incs = sorted(obs_data["veh_inc_clean"].unique().tolist())

    source_dropdown = widgets.Dropdown(
        options=sources, value=sources[0], description="Model Run:"
    )

    # Create a 2x3 grid for the 6 segments
    fig = make_subplots(
        rows=2,
        cols=3,
        subplot_titles=[f"Segment: {seg}" for seg in veh_incs],
        horizontal_spacing=0.08,
        vertical_spacing=0.15,
    )

    # Initialize traces for all 6 subplots
    for i, seg in enumerate(veh_incs):
        row = (i // 3) + 1
        col = (i % 3) + 1

        # TRACE: Scatter
        fig.add_trace(
            go.Scatter(
                x=[], y=[], mode="markers", marker=dict(color="royalblue", opacity=0.6)
            ),
            row=row,
            col=col,
        )
        # TRACE: Dashed Regression Line
        fig.add_trace(
            go.Scatter(
                x=[],
                y=[],
                mode="lines",
                line=dict(color="royalblue", dash="dash", width=2),
            ),
            row=row,
            col=col,
        )

        fig.update_xaxes(title_text="Observed Trips", row=row, col=col)
        fig.update_yaxes(title_text="Modeled Trips", row=row, col=col)

    # Set initial layout
    fig.update_layout(
        height=800,
        width=1200,
        showlegend=False,
        template="plotly_white",
        title_text="Model vs Observed Trips | Cumulative Error: Calculating...",
    )

    # Wrap the figure in a FigureWidget
    g = go.FigureWidget(fig)

    def update_plot(change):
        source = source_dropdown.value

        # ---------------------------------------------------------
        # CALCULATE CUMULATIVE SCORE (WMAPE)
        # ---------------------------------------------------------
        f_mod_all = mod_data[mod_data["Source"] == source]
        merged_all = pd.merge(
            obs_data,
            f_mod_all,
            on=["veh_inc_clean", "p_DistLrg", "a_DistLrg"],
            suffixes=("_obs", "_mod"),
        )
        merged_all = merged_all[merged_all["total_trips_obs"] > 0]

        if not merged_all.empty:
            total_abs_error = np.abs(
                merged_all["total_trips_mod"] - merged_all["total_trips_obs"]
            ).sum()
            total_obs = merged_all["total_trips_obs"].sum()
            overall_error_pct = (
                (total_abs_error / total_obs) * 100 if total_obs > 0 else 0
            )
            new_title = f"Model Run: {source} | Cumulative Error (WMAPE): {overall_error_pct:.1f}%"
        else:
            new_title = f"Model Run: {source} | Cumulative Error: N/A"

        # ---------------------------------------------------------
        # UPDATE SUBPLOTS
        # ---------------------------------------------------------
        new_shapes = []

        with g.batch_update():
            # Update the main title with our new score
            g.layout.title.text = new_title

            for i, seg in enumerate(veh_incs):
                f_mod = f_mod_all[f_mod_all["veh_inc_clean"] == seg]
                f_obs = obs_data[obs_data["veh_inc_clean"] == seg]

                merged = pd.merge(
                    f_obs,
                    f_mod,
                    on=["p_DistLrg", "a_DistLrg"],
                    suffixes=("_obs", "_mod"),
                )
                merged = merged[merged["total_trips_obs"] > 0]

                trace_scatter_idx = i * 2
                trace_trend_idx = i * 2 + 1

                if merged.empty:
                    # Clear this specific subplot if no data
                    g.data[trace_scatter_idx].x, g.data[trace_scatter_idx].y = [], []
                    g.data[trace_trend_idx].x, g.data[trace_trend_idx].y = [], []
                    continue

                x_vals = merged["total_trips_obs"]
                y_vals = merged["total_trips_mod"]

                hover_text = merged.apply(
                    lambda row: (
                        f"Dist: {row['p_DistLrg']} to {row['a_DistLrg']}<br>"
                        f"Obs: {row['total_trips_obs']:.0f}<br>"
                        f"Mod: {row['total_trips_mod']:.0f}"
                    ),
                    axis=1,
                )

                max_val = max(x_vals.max(), y_vals.max())

                # Update Scatter
                g.data[trace_scatter_idx].x = x_vals.tolist()
                g.data[trace_scatter_idx].y = y_vals.tolist()
                g.data[trace_scatter_idx].hovertext = hover_text.tolist()

                # Calculate Regression Line
                if len(merged) > 1:
                    slope = np.sum(x_vals * y_vals) / np.sum(x_vals**2)
                    trend_x = [0, max_val]
                    trend_y = [0, slope * max_val]
                else:
                    trend_x, trend_y = [], []

                # Update Trendline
                g.data[trace_trend_idx].x = trend_x
                g.data[trace_trend_idx].y = trend_y

                # Adjust axis ranges dynamically for this subplot
                axis_num = i + 1
                xaxis_name = f"xaxis{axis_num}" if axis_num > 1 else "xaxis"
                yaxis_name = f"yaxis{axis_num}" if axis_num > 1 else "yaxis"

                g.layout[xaxis_name].range = [0, max_val * 1.05]
                g.layout[yaxis_name].range = [0, max_val * 1.05]

                # Draw Fan lines for this subplot
                xref = f"x{axis_num}" if axis_num > 1 else "x"
                yref = f"y{axis_num}" if axis_num > 1 else "y"

                for r in [0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3]:
                    new_shapes.append(
                        dict(
                            type="line",
                            x0=0,
                            y0=0,
                            x1=max_val,
                            y1=max_val * r,
                            line=dict(
                                color="gray",
                                width=2 if r == 1.0 else 1,
                                dash="dot" if r != 1.0 else "solid",
                            ),
                            xref=xref,
                            yref=yref,
                            layer="below",
                        )
                    )

            g.layout.shapes = new_shapes

    # Observe the dropdown change
    source_dropdown.observe(update_plot, names="value")

    # Run once to initialize
    update_plot(None)

    # Display the UI
    display(source_dropdown)
    display(g)


show_dashboard(mod_df, obs_df)


# In[61]:


import matplotlib.pyplot as plt
import pandas as pd

# Define the extracted data from the calibrated .block file
data = {
    "Bin": ["0-5", "5-10", "10-20", "20+"],
    "0veh_lo": [0.654829, 0.221132, -1.570629, -5.413851],
    "0veh_hi": [0.862158, 0.222730, -1.081346, -5.736178],
    "1veh_lo": [1.399584, 0.333365, -0.249304, -2.480418],
    "1veh_hi": [1.538234, 0.917138, -0.035432, -3.210064],
    "2veh_lo": [1.032024, 0.249493, -0.918710, -2.642988],
    "2veh_hi": [1.259522, 0.741158, 0.169612, -2.134993],
}

df = pd.DataFrame(data)

# Create the plot
plt.figure(figsize=(10, 6))
for col in df.columns[1:]:
    plt.plot(df["Bin"], df[col], marker="o", linewidth=2, label=col)

plt.title("Calibrated Distance Bin Constants by Segment", fontsize=14)
plt.xlabel("Distance Bin (miles)", fontsize=12)
plt.ylabel("Bin Constant Value (Utility Adjustment)", fontsize=12)

# Add a zero-line for reference
plt.axhline(0, color="black", linewidth=1, linestyle="--")

# Formatting
plt.legend(title="Veh/Inc Segment", bbox_to_anchor=(1.05, 1), loc="upper left")
plt.grid(True, alpha=0.3)
plt.tight_layout()

# Save or show
# plt.savefig('distance_bin_constants.png')
plt.show()


# In[ ]:


## =========================================================
## 3. BUILD THE INTERACTIVE PLOTLY DASHBOARD
## =========================================================
# def show_dashboard(mod_data, obs_data):
#    if mod_data.empty:
#        return
#
#    sources = mod_data["Source"].unique().tolist()
#    veh_incs = sorted(obs_data["veh_inc_clean"].unique().tolist())
#
#    source_dropdown = widgets.Dropdown(
#        options=sources, value=sources[0], description="Model Run:"
#    )
#    veh_inc_dropdown = widgets.Dropdown(
#        options=veh_incs, value=veh_incs[0], description="Segment:"
#    )
#
#    fig = make_subplots(
#        rows=1,
#        cols=2,
#        subplot_titles=(
#            "2a. Model vs Observed Trips",
#            "2b. Model vs Observed Percent Error",
#        ),
#    )
#
#    # TRACE 0: Scatter for Chart 1
#    fig.add_trace(
#        go.Scatter(
#            x=[], y=[], mode="markers", marker=dict(color="royalblue", opacity=0.6)
#        ),
#        row=1,
#        col=1,
#    )
#    # TRACE 1: Scatter for Chart 2 (Error)
#    fig.add_trace(
#        go.Scatter(
#            x=[], y=[], mode="markers", marker=dict(color="royalblue", opacity=0.6)
#        ),
#        row=1,
#        col=2,
#    )
#    # TRACE 2: Dashed Regression Line for Chart 1
#    fig.add_trace(
#        go.Scatter(
#            x=[], y=[], mode="lines", line=dict(color="royalblue", dash="dash", width=2)
#        ),
#        row=1,
#        col=1,
#    )
#    # TRACE 3: Upper Validation Staircase for Chart 2
#    fig.add_trace(
#        go.Scatter(
#            x=[],
#            y=[],
#            mode="lines",
#            hoverinfo="skip",
#            line=dict(color="gray", dash="dash", width=1.5),
#        ),
#        row=1,
#        col=2,
#    )
#    # TRACE 4: Lower Validation Staircase for Chart 2
#    fig.add_trace(
#        go.Scatter(
#            x=[],
#            y=[],
#            mode="lines",
#            hoverinfo="skip",
#            line=dict(color="gray", dash="dash", width=1.5),
#        ),
#        row=1,
#        col=2,
#    )
#
#    fig.update_layout(height=500, width=1000, showlegend=False, template="plotly_white")
#    fig.update_xaxes(title_text="Observed Trips", row=1, col=1)
#    fig.update_yaxes(title_text="Modeled Trips", row=1, col=1)
#    fig.update_xaxes(title_text="Observed Trips", row=1, col=2)
#    fig.update_yaxes(
#        title_text="Percent Error", tickformat=".0%", range=[-2, 2], row=1, col=2
#    )
#
#    # Wrap the figure in a FigureWidget so it responds to dropdowns!
#    g = go.FigureWidget(fig)
#
#    def update_plot(change):
#        source = source_dropdown.value
#        veh_inc = veh_inc_dropdown.value
#
#        f_mod = mod_data[
#            (mod_data["Source"] == source) & (mod_data["veh_inc_clean"] == veh_inc)
#        ]
#        f_obs = obs_data[obs_data["veh_inc_clean"] == veh_inc]
#
#        merged = pd.merge(
#            f_obs, f_mod, on=["p_DistLrg", "a_DistLrg"], suffixes=("_obs", "_mod")
#        )
#        merged = merged[merged["total_trips_obs"] > 0]
#
#        if merged.empty:
#            # Clear the plot if no data matches
#            with g.batch_update():
#                g.data[0].x, g.data[0].y = [], []
#                g.data[1].x, g.data[1].y = [], []
#                g.data[2].x, g.data[2].y = [], []
#                g.layout.shapes = []
#            return
#
#        merged["error_pct"] = (
#            merged["total_trips_mod"] - merged["total_trips_obs"]
#        ) / merged["total_trips_obs"]
#
#        hover_text = merged.apply(
#            lambda row: (
#                f"Dist: {row['p_DistLrg']} to {row['a_DistLrg']}<br>Obs: {row['total_trips_obs']:.0f}<br>Mod: {row['total_trips_mod']:.0f}"
#            ),
#            axis=1,
#        )
#
#        max_val = max(merged["total_trips_obs"].max(), merged["total_trips_mod"].max())
#
#        # Calculate the linear regression trendline
#        if len(merged) > 1:
#            x = merged["total_trips_obs"]
#            y = merged["total_trips_mod"]
#
#            # Formula for slope with no intercept: sum(x*y) / sum(x^2)
#            slope = np.sum(x * y) / np.sum(x**2)
#            intercept = 0
#
#            trend_x = [0, max_val]
#            trend_y = [0, slope * max_val]
#        else:
#            trend_x, trend_y = [], []
#
#        with g.batch_update():
#            # Update Scatter 1
#            g.data[0].x, g.data[0].y, g.data[0].hovertext = (
#                merged["total_trips_obs"].tolist(),
#                merged["total_trips_mod"].tolist(),
#                hover_text.tolist(),
#            )
#            # Update Scatter 2
#            g.data[1].x, g.data[1].y, g.data[1].hovertext = (
#                merged["total_trips_obs"].tolist(),
#                merged["error_pct"].tolist(),
#                hover_text.tolist(),
#            )
#            # Update Regression Line
#            g.data[2].x, g.data[2].y = trend_x, trend_y
#
#            # Calculate and Update the Validation Staircase targets
#            stair_x = [0, 500, 500, 1000, 1000, max(max_val, 1500)]
#            g.data[3].x, g.data[3].y = stair_x, [1.0, 1.0, 0.5, 0.5, 0.25, 0.25]
#            g.data[4].x, g.data[4].y = stair_x, [-1.0, -1.0, -0.5, -0.5, -0.25, -0.25]
#
#            # Update axes ranges
#            for col in [1, 2]:
#                g.update_xaxes(range=[0, max_val * 1.05], row=1, col=col)
#            g.update_yaxes(range=[0, max_val * 1.05], row=1, col=1)
#
#            # Redraw background shapes (Fan lines on left, Zero-line on right)
#            new_shapes = []
#            for r in [0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3]:
#                new_shapes.append(
#                    dict(
#                        type="line",
#                        x0=0,
#                        y0=0,
#                        x1=max_val,
#                        y1=max_val * r,
#                        line=dict(
#                            color="gray",
#                            width=2 if r == 1.0 else 1,
#                            dash="dot" if r != 1.0 else "solid",
#                        ),
#                        xref="x1",
#                        yref="y1",
#                        layer="below",
#                    )
#                )
#            new_shapes.append(
#                dict(
#                    type="line",
#                    x0=0,
#                    x1=max_val * 1.05,
#                    y0=0,
#                    y1=0,
#                    line=dict(color="black", width=1, dash="solid"),
#                    xref="x2",
#                    yref="y2",
#                    layer="below",
#                )
#            )
#            g.layout.shapes = new_shapes
#
#    # Observe the dropdown changes
#    source_dropdown.observe(update_plot, names="value")
#    veh_inc_dropdown.observe(update_plot, names="value")
#
#    # Run once to initialize
#    update_plot(None)
#
#    # Display the UI
#    display(widgets.HBox([source_dropdown, veh_inc_dropdown]))
#    display(g)
#
#
# show_dashboard(mod_df, obs_df)


# # Troubleshooting
# 

# In[ ]:


import numpy as np
import pandas as pd


def calculate_advanced_metrics(run_name, mod_trips_dict, obs_trips_dict, dist_mtx):
    """
    Calculates TAZ-level and distance-level metrics for a model run.
    Expects dictionaries where keys are segments (e.g., '0veh_lo') and
    values are 2D numpy arrays (TAZ x TAZ matrices).
    """
    results = []

    # Set up distance bins for the Coincidence Ratio (e.g., 0 to 60 miles in 1-mile increments)
    # Adjust the max distance (61) based on your region's maximum possible trip length!
    bins = np.arange(0, 61, 1)

    for seg in mod_trips_dict.keys():
        mod_mtx = mod_trips_dict[seg]
        obs_mtx = obs_trips_dict[seg]

        # Guard against empty matrices
        mod_total = mod_mtx.sum()
        obs_total = obs_mtx.sum()
        if obs_total == 0:
            continue

        # -------------------------------------------------------------
        # 1. Average Trip Length (ATL)
        # -------------------------------------------------------------
        mod_atl = np.sum(mod_mtx * dist_mtx) / mod_total if mod_total > 0 else 0
        obs_atl = np.sum(obs_mtx * dist_mtx) / obs_total

        # -------------------------------------------------------------
        # 2. Intrazonal Percentage (Diagonal of the matrix)
        # -------------------------------------------------------------
        mod_iz_pct = (np.trace(mod_mtx) / mod_total) * 100 if mod_total > 0 else 0
        obs_iz_pct = (np.trace(obs_mtx) / obs_total) * 100

        # -------------------------------------------------------------
        # 3. TAZ-Level Attraction WMAPE
        # -------------------------------------------------------------
        mod_attr = mod_mtx.sum(axis=0)
        obs_attr = obs_mtx.sum(axis=0)  # TAZ target attractions

        abs_err = np.abs(mod_attr - obs_attr).sum()
        attr_wmape = (abs_err / obs_total) * 100

        # -------------------------------------------------------------
        # 4. Trip Length Frequency Coincidence Ratio (CR)
        # -------------------------------------------------------------
        # Create histograms weighted by the number of trips
        mod_hist, _ = np.histogram(dist_mtx, bins=bins, weights=mod_mtx)
        obs_hist, _ = np.histogram(dist_mtx, bins=bins, weights=obs_mtx)

        # Convert to probabilities (percentages of total trips in each bin)
        mod_prob = mod_hist / mod_total if mod_total > 0 else np.zeros_like(mod_hist)
        obs_prob = obs_hist / obs_total

        # CR is the sum of the minimum overlapping area between the two curves
        coincidence_ratio = np.sum(np.minimum(mod_prob, obs_prob)) * 100

        # Append to our results list
        results.append(
            {
                "Model Run": run_name,
                "Segment": seg,
                "Obs ATL": round(obs_atl, 2),
                "Mod ATL": round(mod_atl, 2),
                "Obs IZ %": round(obs_iz_pct, 1),
                "Mod IZ %": round(mod_iz_pct, 1),
                "TAZ Attr WMAPE (%)": round(attr_wmape, 1),
                "Coincidence Ratio (%)": round(coincidence_ratio, 1),  # Target is > 80%
            }
        )

    return pd.DataFrame(results)


# =========================================================
# EXAMPLE OF HOW TO RUN IT ACROSS YOUR TESTS
# =========================================================
all_metrics = []

# Assuming 'static_data["df_obs_trips"]' holds your observed TAZxTAZ matrices
# You would need to structure your observed data into a dictionary just like trips_data
obs_dict = {
    seg: static_data["df_obs_trips"][
        seg
    ].values  # Update this indexing based on your actual data structure
    for seg in segments
}

# Example: If you have a way to load your previous runs' matrices from disk:
# (If not, you can just run this dynamically at the end of your calibration loop!)
runs_to_evaluate = {
    "Test 7 (Estimation 3)": trips_data_test_7,  # Replace with actual loaded matrix dictionaries
    "Test 8 (Distance 3)": trips_data_test_8,
}

for run_name, mod_dict in runs_to_evaluate.items():
    run_df = calculate_advanced_metrics(
        run_name=run_name,
        mod_trips_dict=mod_dict,
        obs_trips_dict=obs_dict,
        dist_mtx=dist_mtx,  # Your TAZ-to-TAZ distance matrix
    )
    all_metrics.append(run_df)

# Combine and display!
final_metrics_df = pd.concat(all_metrics, ignore_index=True)
display(final_metrics_df)

