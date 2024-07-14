# Zillow HPI Project

### Overview

This repository will focus on exploring the Zillow Home Value Index (ZHVI) data to analyze patterns in residential real estate values across various geographies. The ZHVI measure is one example of a house price index (HPI), which tracks relative price changes in real estate values over time. The data is available at [Zillow Research Data](https://www.zillow.com/research/data/) and can be accessed at various geography levels. Each of the R Notebook folders focuses on a different geography level, and can be used to examine spatial patterns across different regions. Additionally, we'll explore some tools for generating maps from the ZHVI data.

### Additional Context Around the Data

On the data website linked above, Zillow lists several data products that they offer. Within the ZHVI section, there are two dropdown boxes to select Data Type and Geography. 

* There are several options for Data Type that allow some filtering by property types, but we'll stick with the default option: ZHVI All Homes (Single-Family Residential, Condo/Co-op) Time Series, Smoothed, Seasonally Adjusted($).
* The Geography dropdown box allows for selection of various geographies, such as country (US), state, county, metro (MSA), city, ZIP code, and neighborhood. Each of these will be explored throughout the various R Notebooks in the repository.

For each pair of the selections, Zillow provides a monthly time series of ZHVI values for each of the geographic regions across the entire U.S. The codes in the R Notebooks will manage the data import and cleaning process, and then provide some basic visualizations and analysis of the data.

**Important Note for Running the R Notebooks: Start with the Metro-level analysis. This is because the country-level data is only available through this table. Then after saving a cleaned version of the country-level ZHVI, it will be available for use in the other R Notebooks.**

In regard to the topic of HPIs and housing returns, there are many different ways to create HPIs from real estate transaction data. For example, a simple approach is to just use the median home sale in a particular region over a particular time period. However, a more advanced approach would be the use of a "repeat sales" methodology where housing returns are estimated from properties that sell multiple times over the data lifespan. In other words, properties with only one sale do not have sufficient information to tell us anything about how prices are changing over time. 

Some HPIs have an arbitrary starting value (typically normalized to equal 100 on a particular date), and then the dynamics show how values appreciate (or depreciate) as time moves on. The HPIs published by the Federal Housing Finance Agency ([FHFA HPIS](https://www.fhfa.gov/DataTools/Downloads/Pages/House-Price-Index-Datasets.aspx)) are formatted in that way. However, since the ZHVI more precisely aims to capture the "typical" home value for a region during each time period, the units have a bit more interpretability. Regardless, in either case, it is more statistically appropriate to make comparisons across different regions using housing returns (growth rates of HPIs, or also, their first derivative).

In regard to some of the smaller geography levels (ZIP code and neighborhood), the data work can take a long time to clean and analyze. If you run into any computational limitations, you can either stick to just the state/metro level analysis or filter the data down to a subset of regions. I've included code to time the longer steps so that you can get a sense of the runtime for each of the geographies.

### Repository Structure

The data work for this project is contained in the R Notebook directories of this repository. On GitHub, the webpages should display the README.md files, which contain the compiled output of the R Notebooks. If you wish to explore the source codes locally, then you can open the zhvicomps.Rmd files in RStudio and execute the code chunks to replicate the data work. Note the `output: html_notebook` line in the header of that file, which indicates that the R Markdown document is an R Notebook. 

After exploring the R Notebooks and making any desired changes, you can then create a copy that will appear on GitHub. To do this, save a copy of the R Notebook and name it README.Rmd. Then, change the header line to `output: github_document`, which will switch the file from being an R Notebook to an R Markdown file that will compile into a generic [Markdown](https://www.markdownguide.org/) file (.md). This format (along with the README name) will automatically be recognized by GitHub and displayed in-browser. This will also replace the Preview button with an option to Knit the Markdown file. This knitting process will re-run all the code chunks and generate a new README.md file inside of the R Notebook folder, which will display on GitHub.
