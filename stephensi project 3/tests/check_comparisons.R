# Missing comparison files must fail explicitly.
source('R/analysis.R')
source('R/checks.R')
run_comparison_checks <- function() {
  root <- normalizePath(getwd())
  out <- tempfile('stephensi_comparison_');dir.create(out)
  on.exit(unlink(out,recursive=TRUE),add=TRUE)
  error <- tryCatch({compare_reference(out,root,full=FALSE);'NO_ERROR'},error=conditionMessage)
  stopifnot(grepl('Missing calculated output',error,fixed=TRUE))
  error <- tryCatch({compare_reference(out,out,full=FALSE);'NO_ERROR'},error=conditionMessage)
  stopifnot(grepl('Missing numerical comparison target',error,fixed=TRUE))
  cat('Comparison completeness safeguards passed.\n')
}
run_comparison_checks()
