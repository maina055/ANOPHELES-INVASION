# Numerical verification and comparison with the reference manuscript calculations.
verify_model <- function(b,f,cfg,out,root) {
  records<-list()
  record<-function(name,value,tol) {
    passed<-is.finite(value)&&abs(value)<=tol
    records[[length(records)+1L]]<<-data.frame(check=name,value=value,tolerance=tol,passed=passed)
    write_result(do.call(rbind,records),'verification',out)
    if(!passed)stop('Verification failed: ',name,'; value=',format(value,digits=16))
  }
  # Nesting of the earlier four-state model when treatment is disabled.
  old<-scan(gzfile(file.path(root,'data','initial_state.csv.gz')),skip=1,quiet=TRUE)
  h<-array(0,c(6,3,5,62,2));h[1:4,,,,]<-array(old[1:7440],c(4,3,5,62,2))
  y<-pack(h,array(old[7441:7456],c(4,2,2)))
  legacy<-read.csv(file.path(root,'data','legacy_reference.csv'),stringsAsFactors=FALSE)
  for(sid in names(SCENARIOS)) {
    yy<-scenario(y,change(cfg,treated=0),f,sid);r<-summary_state(yy,'legacy',sid)
    for(age in c('all','6-59')) {
      aa<-r[r$region=='both'&r$age==age,];bb<-legacy[legacy$scenario==sid&legacy$age==age,]
      for(k in c('clinical','cost','dalys','deaths','doses'))
        record(paste('legacy',sid,age,k,sep='_'),(aa[[k]]-bb[[k]])/max(1,abs(bb[[k]])),1e-8)
    }
  }
  # Continuous human flow balance: natural deaths plus malaria deaths.
  y<-initial_state(cfg,f);y[vi(0,0,3)]<-100;k<-make_context(f,cfg)
  der<-numeric(NS);der[k$full_index]<-rhs(0,y[k$full_index],k)
  record('continuous_human_balance',sum(der[seq_len(NH)])+f$MU*sum(y[seq_len(NH)])+sum(unpack(der)$o[4,,]),1e-8)
  # Monthly births, ageing and dose events conserve people.
  y[NB+seq_len(1860)]<-0;y[oi(0,0,8)]<-100;y[oi(1,0,8)]<-100
  before<-sum(y[seq_len(NH)]);k<-make_context(f,change(cfg,vacc=1))
  yy<-boundary(y,k,DAYS_MONTH)
  record('monthly_population_balance',sum(yy[seq_len(NH)])-before-200,1e-8)
  # Exponential clearance of an isolated treated cohort.
  x<-unpack(initial_state(cfg,f));x$h[]<-0;x$v[]<-0
  for(p in 1:2)x$h[1,1,1,,p]<-1e5*f$AGE_SHARES
  x$h[6,1,1,31,1]<-100;x$h[1,1,1,31,1]<-x$h[1,1,1,31,1]-100
  yy<-run_model(pack(x$h,x$v),cfg,f,years=1/12)
  actual<-sum(unpack(yy)$h[6,,,,1]);expected<-100*exp(-(1/cfg$txdays+f$MU)*DAYS_MONTH)
  record('treated_clearance_analytic_relative',(actual-expected)/expected,2e-4)
  # Convergence under halving the largest integration step.
  a<-scenario(b$state,b$cfg,f,'F');aa<-summary_state(a,'reference','F')
  half<-scenario(b$state,b$cfg,f,'F',max_step=.5);bb<-summary_state(half,'reference','F')
  for(k in c('clinical','cost','dalys','deaths','doses'))
    record(paste0('half_step_',k),max(abs(aa[[k]]-bb[[k]])/pmax(1,abs(bb[[k]]))),1e-5)
  o<-unpack(a)$o
  record('cost_decomposition_relative',(sum(o[6,,])-sum(o[13:15,,]))/sum(o[6,,]),1e-10)
  record('fatality_accounting_relative',(sum(o[4,,])-.07*sum(o[3,,]))/sum(o[4,,]),1e-10)
  noeff<-change(b$cfg,infection_block=0)
  un<-scenario(b$state,noeff,f,'C');vac<-scenario(b$state,noeff,f,'D')
  record('zero_protection_clinical',sum(unpack(un)$o[1:4,,])-sum(unpack(vac)$o[1:4,,]),1e-7)
  y<-initial_state(b$cfg,f);x<-unpack(y);x$h[1,,,,]<-x$h[1,,,,]+x$h[3,,,,];x$h[3,,,,]<-0
  diseasefree<-scenario(pack(x$h,x$v),b$cfg,f,'F')
  record('disease_free_episodes',sum(unpack(diseasefree)$o[1:4,,]),1e-10)
  # Reference vaccine uptake: each eligible individual can receive only the next dose.
  h<-array(0,c(6,3,5,62,2));v<-array(0,c(4,2,2));o<-array(0,c(15,62,2))
  for(d in 0:3)h[1,1,d+1,c(6,7,9,24)[d+1],1]<-100
  k<-make_context(f,change(cfg,vacc=1));yy<-boundary(pack(h,v,o),k,DAYS_MONTH)
  o<-unpack(yy)$o
  for(d in 1:4)record(paste0('dose_',d,'_timing_and_uptake'),o[5,c(6,7,9,24)[d]+1,1]-100*f$DOSE_ATTEMPT[d],1e-10)
  record('doses_only_at_scheduled_ages',sum(o[5,-(c(6,7,9,24)+1),]),1e-10)
  record('reference_calibration_absolute',max(abs(b$pr-c(.038*.959,.010*.933))),1e-6)
  message('Passed ',length(records),' numerical checks')
  invisible(do.call(rbind,records))
}
# The reference folder is used only after simulation, never as a model input.
# This comparison is numerical verification, not independent clinical validation.
compare_reference <- function(out,root,full=TRUE) {
  names<-c('scenarios_reference.csv','contrasts_complete.csv','principal_economic_comparisons.csv',
    'child_outcomes_with_full_cost_ratio.csv')
  if(full)names<-c(names,'scenarios_complete.csv','density_curve.csv','control_boundaries.csv',
     'economic_scenarios.csv','global_128.csv','prcc.csv','external_benchmark_scan.csv')
  report<-list()
  for(name in names) {
    refpath<-file.path(root,'verification_targets',name);newpath<-file.path(out,name)
    if(!file.exists(refpath))stop('Missing numerical comparison target: ',name)
    if(!file.exists(newpath))stop('Missing calculated output: ',name)
    ref<-read.csv(refpath,stringsAsFactors=FALSE);new<-read.csv(newpath,stringsAsFactors=FALSE)
    if(!all(names(ref)%in%names(new)))stop('Missing output columns: ',name)
    # Quick mode compares the reference model only with the same reference rows.
    if(!full&&'model'%in%names(ref))ref<-ref[ref$model=='reference',,drop=FALSE]
    key<-intersect(c('model','scenario','region','age','contrast','sample','endpoint','parameter','density','effect_scale'),names(ref))
    if(!length(key))stop('No comparison key for ',name)
    keyfun<-function(x)do.call(paste,c(lapply(x[,key,drop=FALSE],function(v)if(is.numeric(v))sprintf('%.10g',v) else v),sep='|'))
    rk<-keyfun(ref);nk<-keyfun(new)
    stopifnot(!anyDuplicated(rk),!anyDuplicated(nk))
    jj<-match(rk,nk)
    if(anyNA(jj)||length(rk)!=length(nk))stop('Reference row mismatch: ',name)
    new<-new[jj,,drop=FALSE]
    numeric_cols<-intersect(names(ref)[vapply(ref,is.numeric,FALSE)],names(new))
    numeric_cols<-setdiff(numeric_cols,key)
    for(col in numeric_cols) {
      a<-new[[col]];b<-ref[[col]]
      same_na<-identical(is.na(a),is.na(b));ok<-is.finite(a)&is.finite(b)
      err<-if(any(ok))max(abs(a[ok]-b[ok])/pmax(1,abs(b[ok]))) else 0
      # The prevalence-matched alternative uses different root-finding algorithms.
      # Its reference density was solved to 1e-6, so 5e-5 relative tolerance is used.
      tol<-if(name%in%c('scenarios_complete.csv','contrasts_complete.csv',
                        'principal_economic_comparisons.csv','child_outcomes_with_full_cost_ratio.csv'))5e-5 else 1e-6
      passed<-same_na&&all(is.finite(a[!is.na(a)]))&&err<=tol
      report[[length(report)+1L]]<-data.frame(file=name,variable=col,max_scaled_difference=err,tolerance=tol,passed=passed)
    }
  }
  ans<-do.call(rbind,report);write_result(ans,'reference_comparison',out)
  if(!nrow(ans)||!all(ans$passed))stop('Reference comparison failed; inspect reference_comparison.csv')
  message('Passed ',nrow(ans),' output comparisons with the manuscript calculations')
  invisible(ans)
}
