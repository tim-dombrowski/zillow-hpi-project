# St. Louis Metro Housing Affordability Dashboard

An interactive **R Shiny** dashboard that measures and visualises
ZIP-code-level housing affordability in the St. Louis, MO-IL metro area.
Home price data is sourced directly from the **Zillow Research ZHVI public CSV
files** — the same data series used throughout the parent
[zillow-hpi-project](https://github.com/tim-dombrowski/zillow-hpi-project)
repository.

---

## What the App Does

| Feature | Description |
|---------|-------------|
| **KPI Cards** | Median ZHVI, estimated monthly housing cost, affordability ratio, and recent price growth — all updated reactively as you change sidebar inputs |
| **Interactive Map** | Leaflet choropleth map of St. Louis-area ZIP codes coloured by affordability ratio, ZHVI, or 1-year price growth using ZCTA polygon boundaries |
| **Time-Series Chart** | Line chart of ZHVI over time for selected ZIP codes |
| **Affordability Ratio Chart** | Time-series view of the housing-cost-to-income ratio, with the 30 % HUD threshold line |
| **Rankings** | Top-15 most and least affordable ZIP codes (bar charts) |
| **Scatter Plots** | Price level vs. affordability ratio; 1-year growth vs. affordability ratio |
| **Data Table** | Sortable, filterable table of all ZIP codes with full financial breakdown |
| **Scenario Analysis** | Violin plot (current vs. baseline), monthly cost waterfall, and sensitivity curve of affordability ratio vs. mortgage rate |

---

## Data Source

All home price data comes from **Zillow Research** public CSV files hosted at:

```
https://files.zillowstatic.com/research/public_csvs/zhvi/
```

### ZHVI Series Used

| Geography | URL Suffix | Usage |
|-----------|------------|-------|
| **ZIP5** | `Zip_zhvi_uc_sfrcondo_tier_0.33_0.67_sm_sa_month.csv` | Primary — all analysis, charts, table, and map |

**Series specification:**
- All Homes (Single-Family Residential + Condo/Co-op)
- Middle price tier (0.33–0.67 percentile)
- Smoothed, seasonally adjusted
- Monthly frequency
- Units: US dollars

Downloaded files are cached locally in `Shiny Dashboard/cache/` and
automatically refreshed every 7 days.

---

## Geography

### Primary: ZIP5 Level

The Zillow ZIP5 dataset contains data for more than 26,000 five-digit ZIP codes
across the United States. The app filters to **`Metro == "St. Louis, MO-IL"`**,
yielding approximately 80–120 ZIP codes spanning the Missouri and Illinois sides
of the metro area.

This geography is used for all affordability analysis, rankings, time-series
charts, the data table, and the choropleth map.

### Map Layer: ZCTA Polygon Shapefiles

The choropleth map uses **ZIP Code Tabulation Area (ZCTA) polygon boundaries**
from the US Census Bureau, downloaded via the `tigris` package. Each ZIP code is
rendered as a filled polygon coloured by the selected variable (affordability
ratio, ZHVI, or 1-year price growth). Without `tigris` and `sf`, the Leaflet map
shows a brief explanatory note; all other tabs still function fully.

---

## How Affordability Is Calculated

All parameters are user-controllable via the sidebar.

### Step-by-Step Formula

```
Purchase price   = ZHVI (Zillow Home Value Index)
Down payment     = price × down_payment_pct / 100
Loan principal   = price − down payment

Monthly rate (r) = annual_mortgage_rate / 100 / 12
Loan months  (n) = term_years × 12

Monthly mortgage = principal × r × (1 + r)^n
                   ─────────────────────────────
                         (1 + r)^n − 1

Monthly tax      = price × annual_tax_rate / 100 / 12
Monthly insurance= price × annual_insurance_rate / 100 / 12

Monthly housing cost = mortgage + tax + insurance

Monthly income   = annual_household_income / 12
Affordability ratio = monthly housing cost / monthly income
```

### Affordability Thresholds

| Ratio | Classification | Basis |
|-------|---------------|-------|
| < 30 % | **Affordable** | HUD rule of thumb (households spending > 30 % are "cost-burdened") |
| 30 – 50 % | **Moderately Burdened** | Common secondary threshold |
| > 50 % | **Severely Burdened** | HUD "severely cost-burdened" threshold |

---

## User-Controlled Assumptions

| Sidebar Input | Default | Notes |
|---------------|---------|-------|
| Mortgage rate | 7.0 % | Change to reflect current market conditions |
| Loan term | 30 years | Options: 10, 15, 20, 25, 30 years |
| Down payment | 20 % | Affects loan principal and PMI exposure |
| Property tax rate | 1.2 % of value/yr | St. Louis area effective rate ≈ 1.0–1.4 % |
| Insurance rate | 0.5 % of value/yr | National average ≈ 0.4–0.7 % |
| Annual household income | $75,000 | Approx. median HH income, St. Louis MSA (ACS 2022) |

> **Note:** This app uses a scenario-based affordability model.  All financial
> outputs reflect the parameter assumptions entered in the sidebar and are
> intended for educational / illustrative purposes, not financial advice.

---

## Relationship to the Parent Repository

This dashboard extends
[tim-dombrowski/zillow-hpi-project](https://github.com/tim-dombrowski/zillow-hpi-project)
and reuses the following patterns from that codebase:

| Pattern | Where in parent repo | Reuse in this app |
|---------|----------------------|-------------------|
| Zillow download URL format | `*/importzhvi.Rmd` in every geography folder | Same base URL and file naming convention |
| `read_csv()` for download | All import notebooks | `load_zhvi_cached()` in `data_prep.R` |
| `pivot_longer()` wide-to-long reshape | All import notebooks | `clean_zhvi_wide_to_long()` in `data_prep.R` |
| Factor conversion of geographic IDs | All import notebooks | Same in `data_prep.R` |
| `Metro == "St. Louis, MO-IL"` filter | Described in parent README | Applied in `load_stl_zip_data()` |
| Blue–white–red `scale_fill_gradient2` colour scheme | `2 State-Level/zhvicomps.Rmd` | Mapped to leaflet and plotly palettes |
| Log-return / annualised growth calculations | `1 Metro-Level/zhvicomps.Rmd` | Simplified into `compute_price_growth()` |

---

## How to Run Locally

### 1. Install required R packages

```r
install.packages(c(
  "shiny",
  "shinydashboard",
  "shinycssloaders",
  "plotly",
  "leaflet",
  "DT",
  "tidyverse",
  "scales",
  "RColorBrewer"
))

# Recommended — enables ZIP code polygon choropleth map
install.packages(c("tigris", "sf"))
```

### 2. Launch the app

From the **project root** (the `zillow-hpi-project` folder):

```r
shiny::runApp("Shiny Dashboard")
```

Or open `Shiny Dashboard/app.R` in RStudio and click **Run App**.

### 3. First launch

On first start the app downloads the Zillow ZIP5 CSV (~20 MB) and caches
it in `Shiny Dashboard/cache/`. Subsequent starts load from cache (refreshed
every 7 days). An internet connection is required for the initial download.

---

## Required R Packages

| Package | Role |
|---------|------|
| `shiny` | Core web application framework |
| `shinydashboard` | Dashboard layout and value boxes |
| `shinycssloaders` | Spinner overlays while charts load |
| `plotly` | Interactive charts (time series, bar, scatter) |
| `leaflet` | Interactive map |
| `DT` | Sortable, filterable data table |
| `tidyverse` | Data download, cleaning, reshaping, ggplot2 |
| `scales` | Dollar and percent label formatting |
| `RColorBrewer` | Colour palettes |
| `tigris` *(recommended)* | US Census ZIP/ZCTA boundary shapefiles |
| `sf` *(recommended)* | Spatial data operations (polygon joins) |

---

## File Structure

```
Shiny Dashboard/
├── app.R          Main Shiny application (UI + server)
├── functions.R    Affordability calculation functions
├── data_prep.R    Zillow data download, cleaning, and filtering
├── README.md      This file
└── cache/         Auto-created; stores downloaded Zillow CSVs
```

---

## Caveats and Limitations

- **ZHVI is not a transaction price.** It is a model-smoothed estimate of the
  typical home value for the middle price tier. Actual purchase prices may
  differ.
- **ZIP code coverage varies.** Not all ZIP codes in the St. Louis metro have
  Zillow ZHVI data due to limited transaction volume in some areas.
- **No income data are fetched automatically.** Affordability is scenario-based
  using the household income entered in the sidebar. Replace the default with
  local or area median income (AMI) data from ACS or HUD for more grounded
  analysis.
- **Property tax and insurance rates are metro-wide assumptions**, not parcel-
  level estimates. Local rates vary by municipality.
- **ZCTA boundaries are Census-defined** and may not perfectly align with USPS
  ZIP code service areas.

---

*Built as part of the [zillow-hpi-project](https://github.com/tim-dombrowski/zillow-hpi-project)
educational series. Data © Zillow, Inc. under the
[Zillow Terms of Use](https://www.zillow.com/research/data/).*
