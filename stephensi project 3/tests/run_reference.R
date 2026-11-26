# Run from the project directory: Rscript tests/run_reference.R
options(stephensi.autorun=FALSE)
source('run_analysis.R')
run_analysis(mode='reference',workers=1)
