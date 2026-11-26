# Check a completed analysis without repeating the differential-equation runs.
# Rscript tests/run_all.R
# Rscript tests/run_all.R runs/<run-directory>
run_all_checks <- function() {
  old <- options(stephensi.autorun=FALSE)
  on.exit(options(old),add=TRUE)
  files <- c('run_analysis.R',list.files('R',pattern='[.]R$',full.names=TRUE),
             list.files('tests',pattern='[.]R$',full.names=TRUE))
  invisible(lapply(files,parse))
  scripts <- c('input_audit.R','run_guard_checks.R','check_comparisons.R',
               'check_results.R','check_state_balance.R','summarise_run.R')
  for(script in scripts)source(file.path('tests',script),local=.GlobalEnv)
  cat('All completed-analysis checks passed.\n')
}
run_all_checks()
