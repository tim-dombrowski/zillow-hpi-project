# Import, Clean, and Save All Geography Levels of ZHVI Data
#
# importallgeographies.R

# Install the knitr package if you haven't already
if (!requireNamespace("knitr", quietly = TRUE)) {
  install.packages("knitr")
}

print(getwd())
dir(getwd())


# Specify the paths to your .Rmd files
rmd_files = c(
  "1 Metro-Level R Notebooks/importzhvi.Rmd",
  "2 State-Level R Notebooks/importzhvi.Rmd",
  "3 County-Level R Notebooks/importzhvi.Rmd",
  "4 City-Level R Notebooks/importzhvi.Rmd",
  "5 ZIP-Level R Notebooks/importzhvi.Rmd",
  "6 Neighborhood-Level R Notebooks/importzhvi.Rmd"
)

# Loop through the .Rmd files and render them
for (rmd_file in rmd_files) {
  t=proc.time()
  rmarkdown::render(rmd_file)
  T=proc.time()-t
  print(paste("Notebook:", rmd_file, "rendered in", round(T[3],2), "seconds."))
}