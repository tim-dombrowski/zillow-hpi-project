# =============================================================================
# app.R  --  St. Louis Metro Housing Affordability Dashboard
# =============================================================================
#
# Overview:
#   Interactive Shiny dashboard that visualises ZIP5-level housing affordability
#   in the St. Louis, MO-IL metro area.  Home price data comes directly from
#   the Zillow Research ZHVI public CSV files.
#
# Data:
#   PRIMARY  -- ZIP5-level ZHVI filtered to Metro == "St. Louis, MO-IL"
#               Used for all analysis, charts, tables, and the choropleth map.
#               ZCTA polygon boundaries rendered via tigris/sf (recommended).
#
# Affordability model:
#   All parameters are user-controlled via the sidebar.
#   See functions.R for the full calculation logic.
#
# Related repo:
#   This app extends tim-dombrowski/zillow-hpi-project, reusing the same
#   Zillow download URLs, wide-to-long reshaping pattern, and ggplot2/scale
#   conventions established in the parent notebooks.
#
# Required packages (install once):
#   shiny, shinydashboard, shinycssloaders, plotly, leaflet, DT,
#   tidyverse, scales, RColorBrewer
#
#   Recommended (for polygon choropleth map):
#     tigris, sf
#
# Run locally:
#   shiny::runApp("Shiny Dashboard")
# =============================================================================


# ---- Package loading ---------------------------------------------------------
suppressPackageStartupMessages({
  library(shiny)
  library(shinydashboard)
  library(shinycssloaders)
  library(plotly)
  library(leaflet)
  library(DT)
  library(tidyverse)
  library(scales)
  library(RColorBrewer)
})

# tigris / sf are recommended; used for ZIP polygon choropleth map
HAS_TIGRIS = requireNamespace("tigris",   quietly = TRUE) &&
             requireNamespace("sf",       quietly = TRUE)

if (HAS_TIGRIS) {
  library(tigris)
  library(sf)
  options(tigris_use_cache = TRUE)
}

# ---- Source helper files -----------------------------------------------------
# When launched via shiny::runApp("Shiny Dashboard") the working directory is
# set to the app folder automatically by Shiny.  We use that as the base path.
APP_DIR   = getwd()

source(file.path(APP_DIR, "functions.R"))
source(file.path(APP_DIR, "data_prep.R"))

# ---- Cache directory ---------------------------------------------------------
CACHE_DIR = file.path(APP_DIR, "cache")
if (!dir.exists(CACHE_DIR)) dir.create(CACHE_DIR, recursive = TRUE)

# ---- Default sidebar values --------------------------------------------------
DEFAULT = list(
  down_pct        = 20,
  annual_rate     = 7.0,
  term_years      = 30,
  annual_tax_rate = 1.2,
  annual_ins_rate = 0.5,
  annual_income   = 75000
)

# ---- Affordability colour palette -------------------------------------------
AFFORD_COLORS = c(
  "Affordable"          = "#2ca02c",
  "Moderately Burdened" = "#ff7f0e",
  "Severely Burdened"   = "#d62728",
  "Unknown"             = "#aaaaaa"
)

# =============================================================================
# UI
# =============================================================================
ui = dashboardPage(
  skin = "blue",

  dashboardHeader(
    title = "STL Housing Affordability"
  ),

  # ---- Sidebar ---------------------------------------------------------------
  dashboardSidebar(
    sidebarMenu(
      id = "tabs",
      menuItem("Overview",           tabName = "overview",   icon = icon("home")),
      menuItem("Time Series",        tabName = "timeseries", icon = icon("chart-line")),
      menuItem("Affordability Rank", tabName = "rankings",   icon = icon("list-ol")),
      menuItem("Data Table",         tabName = "table",      icon = icon("table")),
      menuItem("Scenario Analysis",  tabName = "scenario",   icon = icon("sliders-h")),
      menuItem("About",              tabName = "about",      icon = icon("info-circle"))
    ),

    hr(),
    tags$div(style = "padding: 8px 15px; font-size: 11px; color: #aaa;",
             "Geography"),

    # Region multi-select (populated reactively)
    selectizeInput(
      inputId  = "selected_regions",
      label    = "Select ZIP Codes",
      choices  = NULL,
      multiple = TRUE,
      options  = list(placeholder = "All (or choose specific)")
    ),

    hr(),
    tags$div(style = "padding: 8px 15px; font-size: 11px; color: #aaa;",
             "Reference Date"),

    sliderInput(
      inputId = "ref_date",
      label   = NULL,
      min     = as.Date("2010-01-01"),
      max     = Sys.Date(),
      value   = Sys.Date() - 30,
      step    = 30,
      timeFormat = "%b %Y"
    ),

    hr(),
    tags$div(style = "padding: 8px 15px; font-size: 11px; color: #aaa;",
             "Mortgage Assumptions"),

    sliderInput("annual_rate",  "Mortgage Rate (%)",
                min = 2, max = 14, value = DEFAULT$annual_rate, step = 0.25),

    selectInput("term_years", "Loan Term (years)",
                choices  = c(10, 15, 20, 25, 30),
                selected = DEFAULT$term_years),

    sliderInput("down_pct", "Down Payment (%)",
                min = 0, max = 50, value = DEFAULT$down_pct, step = 1),

    hr(),
    tags$div(style = "padding: 8px 15px; font-size: 11px; color: #aaa;",
             "Housing Cost Assumptions"),

    sliderInput("annual_tax_rate",  "Property Tax Rate (% of value/yr)",
                min = 0.1, max = 4, value = DEFAULT$annual_tax_rate, step = 0.1),

    sliderInput("annual_ins_rate",  "Insurance Rate (% of value/yr)",
                min = 0.1, max = 2, value = DEFAULT$annual_ins_rate, step = 0.1),

    hr(),
    tags$div(style = "padding: 8px 15px; font-size: 11px; color: #aaa;",
             "Household Income"),

    numericInput("annual_income", "Annual Household Income ($)",
                 value = DEFAULT$annual_income, min = 1000, max = 1e7, step = 1000),

    hr(),
    actionButton("reset_defaults", "Reset to Defaults",
                 icon = icon("undo"), width = "100%",
                 class = "btn-warning btn-sm")
  ),  # end dashboardSidebar

  # ---- Body ------------------------------------------------------------------
  dashboardBody(

    # Custom CSS for polished cards
    tags$head(tags$style(HTML("
      .kpi-box { text-align: center; padding: 10px 5px; }
      .kpi-value { font-size: 26px; font-weight: bold; color: #2c3e50; }
      .kpi-label { font-size: 11px; color: #777; text-transform: uppercase;
                   letter-spacing: 1px; margin-top: 2px; }
      .small-box .inner h3 { font-size: 22px; }
      .info-note { font-size: 12px; color: #888; font-style: italic; }
    "))),

    tabItems(

      # ------------------------------------------------------------------
      # Tab 1: Overview
      # ------------------------------------------------------------------
      tabItem(tabName = "overview",

        fluidRow(
          valueBoxOutput("kpi_zip_codes", width = 2),
          valueBoxOutput("kpi_median_zhvi",   width = 2),
          valueBoxOutput("kpi_monthly_cost",  width = 3),
          valueBoxOutput("kpi_afford_ratio",  width = 2),
          valueBoxOutput("kpi_growth_1y",     width = 3)
        ),

        fluidRow(
          box(
            title  = "Affordability Map",
            status = "primary", solidHeader = TRUE,
            width  = 8, height = "520px",
            leafletOutput("map_leaflet", height = "450px") |>
              withSpinner(color = "#3498db")
          ),
          box(
            title  = "Affordability Distribution",
            status = "primary", solidHeader = TRUE,
            width  = 4, height = "520px",
            plotlyOutput("afford_donut", height = "200px"),
            hr(),
            tags$p(class = "info-note",
              "Map shows ZIP code polygons coloured by the selected variable. ",
              "Hover over a polygon to see ZHVI, monthly cost, and affordability ",
              "details. Polygon boundaries are ZCTA shapefiles from the US Census ",
              "Bureau via the tigris package."
            ),
            radioButtons("map_color_var", "Colour polygons by:",
                         choices = c(
                           "Affordability Ratio" = "afford_ratio",
                           "Latest ZHVI"         = "ZHVI",
                           "1-Year Price Growth" = "growth_1y"
                         ),
                         selected = "afford_ratio")
          )
        )
      ),  # end overview

      # ------------------------------------------------------------------
      # Tab 2: Time Series
      # ------------------------------------------------------------------
      tabItem(tabName = "timeseries",

        fluidRow(
          box(
            title  = "ZHVI Over Time — Selected ZIP Codes",
            status = "primary", solidHeader = TRUE,
            width  = 12,
            plotlyOutput("ts_plot", height = "450px") |>
              withSpinner(color = "#3498db")
          )
        ),
        fluidRow(
          box(
            title  = "Affordability Ratio Over Time",
            status = "info", solidHeader = TRUE,
            width  = 12,
            plotlyOutput("ts_afford_plot", height = "350px") |>
              withSpinner(color = "#3498db")
          )
        )
      ),  # end timeseries

      # ------------------------------------------------------------------
      # Tab 3: Affordability Rankings
      # ------------------------------------------------------------------
      tabItem(tabName = "rankings",

        fluidRow(
          box(
            title  = "Most Affordable ZIP Codes (Current)",
            status = "success", solidHeader = TRUE,
            width  = 6,
            plotlyOutput("bar_affordable", height = "400px") |>
              withSpinner(color = "#3498db")
          ),
          box(
            title  = "Least Affordable ZIP Codes (Current)",
            status = "danger", solidHeader = TRUE,
            width  = 6,
            plotlyOutput("bar_unaffordable", height = "400px") |>
              withSpinner(color = "#3498db")
          )
        ),

        fluidRow(
          box(
            title  = "Price Level vs. Affordability Ratio",
            status = "primary", solidHeader = TRUE,
            width  = 6,
            plotlyOutput("scatter_price_afford", height = "380px") |>
              withSpinner(color = "#3498db")
          ),
          box(
            title  = "1-Year Price Growth vs. Affordability Ratio",
            status = "primary", solidHeader = TRUE,
            width  = 6,
            plotlyOutput("scatter_growth_afford", height = "380px") |>
              withSpinner(color = "#3498db")
          )
        )
      ),  # end rankings

      # ------------------------------------------------------------------
      # Tab 4: Data Table
      # ------------------------------------------------------------------
      tabItem(tabName = "table",
        fluidRow(
          box(
            title  = "ZIP Code Summary Table",
            status = "primary", solidHeader = TRUE,
            width  = 12,
            DTOutput("summary_table") |>
              withSpinner(color = "#3498db"),
            tags$p(class = "info-note",
              "All dollar values are in nominal terms. ",
              "Affordability Ratio = monthly housing cost / (annual income / 12). ",
              "30 % threshold (HUD rule of thumb): ratios above 0.30 indicate cost burden."
            )
          )
        )
      ),  # end table

      # ------------------------------------------------------------------
      # Tab 5: Scenario Analysis
      # ------------------------------------------------------------------
      tabItem(tabName = "scenario",

        fluidRow(
          box(
            title = "Scenario Analysis: How Do Assumptions Affect Affordability?",
            status = "warning", solidHeader = TRUE,
            width  = 12,
            tags$p(
              "Use the sidebar inputs to change mortgage rate, down payment, ",
              "income, or loan term.  All charts and the map update instantly. ",
              "Below, compare the current sidebar scenario against a baseline."
            )
          )
        ),

        fluidRow(
          box(
            title  = "Scenario: Affordability Ratio Distribution",
            status = "warning", solidHeader = TRUE,
            width  = 6,
            plotlyOutput("scenario_violin", height = "380px") |>
              withSpinner(color = "#3498db")
          ),
          box(
            title  = "Monthly Cost Breakdown (Median ZIP Code)",
            status = "warning", solidHeader = TRUE,
            width  = 6,
            plotlyOutput("scenario_waterfall", height = "380px") |>
              withSpinner(color = "#3498db")
          )
        ),

        fluidRow(
          box(
            title  = "Sensitivity: Affordability Ratio vs. Mortgage Rate",
            status = "warning", solidHeader = TRUE,
            width  = 12,
            plotlyOutput("scenario_rate_sensitivity", height = "350px") |>
              withSpinner(color = "#3498db")
          )
        )
      ),  # end scenario

      # ------------------------------------------------------------------
      # Tab 6: About
      # ------------------------------------------------------------------
      tabItem(tabName = "about",
        fluidRow(
          box(
            title  = "About This Dashboard",
            status = "primary", solidHeader = TRUE,
            width  = 12,
            includeMarkdown(file.path(APP_DIR, "README.md"))
          )
        )
      )  # end about

    )  # end tabItems
  )  # end dashboardBody
)  # end dashboardPage


# =============================================================================
# SERVER
# =============================================================================
server = function(input, output, session) {

  # --------------------------------------------------------------------------
  # Load ZIP5 data
  # --------------------------------------------------------------------------
  raw_long = reactive({
    df = load_stl_zip_data(CACHE_DIR)
    validate(need(nrow(df) > 0,
      "No data available. Check your internet connection and try again."))
    df
  })

  # Update region selector choices when data changes
  observeEvent(raw_long(), {
    df = raw_long()
    regions = sort(unique(df$RegionName))
    updateSelectizeInput(session, "selected_regions",
                         choices = regions, selected = character(0),
                         server  = TRUE)
    # Update reference date slider to match available dates
    dates = sort(unique(df$Date))
    updateSliderInput(session, "ref_date",
                      min   = min(dates),
                      max   = max(dates),
                      value = max(dates))
  })

  # Filtered long data (subset to selected regions if any chosen)
  filtered_long = reactive({
    df  = raw_long()
    sel = input$selected_regions
    if (length(sel) > 0) df = df[df$RegionName %in% sel, ]
    df
  })

  # Current affordability parameters (from sidebar)
  afford_params = reactive({
    list(
      down_pct        = as.numeric(input$down_pct),
      annual_rate     = as.numeric(input$annual_rate),
      term_years      = as.numeric(input$term_years),
      annual_tax_rate = as.numeric(input$annual_tax_rate),
      annual_ins_rate = as.numeric(input$annual_ins_rate),
      annual_income   = as.numeric(input$annual_income)
    )
  })

  # Summary cross-section for reference date
  summary_df = reactive({
    df     = filtered_long()
    params = afford_params()
    ref    = as.Date(input$ref_date)
    prepare_summary_data(df, ref, params)
  })

  # Reset defaults button
  observeEvent(input$reset_defaults, {
    updateSliderInput(session,  "annual_rate",     value = DEFAULT$annual_rate)
    updateSelectInput(session,  "term_years",      selected = DEFAULT$term_years)
    updateSliderInput(session,  "down_pct",        value = DEFAULT$down_pct)
    updateSliderInput(session,  "annual_tax_rate", value = DEFAULT$annual_tax_rate)
    updateSliderInput(session,  "annual_ins_rate", value = DEFAULT$annual_ins_rate)
    updateNumericInput(session, "annual_income",   value = DEFAULT$annual_income)
  })

  # --------------------------------------------------------------------------
  # KPI VALUE BOXES
  # --------------------------------------------------------------------------
  output$kpi_zip_codes = renderValueBox({
    n = dplyr::n_distinct(summary_df()$RegionName)
    valueBox(n, "ZIP Codes in View", icon = icon("map-marker"),
             color = "blue")
  })

  output$kpi_median_zhvi = renderValueBox({
    med = median(summary_df()$ZHVI, na.rm = TRUE)
    valueBox(dollar_fmt(med), "Median ZHVI", icon = icon("home"),
             color = "purple")
  })

  output$kpi_monthly_cost = renderValueBox({
    med = median(summary_df()$monthly_total_cost, na.rm = TRUE)
    valueBox(dollar_fmt(med), "Median Monthly Housing Cost",
             icon = icon("dollar-sign"), color = "orange")
  })

  output$kpi_afford_ratio = renderValueBox({
    med   = median(summary_df()$afford_ratio, na.rm = TRUE)
    color = if (is.na(med)) "gray" else if (med < 0.30) "green" else if (med <= 0.50) "yellow" else "red"
    valueBox(pct_fmt(med), "Median Affordability Ratio",
             icon = icon("percent"), color = color)
  })

  output$kpi_growth_1y = renderValueBox({
    med = median(summary_df()$growth_1y, na.rm = TRUE)
    color = if (is.na(med)) "gray" else if (med > 0) "green" else "red"
    valueBox(pct_fmt(med), "Median 1-Year Price Growth",
             icon = icon("arrow-trend-up"), color = color)
  })

  # --------------------------------------------------------------------------
  # LEAFLET MAP  (ZIP5 choropleth using ZCTA polygon boundaries from tigris)
  # --------------------------------------------------------------------------

  # Build leaflet map
  output$map_leaflet = renderLeaflet({
    df_snap = summary_df()

    color_var = input$map_color_var

    # Build colour palette
    if (color_var == "afford_ratio") {
      pal_domain = range(df_snap$afford_ratio, na.rm = TRUE)
      pal = colorNumeric(palette = c("#2ca02c", "#ff7f0e", "#d62728"),
                          domain  = pal_domain, na.color = "#aaa")
      color_vals  = df_snap$afford_ratio
      legend_title = "Affordability<br>Ratio"

    } else if (color_var == "ZHVI") {
      pal_domain = range(df_snap$ZHVI, na.rm = TRUE)
      pal = colorNumeric(palette = c("#3498db", "#f39c12", "#e74c3c"),
                          domain  = pal_domain, na.color = "#aaa")
      color_vals  = df_snap$ZHVI
      legend_title = "ZHVI ($)"

    } else {
      pal_domain = range(df_snap$growth_1y, na.rm = TRUE)
      pal = colorNumeric(palette = c("#e74c3c", "#ecf0f1", "#27ae60"),
                          domain  = pal_domain, na.color = "#aaa")
      color_vals  = df_snap$growth_1y
      legend_title = "1-Year<br>Growth"
    }

    # Build popup text (named by RegionName for easy lookup)
    popup_txt = with(df_snap, paste0(
      "<b>ZIP: ", RegionName, "</b><br>",
      "ZHVI: ", dollar_fmt(ZHVI), "<br>",
      "Monthly Cost: ", dollar_fmt(monthly_total_cost), "<br>",
      "Afford. Ratio: ", pct_fmt(afford_ratio), "<br>",
      "1-yr Growth: ",  pct_fmt(growth_1y), "<br>",
      "Status: <b>", afford_label, "</b>"
    ))
    names(popup_txt) = df_snap$RegionName

    # Attempt to get ZCTA polygon boundaries from tigris
    map_data = tryCatch({
      if (HAS_TIGRIS) {
        stl_zips = unique(df_snap$RegionName)
        zctas_mo = tigris::zctas(state = "MO", year = 2020, cb = TRUE)
        zctas_il = tigris::zctas(state = "IL", year = 2020, cb = TRUE)
        zctas    = rbind(zctas_mo, zctas_il)
        zctas    = zctas[zctas$ZCTA5CE20 %in% stl_zips, ]

        # Join ZHVI summary data into the sf object
        zctas = dplyr::left_join(zctas, df_snap, by = c("ZCTA5CE20" = "RegionName"))
        zctas
      } else {
        NULL
      }
    }, error = function(e) NULL)

    # Build base map centred on St. Louis
    m = leaflet() |>
      addTiles(urlTemplate = "https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png",
               attribution  = "© OpenStreetMap © CARTO") |>
      setView(lng = -90.1994, lat = 38.6270, zoom = 10)

    if (!is.null(map_data) && nrow(map_data) > 0) {
      fill_colors = pal(map_data[[color_var]])
      pop_txt     = popup_txt[map_data$ZCTA5CE20]

      m = m |>
        addPolygons(
          data        = map_data,
          fillColor   = fill_colors,
          fillOpacity = 0.7,
          color       = "#555",
          weight      = 0.8,
          popup       = pop_txt,
          highlight   = highlightOptions(
            weight      = 2,
            color       = "#222",
            fillOpacity = 0.9,
            bringToFront = TRUE
          ),
          label       = ~ZCTA5CE20
        ) |>
        addLegend("bottomright", pal = pal, values = color_vals,
                  title = legend_title, opacity = 0.8)
    } else {
      # Fallback: show text note on map
      m = m |>
        addControl(
          html = paste0(
            "<div style='background:white;padding:10px;border-radius:5px;",
            "font-size:12px;max-width:300px;'>",
            "<b>Map note:</b> Install the <code>tigris</code> and ",
            "<code>sf</code> packages to enable the ZIP code choropleth map. ",
            "All other dashboard tabs function without these packages.",
            "</div>"
          ),
          position = "topright"
        )
    }

    m
  })

  # --------------------------------------------------------------------------
  # AFFORDABILITY DONUT  (distribution of labels)
  # --------------------------------------------------------------------------
  output$afford_donut = renderPlotly({
    df = summary_df()
    counts = df |>
      count(afford_label) |>
      mutate(afford_label = as.character(afford_label))

    plot_ly(counts, labels = ~afford_label, values = ~n,
            type  = "pie",
            hole  = 0.45,
            marker = list(colors = unname(AFFORD_COLORS[counts$afford_label]))) |>
      layout(showlegend = TRUE,
             margin      = list(l=0, r=0, t=10, b=10),
             legend      = list(orientation = "h"))
  })

  # --------------------------------------------------------------------------
  # TIME SERIES: ZHVI
  # --------------------------------------------------------------------------
  output$ts_plot = renderPlotly({
    df = filtered_long()
    validate(need(nrow(df) > 0, "No data for selected regions."))

    # Limit to top-10 regions by latest ZHVI if too many selected
    latest = df |> filter(Date == max(Date)) |> arrange(desc(ZHVI))
    if (dplyr::n_distinct(df$RegionName) > 15) {
      top_regions = head(latest$RegionName, 15)
      df = df[df$RegionName %in% top_regions, ]
      note = " (top 15 by current ZHVI shown)"
    } else {
      note = ""
    }

    p = df |>
      plot_ly(x = ~Date, y = ~ZHVI, color = ~RegionName,
              type = "scatter", mode = "lines",
              hovertemplate = paste0("<b>%{fullData.name}</b><br>",
                                     "Date: %{x|%b %Y}<br>",
                                     "ZHVI: $%{y:,.0f}<extra></extra>")) |>
      layout(
        title  = list(text = paste0("ZHVI Over Time — St. Louis Metro (ZIP Codes)", note),
                      font = list(size = 14)),
        xaxis  = list(title = ""),
        yaxis  = list(title = "Zillow Home Value Index ($)",
                      tickformat = "$,.0f"),
        legend = list(orientation = "v"),
        hovermode = "x unified"
      )
    p
  })

  # TIME SERIES: Affordability Ratio
  output$ts_afford_plot = renderPlotly({
    df     = filtered_long()
    params = afford_params()
    validate(need(nrow(df) > 0, "No data for selected regions."))

    # Compute monthly affordability for every date
    df = df |>
      mutate(
        monthly_cost  = mapply(function(z)
          total_monthly_housing_cost(z, params$down_pct,
                                      params$annual_rate, as.numeric(params$term_years),
                                      params$annual_tax_rate, params$annual_ins_rate)["total"],
          ZHVI),
        afford_ratio  = monthly_cost / (params$annual_income / 12)
      )

    # Limit to top-15 to avoid clutter
    if (dplyr::n_distinct(df$RegionName) > 15) {
      latest_top = df |> filter(Date == max(Date)) |> arrange(desc(ZHVI))
      df = df[df$RegionName %in% head(latest_top$RegionName, 15), ]
    }

    threshold_line = list(
      type = "line", y0 = 0.30, y1 = 0.30,
      x0   = min(df$Date), x1 = max(df$Date),
      line = list(color = "red", dash = "dash", width = 1.5)
    )

    p = df |>
      plot_ly(x = ~Date, y = ~afford_ratio, color = ~RegionName,
              type = "scatter", mode = "lines",
              hovertemplate = paste0("<b>%{fullData.name}</b><br>",
                                     "Date: %{x|%b %Y}<br>",
                                     "Ratio: %{y:.1%}<extra></extra>")) |>
      layout(
        title  = list(text = "Affordability Ratio Over Time (red line = 30 % threshold)",
                      font = list(size = 14)),
        xaxis  = list(title = ""),
        yaxis  = list(title = "Monthly Cost / Monthly Income",
                      tickformat = ".0%"),
        shapes    = list(threshold_line),
        hovermode = "x unified"
      )
    p
  })

  # --------------------------------------------------------------------------
  # RANKINGS: Most / Least Affordable Bar Charts
  # --------------------------------------------------------------------------
  output$bar_affordable = renderPlotly({
    df = summary_df() |> filter(!is.na(afford_ratio)) |>
      arrange(afford_ratio) |> head(15)

    plot_ly(df, y = ~reorder(RegionName, -afford_ratio),
            x = ~afford_ratio, type = "bar",
            orientation = "h",
            marker      = list(color = "#2ca02c"),
            hovertemplate = paste0("<b>%{y}</b><br>",
                                    "Ratio: %{x:.1%}<br>",
                                    "ZHVI: $%{customdata:,.0f}<extra></extra>"),
            customdata  = ~ZHVI) |>
      layout(
        xaxis = list(title = "Affordability Ratio", tickformat = ".0%"),
        yaxis = list(title = ""),
        margin = list(l = 150)
      )
  })

  output$bar_unaffordable = renderPlotly({
    df = summary_df() |> filter(!is.na(afford_ratio)) |>
      arrange(desc(afford_ratio)) |> head(15)

    plot_ly(df, y = ~reorder(RegionName, afford_ratio),
            x = ~afford_ratio, type = "bar",
            orientation = "h",
            marker      = list(color = "#d62728"),
            hovertemplate = paste0("<b>%{y}</b><br>",
                                    "Ratio: %{x:.1%}<br>",
                                    "ZHVI: $%{customdata:,.0f}<extra></extra>"),
            customdata  = ~ZHVI) |>
      layout(
        xaxis = list(title = "Affordability Ratio", tickformat = ".0%"),
        yaxis = list(title = ""),
        margin = list(l = 150)
      )
  })

  # --------------------------------------------------------------------------
  # SCATTER PLOTS
  # --------------------------------------------------------------------------
  output$scatter_price_afford = renderPlotly({
    df = summary_df() |> filter(!is.na(afford_ratio), !is.na(ZHVI))

    plot_ly(df, x = ~ZHVI, y = ~afford_ratio,
            type  = "scatter", mode = "markers",
            color = ~afford_label,
            colors = AFFORD_COLORS,
            text  = ~RegionName,
            hovertemplate = paste0("<b>%{text}</b><br>",
                                    "ZHVI: $%{x:,.0f}<br>",
                                    "Ratio: %{y:.1%}<extra></extra>"),
            marker = list(size = 8, opacity = 0.75)) |>
      layout(
        xaxis = list(title = "ZHVI (Home Price)", tickformat = "$,.0f"),
        yaxis = list(title = "Affordability Ratio", tickformat = ".0%"),
        shapes = list(list(type = "line", y0 = 0.30, y1 = 0.30,
                            x0 = min(df$ZHVI), x1 = max(df$ZHVI),
                            line = list(color = "red", dash = "dash")))
      )
  })

  output$scatter_growth_afford = renderPlotly({
    df = summary_df() |> filter(!is.na(afford_ratio), !is.na(growth_1y))

    plot_ly(df, x = ~growth_1y, y = ~afford_ratio,
            type  = "scatter", mode = "markers",
            color = ~afford_label,
            colors = AFFORD_COLORS,
            text  = ~RegionName,
            hovertemplate = paste0("<b>%{text}</b><br>",
                                    "1yr Growth: %{x:.1%}<br>",
                                    "Ratio: %{y:.1%}<extra></extra>"),
            marker = list(size = 8, opacity = 0.75)) |>
      layout(
        xaxis = list(title = "1-Year Price Growth", tickformat = ".1%"),
        yaxis = list(title = "Affordability Ratio", tickformat = ".0%"),
        shapes = list(list(type = "line", y0 = 0.30, y1 = 0.30,
                            x0 = min(df$growth_1y, na.rm=TRUE),
                            x1 = max(df$growth_1y, na.rm=TRUE),
                            line = list(color = "red", dash = "dash")))
      )
  })

  # --------------------------------------------------------------------------
  # DATA TABLE
  # --------------------------------------------------------------------------
  output$summary_table = renderDT({
    df = summary_df() |>
      transmute(
        `ZIP Code`      = RegionName,
        State           = StateName,
        `ZHVI ($)`      = round(ZHVI, 0),
        `Monthly Mort.` = round(monthly_mortgage, 0),
        `Monthly Tax`   = round(monthly_tax, 0),
        `Monthly Ins.`  = round(monthly_insurance, 0),
        `Total Monthly` = round(monthly_total_cost, 0),
        `Afford. Ratio` = round(afford_ratio * 100, 1),
        Status          = as.character(afford_label),
        `1-Yr Growth %` = round(growth_1y * 100, 1),
        `3-Yr Growth %` = round(growth_3y * 100, 1)
      )

    datatable(df,
              filter    = "top",
              rownames  = FALSE,
              options   = list(pageLength = 20, scrollX = TRUE),
              class     = "compact stripe hover") |>
      formatCurrency(c("ZHVI ($)", "Monthly Mort.", "Monthly Tax",
                        "Monthly Ins.", "Total Monthly"),
                      currency = "$", digits = 0) |>
      formatStyle("Afford. Ratio",
                  background = styleInterval(
                    c(30, 50),
                    c("#d5f5e3", "#fdebd0", "#fadbd8")
                  )) |>
      formatStyle("Status",
                  color = styleEqual(
                    c("Affordable", "Moderately Burdened", "Severely Burdened"),
                    c("#1a7a3a",    "#c0690c",              "#a01010")
                  ))
  })

  # --------------------------------------------------------------------------
  # SCENARIO ANALYSIS
  # --------------------------------------------------------------------------

  # Violin / jitter plot of ratio distribution
  output$scenario_violin = renderPlotly({
    df = summary_df() |> filter(!is.na(afford_ratio))

    # Also compute baseline (DEFAULT params)
    baseline_params = DEFAULT
    baseline_df     = prepare_summary_data(filtered_long(),
                                            as.Date(input$ref_date),
                                            baseline_params)

    combined = bind_rows(
      df |> mutate(scenario = "Current Inputs"),
      baseline_df |> mutate(scenario = "Default Baseline")
    )

    plot_ly(combined, y = ~afford_ratio, x = ~scenario, color = ~scenario,
            type = "violin", box = list(visible = TRUE),
            points = "all", jitter = 0.3, pointpos = 0,
            hovertemplate = "%{y:.1%}<extra></extra>") |>
      layout(
        xaxis = list(title = ""),
        yaxis = list(title = "Affordability Ratio", tickformat = ".0%"),
        shapes = list(list(type = "line", y0 = 0.30, y1 = 0.30,
                            x0 = -0.5, x1 = 1.5,
                            line = list(color = "red", dash = "dash"))),
        showlegend = FALSE
      )
  })

  # Waterfall: cost components for median ZIP code
  output$scenario_waterfall = renderPlotly({
    params = afford_params()
    df     = summary_df()

    med_zhvi      = median(df$ZHVI, na.rm = TRUE)
    costs         = total_monthly_housing_cost(
      zhvi            = med_zhvi,
      down_pct        = params$down_pct,
      annual_rate     = params$annual_rate,
      term_years      = as.numeric(params$term_years),
      annual_tax_rate = params$annual_tax_rate,
      annual_ins_rate = params$annual_ins_rate
    )
    monthly_income = params$annual_income / 12

    components = data.frame(
      label  = c("Mortgage P&I", "Property Tax", "Insurance",
                  "Total Housing", "30% Income"),
      value  = c(costs["mortgage"], costs["tax"], costs["insurance"],
                  costs["total"],   monthly_income * 0.30),
      color  = c("#3498db", "#e67e22", "#9b59b6", "#2c3e50", "#e74c3c")
    )

    plot_ly(components, x = ~label, y = ~value,
            type   = "bar",
            marker = list(color = ~color),
            hovertemplate = "<b>%{x}</b><br>$%{y:,.0f}/mo<extra></extra>") |>
      layout(
        title = list(
          text = paste0("Median ZHVI: ", dollar_fmt(med_zhvi)),
          font = list(size = 13)
        ),
        xaxis = list(title = ""),
        yaxis = list(title = "$/month", tickformat = "$,.0f")
      )
  })

  # Sensitivity: affordability ratio vs. rate (range 2–14 %)
  output$scenario_rate_sensitivity = renderPlotly({
    df     = summary_df()
    params = afford_params()
    rates  = seq(2, 14, by = 0.25)

    med_zhvi = median(df$ZHVI, na.rm = TRUE)
    q25_zhvi = quantile(df$ZHVI, 0.25, na.rm = TRUE)
    q75_zhvi = quantile(df$ZHVI, 0.75, na.rm = TRUE)

    calc_ratio = function(price, rate) {
      costs = total_monthly_housing_cost(
        zhvi            = price,
        down_pct        = params$down_pct,
        annual_rate     = rate,
        term_years      = as.numeric(params$term_years),
        annual_tax_rate = params$annual_tax_rate,
        annual_ins_rate = params$annual_ins_rate
      )
      costs["total"] / (params$annual_income / 12)
    }

    sens_df = data.frame(
      rate       = rates,
      ratio_med  = sapply(rates, function(r) calc_ratio(med_zhvi, r)),
      ratio_q25  = sapply(rates, function(r) calc_ratio(q25_zhvi, r)),
      ratio_q75  = sapply(rates, function(r) calc_ratio(q75_zhvi, r))
    )

    plot_ly(sens_df) |>
      add_lines(x = ~rate, y = ~ratio_q25, name = "25th Pctile ZHVI",
                line = list(color = "#2ca02c", dash = "dot")) |>
      add_lines(x = ~rate, y = ~ratio_med,  name = "Median ZHVI",
                line = list(color = "#1f77b4", width = 2.5)) |>
      add_lines(x = ~rate, y = ~ratio_q75, name = "75th Pctile ZHVI",
                line = list(color = "#d62728", dash = "dot")) |>
      add_lines(x = ~rate, y = rep(0.30, length(rates)),
                name = "30% Threshold",
                line = list(color = "black", dash = "dash", width = 1)) |>
      add_lines(x = ~rate, y = rep(0.50, length(rates)),
                name = "50% Threshold",
                line = list(color = "black", dash = "longdash", width = 1)) |>
      layout(
        title  = list(text = "Affordability Ratio vs. Mortgage Rate (income held constant)",
                       font = list(size = 14)),
        xaxis  = list(title = "Annual Mortgage Rate (%)", ticksuffix = "%"),
        yaxis  = list(title = "Monthly Cost / Monthly Income", tickformat = ".0%"),
        hovermode = "x unified"
      )
  })

}  # end server


# =============================================================================
# Run the application
# =============================================================================
shinyApp(ui = ui, server = server)
