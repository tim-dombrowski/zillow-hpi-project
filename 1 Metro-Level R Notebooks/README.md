# Metro-Level ZHVI Data

This directory contains some R Notebooks for exploring the Zillow Home Value Index (ZHVI) data at the metro level. The ZHVI data is available at [Zillow Research Data](https://www.zillow.com/research/data/), and the metro-level data for the ZHVI All Homes (Single-Family Residential, Condo/Co-op) Time Series, Smoothed, Seasonally Adjusted($) series is the default selection on the site. This default, metro-level option is also the only geography level that includes a national, country-level ZHVI. Thus, the importzhvi.Rmd file in this directory will have a couple deviations from the others to split the single national time series from the panel of data for the metro areas. 

## importzhvi.Rmd

This R Notebook simply focuses on downloading and cleaning the ZHVI data. It will save two copies of the downloaded datasets: one as a .csv file with the raw data and the other as a cleaned .fst file, which uses the [fst package](https://cran.r-project.org/package=fst). For this particular geography level, there are three data files saved by this notebook:

* ../Data/Raw/ZHVI_raw_msa+country.csv
* ../Data/Clean/ZHVI_clean_country.fst
* ../Data/Clean/ZHVI_clean_msa.fst

*Note: in the paths above, the .. at the start navigates to the parent directory of this notebook's working directory. This notebook will create a folder in the repo's root that will store the ZHVI data files. The repo's .gitignore file tells git not to sync the data files, so you need to build these yourself.*

## zhvicomps.Rmd

This R Notebook will start with the cleaned ZHVI data and explore some analysis/comparisons between the metro areas. It will also generate a subdirectory of this folder "Figures/", which will store pdf files for the graphics generated in the analysis.