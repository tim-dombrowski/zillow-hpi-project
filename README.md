# Zillow HPI Project

### Overview

This repository will focus on exploring the Zillow Home Value Index (ZHVI) data to analyze patterns in residential real estate values across various geography levels. The ZHVI measure is one example of a house price index (HPI) that tracks relative price changes in real estate values over time. This data is available at [Zillow Research Data](https://www.zillow.com/research/data/) and can be accessed at various geography levels. Each of the R Notebook folders focuses on a different geography level and can be used to examine spatial patterns in house prices across different regions. Additionally, we'll explore some tools for generating maps from the ZHVI data.

### Additional Context Around the Data

On the data website linked above, Zillow lists several data products that they offer. Within the ZHVI section, there are two dropdown boxes to select Data Type and Geography. 

* There are several options for Data Type that allow some filtering by property types, but we'll stick with the default option: ZHVI All Homes (Single-Family Residential, Condo/Co-op) Time Series, Smoothed, Seasonally Adjusted($).
* The Geography dropdown box allows for selection of various geographies, such as country (US), state, county, metro (MSA), city, ZIP code, and neighborhood. Each of these will be explored throughout the various R Notebooks in the repository.

For each pair of the selections, Zillow provides a download of monthly ZHVI values for each of the geographic regions across the entire U.S. The importzhvi.Rmd codes in the R Notebook folders will manage the data download/import and cleaning process. Then, the zhvicomps.Rmd files are work-in-progress codes with the goal of generating some basic visualizations and analysis of the data.

**Important Note for Running the R Notebooks: Be sure to start with the Metro-level import code before attempting to run the zhvicomps for other geographies. Those codes utilize the national US-level series, which is bundled with the Metro-level data.**

In regard to the topic of HPIs and housing returns, there are many different ways to create HPIs from real estate transaction data. For example, a simple approach is to just use the median home sale in a particular region over a particular time period. However, a more advanced approach would be the use of a "repeat sales" methodology where housing returns are estimated from properties that sell multiple times over the data lifespan. In other words, properties with only one sale do not have sufficient information to tell us anything about how prices are changing over time. 

Some HPIs have an arbitrary starting value (typically normalized to equal 100 on a particular date), and then the dynamics show how values appreciate (or depreciate) as time moves on. The HPIs published by the Federal Housing Finance Agency ([FHFA HPIS](https://www.fhfa.gov/DataTools/Downloads/Pages/House-Price-Index-Datasets.aspx)) are formatted in that way. However, since the ZHVI more precisely aims to capture the "typical" home value for a region during each time period, the units have a bit more interpretability. Regardless, in either case, it is more statistically appropriate to make comparisons across different regions using housing returns (a.k.a. growth rates of HPIs or their first derivative).

In regard to some of the smaller geography levels (ZIP code and neighborhood), the data work can take some time to clean and analyze. If you run into any computational limitations, you can either stick to just the state/metro level analysis or filter the data down to a subset of regions. I've included code to time the longer steps so that you can get a sense of the runtime for each of the geographies.

### Repository Structure

The data work for this project is contained in the R Notebook directories of this repository. On GitHub, the webpages will display the README.md files, which contain some additional details about the R Notebook files in the folder. If you wish to explore the source codes locally, then you can open the Rmd files in RStudio and execute the code chunks to replicate the data work. 

Beyond the R Notebook directories, once you run the import codes, those will create a Data folder in the repo that will contain the raw and cleaned data files. The data files are not included in the repository due to their size (see the .gitignore file), but you can generate them by running the import codes.

The Scripts folder contains an R script that will run the import codes for each of the geography levels. Running this script let's you quickly generate local copies of each of the ZHVI series for the various geographies.