# =============================================================================
# data_prep.R
# Downloads and prepares Zillow ZHVI data for the St. Louis metro area.
#
# Geography:
#   PRIMARY  -- ZIP5-level ZHVI (five-digit ZIP code areas).
#               Filtered to Metro == "St. Louis, MO-IL".
#               Used for all affordability analysis, rankings, charts, tables,
#               and the choropleth map (ZCTA polygon boundaries from tigris).
#
# NOTE: The Data/ folder is git-ignored in the parent repo.  This script
#       caches downloaded CSV files in a local cache/ subfolder so that
#       the app does not re-download every time it starts.
# =============================================================================

library(tidyverse)

# ---- Zillow Research CSV base URL -------------------------------------------
ZILLOW_BASE = "https://files.zillowstatic.com/research/public_csvs/zhvi/"

# ---- ZHVI series: All Homes (SFR + Condo), middle tier, smoothed, SA, monthly
ZIP5_URL = paste0(ZILLOW_BASE,
  "Zip_zhvi_uc_sfrcondo_tier_0.33_0.67_sm_sa_month.csv")

# ---- St. Louis metro identifier (as used in Zillow Metro column) -------------
STL_METRO = "St. Louis, MO-IL"

# Note: cache_dir is passed explicitly to all data loading functions.
# The calling app (app.R) creates the cache directory and passes its path.


# =============================================================================
# load_zhvi_cached()
# Downloads a Zillow CSV and caches it locally.  Re-uses the cached file if
# it is less than 7 days old (avoids hammering Zillow's CDN on every restart).
#
# Arguments:
#   url        -- full URL to the Zillow CSV
#   cache_name -- filename to use locally (e.g. "neighborhood_raw.csv")
#   cache_dir  -- path to cache directory
#
# Returns: raw data frame (wide format, as downloaded)
# =============================================================================
load_zhvi_cached = function(url, cache_name, cache_dir) {
  cache_path = file.path(cache_dir, cache_name)
  needs_download = TRUE

  if (file.exists(cache_path)) {
    age_days = as.numeric(difftime(Sys.time(), file.mtime(cache_path), units = "days"))
    if (age_days < 7) needs_download = FALSE
  }

  if (needs_download) {
    message("Downloading Zillow data from: ", url)
    df = read_csv(url, show_col_types = FALSE)
    write_csv(df, cache_path)
    message("Cached to: ", cache_path)
  } else {
    message("Loading cached Zillow data from: ", cache_path)
    df = read_csv(cache_path, show_col_types = FALSE)
  }

  return(df)
}


# =============================================================================
# clean_zhvi_wide_to_long()
# Converts a wide-format Zillow ZHVI data frame to tidy long format.
#
# Wide format (as downloaded):
#   RegionID | SizeRank | RegionName | RegionType | StateName | [extra cols] |
#   2000-01-01 | 2000-02-01 | ... | YYYY-MM-DD
#
# Long format (output):
#   RegionID | SizeRank | RegionName | RegionType | StateName | Date | ZHVI
#
# The function automatically detects which columns are date columns by
# attempting to parse them as dates.
# =============================================================================
clean_zhvi_wide_to_long = function(df_wide, extra_keep_cols = character(0)) {
  # Identify the fixed geography identifier columns (always present)
  id_cols = c("RegionID", "SizeRank", "RegionName", "RegionType", "StateName")

  # Additional metadata columns present in sub-metro geographies
  meta_cols = intersect(names(df_wide),
                        c("State", "Metro", "City", "CountyName",
                          "StateCodeFIPS", "MunicipalCodeFIPS"))

  keep_meta = union(meta_cols, extra_keep_cols)

  # Everything else should be monthly date columns (YYYY-MM-DD format)
  date_candidates = setdiff(names(df_wide), c(id_cols, meta_cols))

  # Pivot to long format
  df_long = df_wide |>
    pivot_longer(
      cols      = all_of(date_candidates),
      names_to  = "Date",
      values_to = "ZHVI"
    ) |>
    mutate(
      Date     = as.Date(Date),
      RegionID = as.factor(RegionID),
      SizeRank = as.integer(SizeRank),
      RegionName = as.character(RegionName),
      RegionType = as.character(RegionType),
      StateName  = as.character(StateName)
    ) |>
    filter(!is.na(ZHVI))    # drop missing values

  return(df_long)
}


# =============================================================================
# load_stl_zip_data()
# Loads and returns tidy ZIP5-level ZHVI data for the St. Louis metro.
# RegionName is a 5-digit ZIP code string.
#
# Used as the primary data source for all affordability analysis, charts,
# tables, and the choropleth map (ZCTA polygon boundaries from tigris).
#
# Returns: data frame with columns:
#   RegionID, SizeRank, RegionName, RegionType, StateName,
#   State, Metro, City, CountyName, Date, ZHVI
# =============================================================================
load_stl_zip_data = function(cache_dir) {
  raw = load_zhvi_cached(
    url        = ZIP5_URL,
    cache_name = "zip5_raw.csv",
    cache_dir  = cache_dir
  )

  if ("Metro" %in% names(raw)) {
    raw_stl = raw[!is.na(raw$Metro) & raw$Metro == STL_METRO, ]
  } else {
    raw_stl = raw
  }

  if (nrow(raw_stl) == 0) {
    warning("No ZIP rows found for '", STL_METRO, "'.")
    return(data.frame())
  }

  long = clean_zhvi_wide_to_long(raw_stl)

  # Pad ZIP codes to 5 characters (preserve leading zeros)
  long$RegionName = formatC(as.integer(long$RegionName), width = 5,
                             flag = "0", format = "d")

  message("ZIP data loaded: ", dplyr::n_distinct(long$RegionName),
          " ZIP codes, ", dplyr::n_distinct(long$Date), " months.")

  return(long)
}


# =============================================================================
# prepare_summary_data()
# Creates a cross-sectional summary data frame (one row per ZIP code)
# for a given reference date, with affordability metrics appended.
#
# Arguments:
#   long_df     -- tidy long-format ZHVI data (from load_stl_*_data)
#   ref_date    -- Date object; the "as of" date for the snapshot
#   params      -- named list of affordability parameters:
#                    down_pct, annual_rate, term_years,
#                    annual_tax_rate, annual_ins_rate, annual_income
#
# Returns: data frame with one row per region, sorted by affordability ratio
# =============================================================================
prepare_summary_data = function(long_df, ref_date, params) {
  # functions.R is sourced by app.R before data_prep.R is called,
  # so all helper functions are available in the calling environment.
  # Snapshot at reference date (use closest available date)
  avail_dates = sort(unique(long_df$Date))
  snap_date   = avail_dates[which.min(abs(avail_dates - ref_date))]

  snap = long_df[long_df$Date == snap_date, ]

  # Compute 1-year and 3-year price growth
  growth_1y = compute_price_growth(long_df, months = 12)
  growth_3y = compute_price_growth(long_df, months = 36)

  names(growth_1y)[names(growth_1y) == "growth"] = "growth_1y"
  names(growth_3y)[names(growth_3y) == "growth"] = "growth_3y"

  # Merge growth into snapshot
  result = snap |>
    left_join(growth_1y[, c("RegionName", "growth_1y")], by = "RegionName") |>
    left_join(growth_3y[, c("RegionName", "growth_3y")], by = "RegionName")

  # Affordability calculations (vectorised over all rows)
  costs = mapply(
    total_monthly_housing_cost,
    zhvi            = result$ZHVI,
    down_pct        = params$down_pct,
    annual_rate     = params$annual_rate,
    term_years      = params$term_years,
    annual_tax_rate = params$annual_tax_rate,
    annual_ins_rate = params$annual_ins_rate,
    SIMPLIFY        = TRUE
  )

  result$monthly_mortgage   = costs["mortgage",   ]
  result$monthly_tax        = costs["tax",        ]
  result$monthly_insurance  = costs["insurance",  ]
  result$monthly_total_cost = costs["total",      ]
  result$down_amount        = costs["down_amount",]
  result$loan_principal     = costs["principal",  ]

  result$afford_ratio = affordability_ratio(result$monthly_total_cost,
                                             params$annual_income)
  result$afford_label = affordability_label(result$afford_ratio)
  result$afford_label = factor(result$afford_label,
                                levels = c("Affordable",
                                           "Moderately Burdened",
                                           "Severely Burdened",
                                           "Unknown"))
  result$snap_date = snap_date

  return(result[order(result$afford_ratio), ])
}
