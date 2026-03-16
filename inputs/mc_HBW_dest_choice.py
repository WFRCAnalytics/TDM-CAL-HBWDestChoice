# Description:
#     This script runs the destination choice model for HBW trips.
#
#     Date Edited: 2/7/2026


# ============================================================================================================
# System setup
# ============================================================================================================
print("Running Python Script: 'mc_HBW_dest_choice.py'\n")
print("System Setup...")

import subprocess
import sys
import traceback
from datetime import datetime
from pathlib import Path

import _global_scripts as gs
import numpy as np
import openmatrix as omx
import pandas as pd
from dbfread import DBF

gs.print_to_console("import global functions ('_global_scripts.py')", 3, False)


# ------------------------------------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------------------------------------
gs.print_to_console("define local functions", 3, False)


# function to sum values in the household productions creation script
def sum_columns(hbw_productions, prefix_list, veh_suffixes):
    cols = []
    for prefix in prefix_list:
        for v in veh_suffixes:
            cols.append(f"P_{prefix}{v}")
    return hbw_productions[cols].sum(axis=1)


# function used to load coefficients from the block file
def load_block_coefficients(file_path):
    coeffs = {}
    with open(file_path, "r") as f:
        for line in f:
            line = line.split(";")[0].strip()
            if not line or "=" not in line:
                continue
            name, val = line.split("=")
            name = name.strip().lower()
            val = float(val.strip())
            parts = name.split("_")
            seg = f"{parts[-2]}_{parts[-1]}"  # e.g., 0veh_lo
            param = "_".join(parts[:-2])  # e.g., intra, logsum
            if seg not in coeffs:
                coeffs[seg] = {}
            coeffs[seg][param] = val
    return coeffs


# function used to apply range-based masking for external zones
def apply_range_mask(mask_array, range_str):
    for r in range_str.split(","):
        if "-" in r:
            start, end = map(int, r.split("-"))
            # This correctly maps TAZ 3563 to Index 3562
            mask_array[start - 1 : end] = True
        else:
            mask_array[int(r) - 1] = True


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


try:
    # ============================================================================================================
    # Debug Setup and Launch Location (LAUNCH LOCATION SHOULD BE MOVED TO ARGUMENT OF PYTHON CALL)
    # ============================================================================================================
    # 1. Set your Flag
    debug = False  # Toggle this to False for production

    # 2. Define your Logic
    if debug:
        # In debug mode, runs script from the scenario directory
        dir_ScriptLaunch = Path.cwd() / "Scenarios" / "v1000-calib" / "BY_2023-C21"
    else:
        # In production, script runs from the current working directory
        dir_ScriptLaunch = Path.cwd()

    # ============================================================================================================
    # Global Parameters
    # ============================================================================================================
    gs.print_to_console("Specifying Global Parameters...", 1, False)
    time_begin_GlobalParam = datetime.now()

    # input and output names
    in_GlobalVar_txt = "py_Variables - mc_HBW_dest_choice.txt"
    out_Log_txt = "py_LogFile - mc_HBW_dest_choice.txt"

    # create path to global variables input file
    path_in_GlobalVar_txt = dir_ScriptLaunch / "_Log" / in_GlobalVar_txt
    GlobalVars = gs.load_voyager_config(path_in_GlobalVar_txt)

    # create global parameters
    ParentDir = Path(GlobalVars["ParentDir"])
    ScenarioDir = Path(GlobalVars["ScenarioDir"])
    UsedZones = int(GlobalVars["UsedZones"])
    dummyzones = GlobalVars["dummyzones"]
    externalzones = GlobalVars["externalzones"]

    # begin log file
    path_Log_dir = ParentDir / ScenarioDir / "_Log"
    path_out_Log_txt = path_Log_dir / out_Log_txt
    path_Log_dir.mkdir(parents=True, exist_ok=True)
    logFile = open(path_out_Log_txt, "w")

    gs.print_to_log("Running Python Script: 'mc_HBW_dest_choice.py'", 1, logFile)
    gs.print_to_log("", 0, logFile)
    gs.print_to_log("System setup...", 1, logFile)
    gs.print_to_log("Specifying Global Parameters...", 1, logFile)

    # log time
    time_end_GlobalParam = datetime.now()
    gs.print_to_console(
        "elapsed time: " + str(time_end_GlobalParam - time_begin_GlobalParam),
        2,
        True,
        logFile,
    )

    # ============================================================================================================
    # Input & Output Files
    # ============================================================================================================
    gs.print_to_console("Setting Input and Output Files...", 1, False)
    time_begin_input_output = datetime.now()

    # Define file paths (folders)
    path_mc_temp = ParentDir / ScenarioDir / "Temp" / "4_ModeChoice"
    path_skims = ParentDir / ScenarioDir / "4_ModeChoice" / "1a_Skims"
    path_mc_temp_sub = path_mc_temp  # / "HBW_Dest_Choice-New"

    # Define file paths (input)
    path_pa_file = ParentDir / ScenarioDir / "2_TripGen" / "pa_initial.dbf"
    path_tell_file = ParentDir / ScenarioDir / "2_TripGen" / "telecommute.dbf"
    path_se_file = ParentDir / ScenarioDir / "0_InputProcessing" / "SE_File.dbf"
    path_coeff_file = (
        ParentDir
        / "2_ModelScripts"
        / "4_ModeChoice"
        / "block"
        / "coefficients_cal8.block"
    )
    path_hh_files = [
        path_mc_temp / f"HH{i}_PercTrips_segment_hbw.dbf" for i in range(1, 7)
    ]
    path_logsums = path_mc_temp_sub / "HBW_logsums_Pk.omx"

    # Define file paths (intermediate)
    path_omx_convert_initial = path_mc_temp_sub / "convert_initial_mtx.s"
    path_cube_bat_intial = path_mc_temp_sub / "convert_initial_mtx.bat"
    path_omx_convert_final = path_mc_temp_sub / "convert_final_mtx.s"
    path_cube_bat_final = path_mc_temp_sub / "export_final_hbw_matrices.bat"

    # Define file paths (output)
    out_hh_productions = path_mc_temp_sub / "HBW_prods_by_autos_income.txt"

    # read input files
    df_se = pd.DataFrame(iter(DBF(path_se_file)))
    df_pa = pd.DataFrame(iter(DBF(path_pa_file)))
    df_tel = pd.DataFrame(iter(DBF(path_tell_file)))
    df_hh = [pd.DataFrame(iter(DBF(f))) for f in path_hh_files]

    # load coefficients file
    coeffs = load_block_coefficients(path_coeff_file)
    segments = list(coeffs.keys())

    # ensure paths exist
    path_omx_convert_initial.parent.mkdir(parents=True, exist_ok=True)
    path_omx_convert_final.parent.mkdir(parents=True, exist_ok=True)

    # log time
    time_end_input_output = datetime.now()
    gs.print_to_console(
        "elapsed time: " + str(time_end_input_output - time_begin_input_output),
        2,
        True,
        logFile,
    )

    # ============================================================================================================
    # Convert MTX to OMX
    # ============================================================================================================
    gs.print_to_console(
        "Creating CUBE script to convert HBW Dest Choice matrices to OMX",
        1,
        True,
        logFile,
    )
    time_begin_omx_intial = datetime.now()

    # define the files we need to convert
    files_to_convert = [
        (path_mc_temp / "HBW_logsums_Pk.mtx", path_mc_temp_sub / "HBW_logsums_Pk.omx"),
        (path_skims / "skm_auto_Pk.mtx", path_skims / "skm_auto_Pk.omx"),
        (
            path_mc_temp_sub / "Best_Walk_Skims.mtx",
            path_mc_temp_sub / "Best_Walk_Skims.omx",
        ),
    ]

    # write the conversion script
    with open(path_omx_convert_initial, "w") as f:
        for src, dst in files_to_convert:
            f.write(
                f'convertmat from="{src.resolve()}", to="{dst.resolve()}", compression=2, format="omx"\n'
            )

    # open batch file
    with open(path_cube_bat_intial, "w") as f:
        f.write(
            f'start /w "C:\\Program Files\\Citilabs\\CubeVoyager" VOYAGER.EXE "{path_omx_convert_initial.resolve()}" /start -Report\n'
        )

    # run batch file
    if not path_cube_bat_intial.exists():
        gs.print_to_console(
            f"Missing CUBE bat: {path_cube_bat_intial}", 2, True, logFile
        )
    else:
        gs.print_to_console(
            f"Running CUBE Conversion: {path_cube_bat_intial}", 2, True, logFile
        )
        working_dir = path_cube_bat_intial.parent
        subprocess.call(str(path_cube_bat_intial), cwd=str(working_dir))
        gs.print_to_console("CUBE Conversion finished.", 2, True, logFile)

    # log time
    time_end_omx_intial = datetime.now()
    gs.print_to_console(
        "elapsed time: " + str(time_end_omx_intial - time_begin_omx_intial),
        2,
        True,
        logFile,
    )

    # ============================================================================================================
    # Production Segmentation
    # ============================================================================================================
    gs.print_to_console("Production Segmentation", 1, True, logFile)
    time_begin_prod_segmentation = datetime.now()

    # set zone column
    zone_col = "Z"

    # merge all HH files together (sum across household sizes)
    hh_all = df_hh[0].copy()
    for df in df_hh[1:]:
        hh_all = hh_all.merge(df, on=zone_col, suffixes=("", "_dup"))

        # add duplicate columns and drop
        for col in df.columns:
            if col != zone_col:
                if col + "_dup" in hh_all.columns:
                    hh_all[col] += hh_all[col + "_dup"]
                    hh_all.drop(columns=[col + "_dup"], inplace=True)

    # merge HBW productions
    hbw_productions = hh_all.merge(df_pa[[zone_col, "HBW_P"]], on=zone_col)

    # define helper column groups
    low_income_workers = ["ILW0", "ILW1", "ILW2", "ILW3"]
    high_income_workers = ["IHW0", "IHW1", "IHW2", "IHW3"]

    # calculate trips by segment
    hbw_productions["trips_0veh_lo"] = (
        sum_columns(hbw_productions, low_income_workers, ["V0"])
        * hbw_productions["HBW_P"]
    )
    hbw_productions["trips_1veh_lo"] = (
        sum_columns(hbw_productions, low_income_workers, ["V1"])
        * hbw_productions["HBW_P"]
    )
    hbw_productions["trips_2veh_lo"] = (
        sum_columns(hbw_productions, low_income_workers, ["V2", "V3"])
        * hbw_productions["HBW_P"]
    )
    hbw_productions["trips_0veh_hi"] = (
        sum_columns(hbw_productions, high_income_workers, ["V0"])
        * hbw_productions["HBW_P"]
    )
    hbw_productions["trips_1veh_hi"] = (
        sum_columns(hbw_productions, high_income_workers, ["V1"])
        * hbw_productions["HBW_P"]
    )
    hbw_productions["trips_2veh_hi"] = (
        sum_columns(hbw_productions, high_income_workers, ["V2", "V3"])
        * hbw_productions["HBW_P"]
    )

    # zero out dummy and external zones
    mask = (hbw_productions[zone_col] == dummyzones) | (
        hbw_productions[zone_col] == externalzones
    )
    # set of columns
    cols_to_zero = [
        "trips_0veh_lo",
        "trips_1veh_lo",
        "trips_2veh_lo",
        "trips_0veh_hi",
        "trips_1veh_hi",
        "trips_2veh_hi",
    ]
    hbw_productions.loc[mask, cols_to_zero] = 0

    # write output file in correct Cube column order (no header)
    output_columns = [
        zone_col,
        "trips_0veh_lo",
        "trips_0veh_hi",
        "trips_1veh_lo",
        "trips_1veh_hi",
        "trips_2veh_lo",
        "trips_2veh_hi",
    ]
    hbw_prods_by_autos_income = hbw_productions[output_columns]

    # output file to csv
    hbw_prods_by_autos_income.to_csv(
        out_hh_productions, sep=" ", index=False, header=False, float_format="%.0f"
    )

    gs.print_to_console(
        f"HBW productions by autos/income written to: {out_hh_productions.resolve()}",
        2,
        True,
        logFile,
    )

    # log time
    time_end_prod_segmentation = datetime.now()
    gs.print_to_console(
        "elapsed time: "
        + str(time_end_prod_segmentation - time_begin_prod_segmentation),
        2,
        True,
        logFile,
    )

    # ============================================================================================================
    # Prepare for Iterative Balancing Loop
    # ============================================================================================================
    gs.print_to_console("Prepare for Iterative Balancing Loop", 1, True, logFile)
    time_begin_dc_prep = datetime.now()

    # --------------------------------------------------------------------------------
    # Setup & Masking Logic (Range-Based)
    # --------------------------------------------------------------------------------
    gs.print_to_console("Setup & Masking Logic (Range-Based)", 2, True, logFile)

    # externals
    mask_external_dummys = np.zeros(UsedZones, dtype=bool)

    # apply range-based masking for dummy and external zones
    apply_range_mask(mask_external_dummys, dummyzones)  # Blocks 3562 to 3599 (Indices)
    apply_range_mask(
        mask_external_dummys, externalzones
    )  # Blocks 3600 to 3628 (Indices)

    # align SE data (Modern Pandas Way)
    if "N" in df_se.columns:
        # Set the index to be N - 1 (so TAZ 1 is index 0)

        df_se_indexed = df_se.set_index(df_se["N"] - 1)
    else:
        df_se_indexed = df_se.copy()

    # Reindex expands the dataframe to include all zones (0 to UsedZones-1)
    df_se_full = df_se_indexed.reindex(np.arange(UsedZones)).fillna(0)

    # Optional: If you need the 'N' column to be perfectly populated for the new dummy rows
    if "N" in df_se_full.columns:
        df_se_full["N"] = np.arange(1, UsedZones + 1)

    # --------------------------------------------------------------------------------
    # Pre-Load Matrix Data before Utility Calculation
    # --------------------------------------------------------------------------------
    gs.print_to_console(
        "Pre-Load Matrix Data before Utility Calculation", 2, True, logFile
    )

    # read in skims
    skm_hwy = omx.open_file(path_skims / "skm_auto_Pk.omx", "r")
    skm_walk = omx.open_file(path_mc_temp_sub / "Best_Walk_Skims.omx", "r")

    # distance, time, and walk gencost matrices
    dist_mtx = skm_hwy["dist_GP"][:]
    hwy_time = skm_hwy["ivt_GP"][:] + skm_hwy["ovt"][:]
    walk_gencost = skm_walk["GENCOST"][:]

    # Load logsums into RAM to prevent NameError and HDF5 errors
    log_file = {}
    with omx.open_file(path_logsums, "r") as f:
        for seg in segments:
            gs.print_to_console(f"Loading logsums for {seg}...", 3, True, logFile)
            log_file[seg] = np.array(f[seg][:])

    skm_hwy.close()
    skm_walk.close()

    # --------------------------------------------------------------------------------
    # Calculate Static Components of Utility Equation
    # --------------------------------------------------------------------------------
    gs.print_to_console(
        "Calculate Static Components of Utility Equation", 2, True, logFile
    )

    # distance-based factors
    dist_sq = dist_mtx * dist_mtx
    dist_cu = dist_sq * dist_mtx
    short_trip_factor = 1.0 / np.clip(dist_mtx, 1.0, None)

    # employment ratios
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

    # calculate size term for utility equation
    size_terms = {seg: get_size_term(coeffs[seg], df_se_full) for seg in segments}

    # create true false matrix on if cells are in the same district
    dist_lrg = df_se_full["DISTLRG"].values
    district_match = dist_lrg[:, np.newaxis] == dist_lrg[np.newaxis, :]

    # initiate arrays for utility calculation
    adj_factors = np.zeros(UsedZones)
    trips_data = {seg: {} for seg in segments}
    target_attractions = np.zeros(UsedZones)

    # ensure correct indexing for tripgen pa data
    df_pa["Zone_Index"] = df_pa["Z"].astype(int) - 1
    valid_pa = df_pa[df_pa["Zone_Index"] < UsedZones]
    target_attractions[valid_pa["Zone_Index"].values] = valid_pa["HBW_A"].values

    # log time
    time_end_dc_prep = datetime.now()
    gs.print_to_console(
        "elapsed time: " + str(time_end_dc_prep - time_begin_dc_prep),
        2,
        True,
        logFile,
    )

    # ============================================================================================================
    # Iterative Balancing Loop
    # ============================================================================================================
    gs.print_to_console(
        "Run iterative balancing loop, calculate utilities, and converge trips",
        1,
        True,
        logFile,
    )
    time_begin_utility = datetime.now()

    # iterative balancing loop and utility calculation
    # loop until convergence or max iterations
    for iterate in range(1, 11):
        total_trips_od = np.zeros((UsedZones, UsedZones))

        # loop through each vehicle ownership (0,1,2) and income segment (lo, hi)
        for seg in segments:
            c, st_vector = coeffs[seg], size_terms[seg]

            # -----------------------#
            # 1. production alignment
            p_seg_original = hbw_prods_by_autos_income[f"trips_{seg}"].values.copy()
            p_seg = p_seg_original.copy()
            p_seg[mask_external_dummys] = 0

            # -----------------------#
            # 2. utility calculation
            utility = (
                (c["logsum"] * log_file[seg][:])
                + short_trip_factor
                + ((c["hwy_dist"] - c["distcal"]) * dist_mtx)
                + (0.00075 * dist_sq)
                + (-0.000002 * dist_cu)
                + (c["hwy_time"] * hwy_time)
                + (c["transit_cost"] * walk_gencost)
                + st_vector[None, :]
                + adj_factors[None, :]
                + (c["retail_ratio"] * retail_ratio)[None, :]
                + (c["industrial_ratio"] * ind_ratio)[None, :]
                + (c["other_ratio"] * other_ratio)[None, :]
            )

            # apply intrazonal factor
            np.fill_diagonal(utility, utility.diagonal() + c["intra"])

            # apply district match factor
            utility += np.where(district_match, c["intradist"], 0)

            # -----------------------#
            # 3. exponentiate
            exp_u = np.exp(utility)

            # set utilities to zero based on production and attraction constraints
            exp_u[p_seg <= 0, :] = 0
            exp_u[:, df_se_full["TOTEMP"].values <= 0] = 0
            exp_u[:, mask_external_dummys] = 0

            # -----------------------#
            # 4. calculate sum of probability of each zone across row (logit model denominator)
            row_sums = exp_u.sum(axis=1)[:, np.newaxis]

            # calculate share matrix (probability of choosing each destination)
            share_mtx = np.divide(
                exp_u, row_sums, out=np.zeros_like(exp_u), where=row_sums != 0
            )

            # -----------------------#
            # 5. calculate trip matrix
            trips_mtx = share_mtx * p_seg[:, np.newaxis]

            trips100_mtx = trips_mtx * 100
            share100_mtx = share_mtx * 100

            # store output data for export
            trips_data[seg] = {
                "share": share100_mtx,
                "trips100": trips100_mtx,
                "trips": trips_mtx,
            }
            total_trips_od += trips_mtx

        # -----------------------#
        # 6. attraction balancing
        current_attractions = total_trips_od.sum(axis=0)

        # identify zones eligible for balancing
        adj_mask = (target_attractions > 0) & (~mask_external_dummys)

        # calculate additive adjustmetn factor (log of ratio of target to current attractions)
        new_step = np.zeros_like(adj_factors)
        safe_mask = adj_mask & (current_attractions > 0)
        new_step[safe_mask] = np.log(
            target_attractions[safe_mask] / current_attractions[safe_mask]
        )

        # udpate factors for next iteration
        adj_factors += new_step

        # -----------------------#
        # 7. convergence audit
        abs_diff = np.abs(current_attractions - target_attractions)
        pct_diff = np.zeros_like(abs_diff)
        np.divide(
            abs_diff, target_attractions, out=pct_diff, where=target_attractions > 0
        )

        # convergence criteria check
        # percent difference less than 2% or absolute difference less than 10 trips
        converged_zones = ((pct_diff < 0.02) | (abs_diff <= 10)) & (
            target_attractions > 0
        )
        percent_converged = np.sum(converged_zones) / np.sum(target_attractions > 0)

        # converged if more than 99% of zones meet convergence criteria
        gs.print_to_console(
            f"Iteration {iterate}: {percent_converged:.2%} of zones converged.",
            2,
            True,
            logFile,
        )
        if percent_converged > 0.99:
            gs.print_to_console(
                "Model Converged. More than 99% of zones meet convergence criteria.",
                2,
                True,
                logFile,
            )
            break

    # log time
    time_end_utility = datetime.now()
    gs.print_to_console(
        "elapsed time: " + str(time_end_utility - time_begin_utility),
        2,
        True,
        logFile,
    )

    # ============================================================================================================
    # Finalize trips and post-process for telecommuting adjustments
    # ============================================================================================================
    gs.print_to_console(
        "Finalize trips and post-process for telecommuting adjustments",
        1,
        True,
        logFile,
    )
    time_begin_finalize = datetime.now()

    # extract telecommute arrays from your telecommuting input
    pct_tel_hbw = df_tel["PCTTELHBW"].values.reshape(1, -1)
    fac_tel_hbw = df_tel["FACTELHBW"].values.reshape(1, -1)

    # initialize dictionaries to hold our new matrices
    post_proc = {}
    totals = {
        "ini_trips100": 0,
        "ini_trips": 0,
        "trips100": 0,
        "trips": 0,
        "Tel_trips100": 0,
        "Tel_trips": 0,
        "Tot_trips100": 0,
        "Tot_trips": 0,
    }

    # calculate telecommute adjustments for each segment
    for seg in segments:  # '0veh_lo', '0veh_hi', etc.
        ini_trips100 = trips_data[seg]["trips100"]
        ini_trips = trips_data[seg]["trips"]
        share = trips_data[seg]["share"]

        # calculate telecommute trips
        tel_trips100 = ini_trips100 * pct_tel_hbw
        tel_trips = ini_trips * pct_tel_hbw

        # calculate adjustment to account for telecommute
        adj_trips100 = ini_trips100 * fac_tel_hbw
        adj_trips = ini_trips * fac_tel_hbw

        # calculate final HBW trips by applying trip adjustment
        final_trips100 = ini_trips100 - adj_trips100
        final_trips = ini_trips - adj_trips

        # calculate Total = Final trips + Tel Trips
        tot_trips100 = final_trips100 + tel_trips100
        tot_trips = final_trips + tel_trips

        # store everything for this segment
        post_proc[seg] = {
            "ini_trips100": ini_trips100,
            "ini_trips": ini_trips,
            "trips100": final_trips100,
            "trips": final_trips,
            "Tel_trips100": tel_trips100,
            "Tel_trips": tel_trips,
            "Tot_trips100": tot_trips100,
            "Tot_trips": tot_trips,
            "share": share,
        }

        # add to running totals for the pa_HBW_total.mtx equivalent
        for key in totals.keys():
            totals[key] += post_proc[seg][key]

    # calculate Aggregate Summaries by Vehicle Class
    veh_sums = {}
    for v in ["0veh", "1veh", "2veh"]:
        lo_seg = f"{v}_lo"
        hi_seg = f"{v}_hi"

        veh_sums[v] = {
            "Final": post_proc[lo_seg]["trips"] + post_proc[hi_seg]["trips"],
            "Tel": post_proc[lo_seg]["Tel_trips"] + post_proc[hi_seg]["Tel_trips"],
            "Tot": post_proc[lo_seg]["Tot_trips"] + post_proc[hi_seg]["Tot_trips"],
        }

    # export individual segment matrices
    for seg in segments:
        # Append '_noXI' only for 2veh segments
        suffix = "_noXI" if "2veh" in seg else ""
        file_name = f"pa_HBW_{seg}{suffix}_tmp.omx"

        out_file = path_mc_temp_sub / file_name
        with omx.open_file(out_file, "w") as f:
            for mat_name, matrix_data in post_proc[seg].items():
                f[mat_name] = matrix_data

        gs.print_to_console(f"Created OMX file: {file_name}", 2, True, logFile)

    # export total summary matrix
    total_file = path_mc_temp_sub / "pa_HBW_total_noXI_tmp.omx"
    with omx.open_file(total_file, "w") as f:
        for mat_name, matrix_data in totals.items():
            f[mat_name] = matrix_data

    gs.print_to_console("Created OMX file: pa_HBW_total_noXI.omx", 2, True, logFile)

    # export aggregate vehicle matrices
    veh_file = path_mc_temp_sub / "pa_HBW_NumVeh_noXI_tmp.omx"
    with omx.open_file(veh_file, "w") as f:
        # Final Trips
        f["HBWTOT"] = totals["trips"]
        f["HBW0"] = veh_sums["0veh"]["Final"]
        f["HBW1"] = veh_sums["1veh"]["Final"]
        f["HBW2"] = veh_sums["2veh"]["Final"]

        # Telecommute Trips
        f["Tel_HBWTOT"] = totals["Tel_trips"]
        f["Tel_HBW0"] = veh_sums["0veh"]["Tel"]
        f["Tel_HBW1"] = veh_sums["1veh"]["Tel"]
        f["Tel_HBW2"] = veh_sums["2veh"]["Tel"]

        # Total Trips
        f["Tot_HBWTOT"] = totals["Tot_trips"]
        f["Tot_HBW0"] = veh_sums["0veh"]["Tot"]
        f["Tot_HBW1"] = veh_sums["1veh"]["Tot"]
        f["Tot_HBW2"] = veh_sums["2veh"]["Tot"]

    gs.print_to_console(
        "Created OMX file: pa_HBW_NumVeh_noXI_tmp.omx", 2, True, logFile
    )

    # calculate pa_HBW_0veh.mtx for downstream use
    zero_veh_file = path_mc_temp_sub / "pa_HBW_0veh.omx"
    with omx.open_file(zero_veh_file, "w") as f:
        f["trips"] = veh_sums["0veh"]["Final"]

    # Log successful creation
    gs.print_to_console("Created OMX file: pa_HBW_0veh.omx", 2, True, logFile)

    gs.print_to_console(
        "Post-processing complete. All OMX files written.", 2, True, logFile
    )

    # log time
    time_end_finalize = datetime.now()
    gs.print_to_console(
        "elapsed time: " + str(time_end_finalize - time_begin_finalize),
        2,
        True,
        logFile,
    )

    # ============================================================================================================
    # Convert Post-Processed OMX files back to MTX
    # ============================================================================================================
    gs.print_to_console(
        "Convert Post-Processed OMX files back to MTX",
        1,
        True,
        logFile,
    )

    with open(path_omx_convert_final, "w") as f:
        # 1. Convert each segment file
        for seg in segments:
            # CURVEBALL FIX: Append '_noXI' only for 2veh segments
            suffix = "_noXI" if "2veh" in seg else ""

            omx_f = f"pa_HBW_{seg}{suffix}_tmp.omx"
            mtx_f = f"pa_HBW_{seg}{suffix}_tmp.mtx"
            src = path_mc_temp_sub / omx_f
            dst = path_mc_temp_sub / mtx_f
            f.write(f'convertmat from="{src}", to="{dst}", format=TPP\n')

        # 2. Convert the total file
        total_src = path_mc_temp_sub / "pa_HBW_total_noXI_tmp.omx"
        total_dst = path_mc_temp_sub / "pa_HBW_total_noXI_tmp.mtx"
        f.write(f'convertmat from="{total_src}", to="{total_dst}", format=TPP\n')

        # 3. Convert the Aggregate NumVeh file
        veh_src = path_mc_temp_sub / "pa_HBW_NumVeh_noXI_tmp.omx"
        veh_dst = path_mc_temp_sub / "pa_HBW_NumVeh_noXI_tmp.mtx"
        f.write(f'convertmat from="{veh_src}", to="{veh_dst}", format=TPP\n')

        # 4. Convert the Zero-Veh file
        zero_src = path_mc_temp_sub / "pa_HBW_0veh.omx"
        zero_dst = path_mc_temp_sub / "pa_HBW_0veh.mtx"
        f.write(f'convertmat from="{zero_src}", to="{zero_dst}", format=TPP\n')

    # Create and run the .bat file
    with open(path_cube_bat_final, "w") as f:
        f.write(
            f'start /w "C:\\Program Files\\Citilabs\\CubeVoyager" VOYAGER.EXE "{path_omx_convert_final}" /start -Report\n'
        )

    if not path_cube_bat_final.exists():
        gs.print_to_console(
            f"Missing CUBE bat: {path_cube_bat_final}", 2, True, logFile
        )
    else:
        gs.print_to_console("Running final OMX to MTX Conversion...", 2, True, logFile)
        subprocess.call(str(path_cube_bat_final), cwd=str(path_cube_bat_final.parent))
        gs.print_to_console(
            "Conversion finished. All post-processed .mtx files are ready.",
            2,
            True,
            logFile,
        )


except Exception:
    import traceback

    # 1. Capture the entire error message and exact line numbers
    full_traceback = traceback.format_exc()

    # 2. BULLETPROOF CONSOLE PRINT: Do this first before anything else can crash!
    print("\n" + "=" * 85)
    print("!!! FATAL ERROR ENCOUNTERED !!!")
    print("=" * 85)
    print(full_traceback)
    print("=" * 85)

    # 3. SAFELY ATTEMPT LOGGING: Only write to log if it was successfully created
    if "logFile" in locals() and not logFile.closed:
        try:
            gs.print_to_log(
                "\n==================================================", 0, logFile
            )
            gs.print_to_log("FATAL PYTHON ERROR:", 1, logFile)
            gs.print_to_log(full_traceback, 1, logFile)
            logFile.close()
        except Exception:
            print("Notice: Could not write the error to the log file.")

    # 4. SAFELY PRINT FOLDER INFO: Only if ScenarioDir was successfully defined
    if "ScenarioDir" in locals() and "out_Log_txt" in locals():
        print(
            f"\nPlease check '{ScenarioDir}\\_Log\\{out_Log_txt}' for messages (if generated)."
        )

    # 5. FREEZE THE WINDOW: Wait for the user to read the error
    print("\n*** The script has stopped due to the error above. ***")
    input("Press Enter to close this window and exit...")

    # exit python & hand control back to Cube
    sys.exit(1)
