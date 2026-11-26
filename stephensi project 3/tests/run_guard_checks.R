# Execution safeguards. Run from the project directory:
# Rscript tests/run_guard_checks.R
options(stephensi.autorun=FALSE)
source('run_analysis.R')
check_guards<-function() {
  root<-normalizePath(getwd());out<-tempfile('stephensi_guard_')
  dir.create(out);on.exit(unlink(out,recursive=TRUE),add=TRUE)
  saveRDS(list(source_input_md5='different-input'),file.path(out,'run_manifest.rds'))
  message1<-tryCatch({run_analysis(root,mode='reference',out=out);'NO_ERROR'},error=conditionMessage)
  stopifnot(grepl('Output directory is not empty',message1,fixed=TRUE))
  message2<-tryCatch({run_analysis(root,mode='reference',out=out,resume=TRUE);'NO_ERROR'},error=conditionMessage)
  stopifnot(grepl('Code or inputs changed',message2,fixed=TRUE))
  paths<-sort(c(file.path(root,'run_analysis.R'),
    list.files(file.path(root,'R'),pattern='[.]R$',full.names=TRUE),
    list.files(file.path(root,'data'),full.names=TRUE),
    list.files(file.path(root,'verification_targets'),full.names=TRUE)))
  hashes<-tools::md5sum(paths);names(hashes)<-substring(names(hashes),nchar(root)+2L)
  saveRDS(list(source_input_md5=hashes,mode='full'),file.path(out,'run_manifest.rds'))
  message3<-tryCatch({run_analysis(root,mode='reference',out=out,resume=TRUE);'NO_ERROR'},error=conditionMessage)
  stopifnot(grepl('Run mode changed',message3,fixed=TRUE))
  cat('Output and resumption safeguards passed.\n')
}
check_guards()
