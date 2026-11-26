# Whole-trajectory human population balance, using saved full states.
# Run from the project directory: Rscript tests/check_state_balance.R
source('R/model.R')
args <- commandArgs(trailingOnly=TRUE)
out <- if(length(args))args[1] else 'results'
inputs <- load_inputs(getwd());f <- inputs$f
paths <- list.files(file.path(out,'states'),pattern='^final_.*[.]rds$',full.names=TRUE)
stopifnot(length(paths)>0)
rows <- lapply(paths,function(path) {
  name <- basename(path)
  tag <- sub('^final_(.*)_[A-F][.]rds$','\\1',name)
  sid <- sub('^final_.*_([A-F])[.]rds$','\\1',name)
  start <- readRDS(file.path(out,paste0('baseline_',tag,'.rds')))$state
  y <- readRDS(path);x <- unpack(y)
  initial_population <- sum(start[seq_len(NH)])
  final_population <- sum(x$h)
  birth_rate <- if(tag=='zero_natural_growth')f$MU else f$BIRTH
  expected <- initial_population+(birth_rate-f$MU)*DAYS_YEAR*sum(x$o[10,,])-sum(x$o[4,,])
  relative_residual <- (final_population-expected)/initial_population
  data.frame(model=tag,scenario=sid,initial_population=initial_population,
             final_population=final_population,balance_expected=expected,
             relative_residual=relative_residual,tolerance=1e-9,
             passed=is.finite(relative_residual)&&abs(relative_residual)<=1e-9)
})
ans <- do.call(rbind,rows)
write.csv(ans,file.path(out,'population_balance_checks.csv'),row.names=FALSE)
stopifnot(all(ans$passed))
cat('Whole-trajectory population balance passed for ',nrow(ans),' saved states.\n',sep='')
