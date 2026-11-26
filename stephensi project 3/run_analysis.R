#!/usr/bin/env Rscript
# Anopheles stephensi vaccination and vector-control scenario analysis.
# Run from the extracted project directory in R or RStudio:
#   source('run_analysis.R')
# Command line:
#   Rscript run_analysis.R --mode full --workers 2
# No contributed R packages or external software are required.

run_analysis <- function(root=getwd(),mode='full',workers=1L,out=NULL,
                         resume=FALSE,compare=TRUE) {
  root<-normalizePath(root,mustWork=TRUE)
  if(!mode%in%c('full','reference'))stop('mode must be full or reference')
  workers<-as.integer(workers)
  if(length(workers)!=1L||is.na(workers)||workers<1L)stop('workers must be a positive integer')
  for(name in c('model','analysis','checks','reporting','figures'))
    source(file.path(root,'R',paste0(name,'.R')),local=.GlobalEnv)
  compiler::enableJIT(3L)
  if(is.null(out))out<-file.path(root,'runs',paste0(format(Sys.time(),'%Y%m%d_%H%M%S'),'-',Sys.getpid()))
  dir.create(out,recursive=TRUE,showWarnings=FALSE);out<-normalizePath(out,mustWork=TRUE)
  paths<-sort(c(file.path(root,'run_analysis.R'),
                 list.files(file.path(root,'R'),pattern='[.]R$',full.names=TRUE),
                 list.files(file.path(root,'data'),full.names=TRUE),
                 list.files(file.path(root,'verification_targets'),full.names=TRUE)))
  hashes<-tools::md5sum(paths);names(hashes)<-substring(names(hashes),nchar(root)+2L)
  manifest_path<-file.path(out,'run_manifest.rds')
  if(length(list.files(out,all.files=FALSE))) {
    if(!resume)stop('Output directory is not empty. Choose a new directory or set resume=TRUE.')
    if(!file.exists(manifest_path))stop('Cannot resume without a run manifest.')
    previous<-readRDS(manifest_path)
    if(!identical(previous$source_input_md5,hashes))stop('Code or inputs changed. Start a new run.')
    if(!identical(previous$mode,mode))stop('Run mode changed. Start a new output directory.')
  }
  started<-Sys.time()
  manifest<-list(status='running',mode=mode,workers=workers,started=as.character(started),
                 R=R.version.string,source_input_md5=hashes)
  write_manifest<-function(status,error=NULL) {
    manifest$status<-status;manifest$finished<-as.character(Sys.time())
    manifest$elapsed_seconds<-as.numeric(difftime(Sys.time(),started,units='secs'))
    if(!is.null(error))manifest$error<-error
    saveRDS(manifest,manifest_path)
    writeLines(c(paste('Status:',status),paste('Mode:',mode),paste('R:',R.version.string),
      paste('Started:',manifest$started),paste('Finished:',manifest$finished),
      paste('Elapsed seconds:',round(manifest$elapsed_seconds,2)),
      if(!is.null(error))paste('Error:',error)),file.path(out,'run_status.txt'))
  }
  write_manifest('running')
  write.csv(data.frame(file=names(hashes),md5=unname(hashes)),file.path(out,'source_input_checksums.csv'),row.names=FALSE)
  capture.output(sessionInfo(),file=file.path(out,'sessionInfo.txt'))
  tryCatch({
    input<-load_inputs(root);f<-input$f;cfg<-input$cfg
    message('Reference calibration and intervention scenarios')
    run_variant('reference',cfg,f,out)
    b<-load_reference(out)
    if(mode=='full') {
      message('Structural sensitivity analyses')
      fun<-function(tag)structural_job(tag,f,cfg,out)
      map_jobs(as.list(STRUCTURAL_TAGS),fun,workers,root)
      message('Additional sensitivity analyses')
      fun<-function(tag)extra_job(tag,f,cfg,out)
      extra<-map_jobs(as.list(EXTRA_TAGS),fun,workers,root)
      write_result(do.call(rbind,extra),'extra_sensitivity',out)
      if(!file.exists(file.path(out,'density_curve.csv'))) {
        message('Invader-density curve')
        fun<-function(den)density_job(den,b,f,out)
        rows<-map_jobs(as.list(round(seq(.2,1.2,by=.05),2)),fun,workers,root)
        write_result(do.call(rbind,rows),'density_curve',out)
      }
      if(!file.exists(file.path(out,'control_boundaries.csv')))control_boundaries(b,f,out)
      if(!file.exists(file.path(out,'economic_scenarios.csv')))economic_analyses(b,f,out)
      message('Prevalence matching, lake bounds and transported benchmark')
      benchmark_analyses(b,f,cfg,out,root,workers)
      message('Global sensitivity analysis: 128 design points and 500 bootstrap resamples')
      global_analysis(b,f,out,root,workers)
    }
    aggregate_results(out)
    message('Numerical verification')
    verify_model(b,f,cfg,out,root)
    verify_output_integrity(out,full=mode=='full')
    if(compare)compare_reference(out,root,full=mode=='full')
    export_manuscript_tables(out,root,full=mode=='full')
    if(compare)compare_reported_values(out,root,full=mode=='full')
    make_figures(out,full=mode=='full')
    write_manifest('completed')
    message('Analysis completed: ',out)
    invisible(out)
  },error=function(e) {
    write_manifest('failed',conditionMessage(e));stop(e)
  })
}

# Set options(stephensi.autorun=FALSE) before sourcing to load the runner only.
if(isTRUE(getOption('stephensi.autorun',TRUE))) {
  args<-commandArgs(trailingOnly=TRUE)
  script_arg<-grep('^--file=',commandArgs(),value=TRUE)
  source_file<-tryCatch(sys.frame(1)$ofile,error=function(e)NULL)
  root<-if(!is.null(source_file))dirname(normalizePath(source_file)) else
    if(length(script_arg))dirname(normalizePath(sub('^--file=','',script_arg[1]))) else getwd()
  mode<-'full';workers<-1L;out<-NULL;resume<-FALSE;i<-1L
  while(i<=length(args)) {
    key<-args[i]
    if(key=='--resume'){resume<-TRUE;i<-i+1L;next}
    if(!key%in%c('--mode','--workers','--out'))stop('Unrecognised argument: ',key)
    if(i==length(args))stop('Missing value for ',key)
    value<-args[i+1L]
    if(key=='--mode')mode<-value
    if(key=='--workers')workers<-as.integer(value)
    if(key=='--out')out<-value
    i<-i+2L
  }
  run_analysis(root,mode,workers,out,resume)
}
