# Summarise a completed run and its verification records.
args <- commandArgs(trailingOnly=TRUE)
out <- if(length(args))args[1] else 'results'
m <- readRDS(file.path(out,'run_manifest.rds'))
stopifnot(identical(m$status,'completed'))
files <- c('verification.csv','output_integrity.csv','reference_comparison.csv',
           'reported_value_comparison.csv','population_balance_checks.csv')
labels <- c('Numerical model checks','Output accounting checks','Full-precision output comparisons',
            'Manuscript reporting-precision comparisons','Whole-trajectory population balances')
records <- lapply(files,function(name)read.csv(file.path(out,name),stringsAsFactors=FALSE))
stopifnot(all(vapply(records,function(x)all(x$passed),FALSE)))
lines <- c('# Computational verification', '',
  paste('Execution status:',m$status),paste('Analysis mode:',m$mode),paste('R:',m$R),
  paste('Workers:',m$workers),paste('Started:',m$started),paste('Finished:',m$finished),
  paste('Elapsed minutes:',round(m$elapsed_seconds/60,2)), '',
  '| Verification group | Passed | Total |','| --- | ---: | ---: |')
for(i in seq_along(records))lines <- c(lines,paste0('| ',labels[i],' | ',
  sum(records[[i]]$passed),' | ',nrow(records[[i]]),' |'))
d <- read.csv(file.path(out,'scenarios_complete.csv'),stringsAsFactors=FALSE)
lines <- c(lines,'',paste('Model variants:',length(unique(d$model))),
           paste('Scenario summary rows:',nrow(d)),
           paste('Largest scaled numerical comparison discrepancy:',
                 format(max(records[[3]]$max_scaled_difference),digits=8)),
           paste('Largest relative population balance residual:',
                 format(max(abs(records[[5]]$relative_residual)),digits=8)), '',
           '## Reference comparisons','',
           '| Comparison | Child clinical episodes averted | All-age US$ per DALY averted |',
           '| --- | ---: | ---: |')
co <- read.csv(file.path(out,'contrasts_complete.csv'),stringsAsFactors=FALSE)
for(pair in c('B-A','D-C','E-C','F-E')) {
  x <- subset(co,model=='reference' & region=='both' & contrast==pair)
  lines <- c(lines,sprintf('| %s | %.6f | %.6f |',pair,
    x$clinical_averted[x$age=='6-59'],x$icer[x$age=='all']))
}
lines <- c(lines,'','## Interpretation','',
 'These checks assess numerical consistency and agreement with the reported calculations. Independent clinical predictive validation has not been established. Economic values retain the historical 2020 US-dollar convention. Assumptions and input transfers remain applicable.', '',
 'Source and input fingerprints are recorded in source_input_checksums.csv. Detailed discrepancies and tolerances are retained in the individual verification tables.')
writeLines(lines,file.path(out,'verification_summary.md'))
cat('Computational verification summary written.\n')
