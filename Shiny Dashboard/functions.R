# =============================================================================
# functions.R
# Helper functions for the St. Louis Housing Affordability Dashboard
#
# Affordability framework:
#   Purchase price  = ZHVI (Zillow Home Value Index)
#   Down payment    = price * down_pct / 100
#   Loan principal  = price - down payment
#   Monthly payment = standard fixed-rate amortization formula
#   Monthly housing = payment + monthly property tax + monthly insurance
#   Affordability   = monthly housing cost / (annual income / 12)
#
# Rule of thumb: households spending >30 % of gross income on housing are
# "cost-burdened" (U.S. Department of Housing and Urban Development).
# =============================================================================


# -----------------------------------------------------------------------------
# monthly_mortgage_payment()
# Standard fixed-rate amortization formula.
#
# Arguments:
#   principal  -- loan amount in dollars
#   annual_rate -- annual interest rate as a percentage (e.g. 7.0 for 7 %)
#   term_years  -- loan term in years (e.g. 30)
#
# Returns: monthly principal-and-interest payment in dollars
# -----------------------------------------------------------------------------
monthly_mortgage_payment = function(principal, annual_rate, term_years) {
  r = (annual_rate / 100) / 12   # monthly decimal rate
  n = term_years * 12            # total number of monthly payments

  # Edge case: 0 % rate is a simple equal-installment loan
  if (r == 0) {
    return(principal / n)
  }

  payment = principal * r * (1 + r)^n / ((1 + r)^n - 1)
  return(payment)
}


# -----------------------------------------------------------------------------
# monthly_tax_cost()
# Estimates the monthly property tax component.
#
# Arguments:
#   home_price   -- estimated home value (ZHVI)
#   annual_tax_rate -- annual property tax rate as a percentage (e.g. 1.2)
#
# Returns: monthly property tax amount in dollars
# -----------------------------------------------------------------------------
monthly_tax_cost = function(home_price, annual_tax_rate) {
  return((home_price * annual_tax_rate / 100) / 12)
}


# -----------------------------------------------------------------------------
# monthly_insurance_cost()
# Estimates monthly homeowner's insurance.
#
# Arguments:
#   home_price       -- estimated home value (ZHVI)
#   annual_ins_rate  -- annual insurance rate as a percentage (e.g. 0.5)
#
# Returns: monthly insurance cost in dollars
# -----------------------------------------------------------------------------
monthly_insurance_cost = function(home_price, annual_ins_rate) {
  return((home_price * annual_ins_rate / 100) / 12)
}


# -----------------------------------------------------------------------------
# total_monthly_housing_cost()
# Sums mortgage payment, property tax, and insurance.
#
# Arguments:
#   zhvi            -- ZHVI (used as purchase price)
#   down_pct        -- down payment as a percentage (e.g. 20)
#   annual_rate     -- annual mortgage rate as a percentage (e.g. 7.0)
#   term_years      -- loan term in years
#   annual_tax_rate -- annual property tax rate as a percentage
#   annual_ins_rate -- annual insurance rate as a percentage
#
# Returns: named numeric vector with components and total
# -----------------------------------------------------------------------------
total_monthly_housing_cost = function(zhvi,
                                       down_pct       = 20,
                                       annual_rate    = 7.0,
                                       term_years     = 30,
                                       annual_tax_rate = 1.2,
                                       annual_ins_rate = 0.5) {
  down_amount = zhvi * down_pct / 100
  principal   = zhvi - down_amount
  mortgage    = monthly_mortgage_payment(principal, annual_rate, term_years)
  tax         = monthly_tax_cost(zhvi, annual_tax_rate)
  insurance   = monthly_insurance_cost(zhvi, annual_ins_rate)
  total       = mortgage + tax + insurance

  return(c(
    down_amount = down_amount,
    principal   = principal,
    mortgage    = mortgage,
    tax         = tax,
    insurance   = insurance,
    total       = total
  ))
}


# -----------------------------------------------------------------------------
# affordability_ratio()
# Calculates the housing-cost-to-income ratio.
#
# Arguments:
#   monthly_housing_cost -- total monthly housing cost in dollars
#   annual_income        -- annual household income in dollars
#
# Returns: ratio (e.g. 0.32 means 32 % of income goes to housing)
# -----------------------------------------------------------------------------
affordability_ratio = function(monthly_housing_cost, annual_income) {
  monthly_income = annual_income / 12
  if (monthly_income <= 0) return(NA_real_)
  return(monthly_housing_cost / monthly_income)
}


# -----------------------------------------------------------------------------
# affordability_label()
# Classifies the affordability ratio into three buckets.
#
# Thresholds (HUD-inspired rule of thumb):
#   < 30 %  --> "Affordable"
#   30–50 % --> "Moderately Burdened"
#   > 50 %  --> "Severely Burdened"
#
# Arguments:
#   ratio -- affordability ratio (numeric, 0–1 scale)
#
# Returns: character label
# -----------------------------------------------------------------------------
affordability_label = function(ratio) {
  dplyr::case_when(
    is.na(ratio)   ~ "Unknown",
    ratio < 0.30   ~ "Affordable",
    ratio <= 0.50  ~ "Moderately Burdened",
    TRUE           ~ "Severely Burdened"
  )
}


# -----------------------------------------------------------------------------
# compute_price_growth()
# Computes 1-year and 3-year annualised price growth for each region.
#
# Arguments:
#   df       -- long-format data frame with columns: RegionName, Date, ZHVI
#   months   -- lookback window in months (default 12 for 1-year)
#
# Returns: data frame with columns RegionName, growth (proportion, e.g. 0.05)
# -----------------------------------------------------------------------------
compute_price_growth = function(df, months = 12) {
  latest_date = max(df$Date, na.rm = TRUE)
  prior_date  = latest_date - months * 30   # approximate

  # Find the closest available date to the prior date
  available_dates = sort(unique(df$Date))
  prior_date = available_dates[which.min(abs(available_dates - prior_date))]

  now_df   = df[df$Date == latest_date, c("RegionName", "ZHVI")]
  prior_df = df[df$Date == prior_date,  c("RegionName", "ZHVI")]

  merged = merge(now_df, prior_df, by = "RegionName", suffixes = c("_now", "_prior"))
  merged$growth = (merged$ZHVI_now - merged$ZHVI_prior) / merged$ZHVI_prior

  return(merged[, c("RegionName", "growth", "ZHVI_now", "ZHVI_prior")])
}


# -----------------------------------------------------------------------------
# dollar_fmt() / pct_fmt()
# Convenience wrappers for label formatting used in UI and plots.
# -----------------------------------------------------------------------------
dollar_fmt = function(x, accuracy = 1) {
  scales::dollar(x, accuracy = accuracy, big.mark = ",")
}

pct_fmt = function(x, accuracy = 0.1) {
  scales::percent(x, accuracy = accuracy)
}
