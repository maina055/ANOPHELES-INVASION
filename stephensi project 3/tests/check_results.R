# Check completed calculations without running the transmission model again.
# Run from the project directory: Rscript tests/check_results.R
source('R/model.R')
source('R/analysis.R')
source('R/checks.R')
source('R/reporting.R')
args <- commandArgs(trailingOnly=TRUE)
out <- if(length(args))args[1] else 'results'
stopifnot(file.exists(file.path(out,'run_manifest.rds')))
manifest <- readRDS(file.path(out,'run_manifest.rds'))
stopifnot(identical(manifest$status,'completed'))
full <- identical(manifest$mode,'full')
verify_output_integrity(out,full=full)
compare_reference(out,getwd(),full=full)
compare_reported_values(out,getwd(),full=full)
checks <- read.csv(file.path(out,'verification.csv'))
stopifnot(nrow(checks)==78L,all(checks$passed),all(is.finite(checks$value)),
          all(abs(checks$value)<=checks$tolerance))
paths <- c('run_analysis.R',list.files('R',pattern='[.]R$',full.names=TRUE),
           list.files('data',full.names=TRUE),list.files('verification_targets',full.names=TRUE))
current <- tools::md5sum(sort(paths))
stopifnot(identical(current,manifest$source_input_md5))
cat('Completed-run checks passed.\n')
