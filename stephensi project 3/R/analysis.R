# Calibration, reference interventions and prespecified sensitivity analyses.
write_result <- function(x,name,out) {
  write.csv(x,file.path(out,paste0(name,'.csv')),row.names=FALSE,na='')
  invisible(x)
}
load_reference <- function(out) readRDS(file.path(out,'baseline_reference.rds'))

# Optional process parallelism uses only the parallel package distributed with R.
# PSOCK workers are supported on Windows, macOS and Linux.
map_jobs <- function(items,fun,workers=1L,root=NULL) {
  if(workers<=1L)return(lapply(items,fun))
  cl<-parallel::makePSOCKcluster(workers,outfile='')
  on.exit(parallel::stopCluster(cl),add=TRUE)
  parallel::clusterCall(cl,function(root) {
    source(file.path(root,'R','model.R'),local=.GlobalEnv)
    source(file.path(root,'R','analysis.R'),local=.GlobalEnv)
    compiler::enableJIT(3L)
    NULL
  },root)
  ans<-parallel::parLapplyLB(cl,items,fun)
  ans
}
run_variant <- function(tag,cfg,f,out,changes=list(),target=c(.038,.010),
                        fractions=c(.959,.933),diag=1,init_years=14,
                        ids=names(SCENARIOS),years=10,recalibrate=TRUE) {
  path<-file.path(out,paste0('scenarios_',tag,'.csv'))
  if(file.exists(path))return(read.csv(path,stringsAsFactors=FALSE))
  cfg<-modifyList(cfg,changes)
  if(tag=='reference'&&file.exists(file.path(out,'baseline_reference.rds'))) {
    b<-load_reference(out)
  } else if(recalibrate) {
    b<-calibrate(cfg,f,target,fractions,diag,init_years,tag,out)
  } else {
    b<-load_reference(out);b$cfg<-modifyList(b$cfg,changes)
    b$diagnostic$tag<-tag
  }
  saveRDS(b,file.path(out,paste0('baseline_',tag,'.rds')),compress=TRUE)
  if(!file.exists(file.path(out,paste0('calibration_',tag,'.csv'))))
    write_result(b$diagnostic,paste0('calibration_',tag),out)
  rows<-list();dose_rows<-list()
  state_dir<-file.path(out,'states');dir.create(state_dir,showWarnings=FALSE)
  for(sid in ids) {
    keep<-tag%in%c('reference','lake')
    z<-scenario(b$state,b$cfg,f,sid,years=years,keep=keep)
    y<-if(keep)z$final else z
    rows[[sid]]<-summary_state(y,tag,sid)
    saveRDS(y,file.path(state_dir,paste0('final_',tag,'_',sid,'.rds')),compress=TRUE)
    o<-unpack(y)$o
    for(region in c('both','rural','urban')) {
      pp<-switch(region,both=1:2,rural=1L,urban=2L)
      counts<-vapply(c(6L,7L,9L,24L),function(a)sum(o[5,a+1L,pp]),0.)
      dose_rows[[length(dose_rows)+1L]]<-data.frame(model=tag,scenario=sid,
        region=region,dose1=counts[1],dose2=counts[2],dose3=counts[3],
        dose4=counts[4],all_doses=sum(counts))
    }
    if(keep)write_result(trajectory_table(z),paste0('trajectory_',tag,'_',sid),out)
  }
  write_result(do.call(rbind,dose_rows),paste0('dose_deliveries_',tag),out)
  ans<-do.call(rbind,rows);write_result(ans,paste0('scenarios_',tag),out)
  message('Completed ',tag);ans
}
structural_job <- function(tag,f,cfg,out) {
  changes<-list();target<-c(.038,.010);fractions<-c(.959,.933)
  diag<-1;init_years<-14;recalibrate<-TRUE
  if(tag=='lake'){changes<-list(care_r=.567);target<-c(.105,.010);fractions<-c(.955,.933)}
  if(tag=='partial_immunity')changes<-list(rsus=.5)
  if(tag=='no_infection_immunity')changes<-list(rsus=1)
  if(tag=='early_low'){changes<-list(early1=.1,early2=.2);recalibrate<-FALSE}
  if(tag=='early_high'){changes<-list(early1=.2,early2=.4);recalibrate<-FALSE}
  if(tag=='diagnostic_80')diag<-.8
  if(tag=='diagnostic_60')diag<-.6
  if(tag=='older_mortality_low')f$PDEATH_SEV[61:62]<-f$PDEATH_SEV[61:62]*.5
  if(tag=='older_mortality_high')f$PDEATH_SEV[61:62]<-f$PDEATH_SEV[61:62]*1.5
  if(tag=='older_clinical_low')f$PCLIN[61:62]<-f$PCLIN[61:62]*.5
  if(tag=='older_clinical_high')f$PCLIN[61:62]<-f$PCLIN[61:62]*1.5
  if(tag=='init28')init_years<-28
  if(tag=='init56')init_years<-56
  if(tag=='care_half')changes<-list(care_r=.653*.5,care_u=.603*.5)
  if(tag=='care_full')changes<-list(care_r=1,care_u=1)
  if(tag=='delay_zero')changes<-list(delay=0)
  if(tag=='delay_four')changes<-list(delay=4)
  if(tag=='txinfect_zero')changes<-list(txinfect=0)
  if(tag=='txinfect_full')changes<-list(txinfect=1)
  if(tag=='admission_half')changes<-list(admit=.5,unfatal=2)
  if(tag=='combined'){changes<-list(rsus=.5,early1=.1,early2=.2,care_r=.653*.5,care_u=.603*.5);diag<-.8}
  run_variant(tag,cfg,f,out,changes,target,fractions,diag,init_years,recalibrate=recalibrate)
}
STRUCTURAL_TAGS <- c('lake','partial_immunity','no_infection_immunity','early_low','early_high',
 'diagnostic_80','diagnostic_60','older_mortality_low','older_mortality_high',
 'older_clinical_low','older_clinical_high','init28','init56','care_half','care_full',
 'delay_zero','delay_four','txinfect_zero','txinfect_full','admission_half','combined')
extra_job <- function(tag,f,cfg,out) {
  changes<-list();years<-10;recalibrate<-FALSE
  if(grepl('^older_severity_',tag)) {
    f$PSEV[61:62]<-f$PSEV[61:62]*if(grepl('low$',tag)).5 else 1.5;recalibrate<-TRUE
  }
  if(grepl('^severity_',tag)){changes$severity_mult<-if(grepl('low$',tag)).5 else 1.5;recalibrate<-TRUE}
  if(grepl('^fatality_',tag)){changes$fatality_mult<-if(grepl('low$',tag)).5 else 1.5;recalibrate<-TRUE}
  if(grepl('^protection_',tag))changes$infection_block<-if(grepl('low$',tag)).75 else 1.25
  if(grepl('^waning_',tag))f$PROFILE_RATE<-f$PROFILE_RATE*if(grepl('slow$',tag)).5 else 2
  if(tag=='coverage_observed')f$DOSE_ATTEMPT<-c(.827,.781/.827,.689/.781,.340/.689)
  if(tag=='equal_biting'){f$BITE_WEIGHT[]<-1;recalibrate<-TRUE}
  if(tag=='zero_natural_growth'){f$BIRTH<-f$MU;recalibrate<-TRUE}
  if(tag=='horizon5')years<-5
  if(tag=='horizon20')years<-20
  if(grepl('^treatment_cost_',tag)) {
    m<-if(grepl('low$',tag)).5 else 2;f$COST_UNCOMPL<-f$COST_UNCOMPL*m;f$COST_SEV<-f$COST_SEV*m
  }
  if(grepl('^adult_lifetime_',tag))f$LIFE_REMAIN[62]<-if(grepl('low$',tag))47.83 else 67.62
  run_variant(tag,cfg,f,out,changes,ids=c('C','D'),years=years,recalibrate=recalibrate)
}
EXTRA_TAGS <- c('older_severity_low','older_severity_high','severity_low','severity_high',
 'fatality_low','fatality_high','protection_low','protection_high','waning_slow','waning_fast',
 'coverage_observed','equal_biting','zero_natural_growth','horizon5','horizon20',
 'treatment_cost_low','treatment_cost_high','adult_lifetime_low','adult_lifetime_high')

# Comparator C versus D, with fixed native-vector calibration and changed invader density.
density_job <- function(den,b,f,out) {
  cfg<-change(b$cfg,steph_density=den)
  a<-scenario(b$state,cfg,f,'C');d<-scenario(b$state,cfg,f,'D')
  rr<-contrasts(rbind(summary_state(a,'density','C'),summary_state(d,'density','D')))
  ch<-subset(rr,region=='both'&age=='6-59');allr<-subset(rr,region=='both'&age=='all')
  data.frame(density=den,prev_u=prevalence(a)[2],clinical_averted=ch$clinical_averted,
    dalys_averted=allr$dalys_averted,incremental_cost=allr$incremental_cost,icer=allr$icer)
}
control_boundaries <- function(b,f,out) {
  base<-read.csv(file.path(out,'scenarios_reference.csv'),stringsAsFactors=FALSE)
  base<-subset(base,region=='both'&age=='all');C0<-subset(base,scenario=='C');D0<-subset(base,scenario=='D')
  reficer<-(D0$cost-C0$cost)/(C0$dalys-D0$dalys)
  rows<-lapply(c(0,1/3,2/3,1,4/3),function(e) {
    cfg<-change(b$cfg,control_bite=1-.3*e,control_capacity=1-.4*e,
                control_mortality=1+.3*e,control_cost=0)
    a<-subset(summary_state(scenario(b$state,cfg,f,'E'),'grid','E'),region=='both'&age=='all')
    cfg$control_cost<-1
    one<-subset(summary_state(scenario(b$state,cfg,f,'E'),'grid','E'),region=='both'&age=='all')
    benefit<-C0$dalys-a$dalys;slope<-one$cost-a$cost
    data.frame(effect_scale=e,benefit=benefit,zero_cost_delta=a$cost-C0$cost,cost_per_price=slope,
      equal_ratio_price=if(benefit>1e-6)(reficer*benefit-(a$cost-C0$cost))/slope else NA_real_,
      equal_total_cost_price=(D0$cost-a$cost)/slope)
  })
  write_result(do.call(rbind,rows),'control_boundaries',out)
}
annual_urban_rate <- function(z) {
  delta<-unpack(z$states[,85])$o[,,2]-unpack(z$states[,73])$o[,,2]
  total<-rowSums(delta);(total[2]+total[3])/total[10]
}
benchmark_analyses <- function(b,f,cfg,out,root,workers=1L) {
  path<-file.path(out,'scenarios_lake_matched_urban.csv')
  if(!file.exists(path)) {
    target<-.105*.955;history<-list()
    obj<-function(den) {
      y<-scenario(b$state,change(b$cfg,steph_density=den),f,'C')
      p<-prevalence(y)[2];history[[length(history)+1L]]<<-data.frame(density=den,prevalence=p);p-target
    }
    fit<-uniroot(obj,c(.001,.2),tol=1e-9)
    den<-fit$root;achieved<-obj(den)+target
    rows<-lapply(names(SCENARIOS),function(sid)summary_state(scenario(b$state,change(b$cfg,steph_density=den),f,sid),'lake_matched_urban',sid))
    write_result(do.call(rbind,rows),'scenarios_lake_matched_urban',out)
    write_result(do.call(rbind,history),'prevalence_match_search',out)
    write_result(data.frame(density=den,target_pf=target,achieved_pf=achieved),'prevalence_match',out)
  }
  run_variant('lake_lower',cfg,f,out,list(care_r=.567),target=c(.078,.010),fractions=c(.955,.933),ids=c('A','B'))
  run_variant('lake_upper',cfg,f,out,list(care_r=.567),target=c(.132,.010),fractions=c(.955,.933),ids=c('A','B'))
  run_variant('species_under5',cfg,f,out,fractions=c(.935,.926),ids=c('A','B','C','D'))
  if(!file.exists(file.path(out,'external_benchmark_scan.csv'))) {
    rate_a<-annual_urban_rate(scenario(b$state,b$cfg,f,'A',keep=TRUE))
    densities<-exp(seq(log(.001),log(5),length.out=25))
    fun<-function(d) {
      rate<-annual_urban_rate(scenario(b$state,change(b$cfg,steph_density=d),f,'C',keep=TRUE))
      data.frame(density=d,rate_ratio=rate/rate_a)
    }
    rows<-map_jobs(as.list(densities),fun,workers,root)
    scan<-do.call(rbind,rows);write_result(scan,'external_benchmark_scan',out)
    endpoints<-scan[c(1,nrow(scan)),];write_result(endpoints,'external_benchmark_search',out)
    bracketed<-prod(endpoints$rate_ratio-30)<0
    status<-data.frame(status=if(bracketed)'bracketed' else 'not_bracketed',
      density_lower=.001,density_upper=5,ratio_lower=endpoints$rate_ratio[1],
      ratio_upper=endpoints$rate_ratio[2],target_ratio=30,max_sampled_ratio=max(scan$rate_ratio))
    if(bracketed) {
      obj<-function(d)fun(d)$rate_ratio-30
      den<-uniroot(obj,c(.001,5),tol=1e-7)$root
      status$status<-'matched_transported_benchmark';status$matched_density<-den
      rows<-lapply(names(SCENARIOS),function(sid)summary_state(scenario(b$state,change(b$cfg,steph_density=den),f,sid),'transported_30fold',sid))
      write_result(do.call(rbind,rows),'scenarios_transported_30fold',out)
    }
    write_result(status,'external_benchmark',out)
  }
}
economic_analyses <- function(b,f,out) {
  tasks<-list(price2=list(price_dose=2),price10=list(price_dose=10),
              discount0=list(discount=0),discount5=list(discount=.05))
  rows<-list()
  for(tag in names(tasks))for(sid in c('C','D')) {
    y<-scenario(b$state,modifyList(b$cfg,tasks[[tag]]),f,sid)
    rows[[length(rows)+1L]]<-summary_state(y,tag,sid)
  }
  df<-do.call(rbind,rows);write_result(df,'economic_scenarios',out)
  write_result(contrasts(df),'economic_contrasts',out)
}
prcc <- function(x,y) {
  a<-apply(x,2,rank,ties.method='average');b<-rank(y,ties.method='average')
  vapply(seq_len(ncol(a)),function(j) {
    other<-cbind(1,a[,-j,drop=FALSE]);q<-qr(other)
    cor(qr.resid(q,a[,j]),qr.resid(q,b))
  },0.)
}
global_job <- function(i,X,b,f,out) {
  path<-file.path(out,sprintf('global_%03d.csv',i-1L))
  if(file.exists(path))return(read.csv(path))
  x<-X[i,];cfg<-change(b$cfg,steph_density=x[1],infection_block=x[2],
                       steph_bite_multiplier=x[3],adult_mortality_mult=x[4])
  a<-unpack(scenario(b$state,cfg,f,'C'))$o;d<-unpack(scenario(b$state,cfg,f,'D'))$o
  dalys<-sum(a[7,,]-d[7,,]);cost<-sum(d[6,,]-a[6,,]);episodes<-sum(a[2:3,7:60,]-d[2:3,7:60,])
  ans<-data.frame(sample=i-1L,density=x[1],protection=x[2],biting=x[3],mortality=x[4],
    episodes=episodes,dalys=dalys,incremental_cost=cost,icer=cost/dalys,row.names=NULL)
  write.csv(ans,path,row.names=FALSE);ans
}
global_analysis <- function(b,f,out,root,workers=1L) {
  labels<-c('density','protection','biting','mortality')
  X<-as.matrix(read.csv(file.path(root,'data','global_design_128.csv'))[,labels])
  stopifnot(identical(dim(X),c(128L,4L)),all(is.finite(X)))
  write_result(as.data.frame(X),'global_design_128_used',out)
  fun<-function(i)global_job(i,X,b,f,out)
  df<-do.call(rbind,map_jobs(as.list(1:128),fun,workers,root))
  write_result(df,'global_128',out)
  rows<-list()
  for(endpoint in c('episodes','icer')) {
    yy<-df[[endpoint]];est<-prcc(X,yy)
    # Fixed one-based bootstrap indices reproduce the reference random draws.
    # The resampling design is independent of the model outcomes.
    ix<-as.matrix(read.csv(file.path(root,'data',paste0('bootstrap_',endpoint,'_indices.csv')),header=FALSE))
    stopifnot(identical(dim(ix),c(500L,128L)),all(ix>=1 & ix<=128))
    boot<-t(apply(ix,1,function(k)prcc(X[k,,drop=FALSE],yy[k])))
    half<-prcc(X[1:64,,drop=FALSE],yy[1:64])
    rows[[endpoint]]<-data.frame(endpoint=endpoint,parameter=labels,prcc=est,
      lower=apply(boot,2,quantile,probs=.025,type=7),
      upper=apply(boot,2,quantile,probs=.975,type=7),prcc_first64=half,row.names=NULL)
  }
  write_result(do.call(rbind,rows),'prcc',out)
}
aggregate_results <- function(out) {
  paths<-list.files(out,pattern='^scenarios_.*[.]csv$',full.names=TRUE)
  paths<-paths[!basename(paths)%in%c('scenarios_all.csv','scenarios_complete.csv')]
  df<-do.call(rbind,lapply(paths,read.csv,stringsAsFactors=FALSE))
  stopifnot(!anyDuplicated(df[,c('model','scenario','region','age')]))
  write_result(df,'scenarios_complete',out);co<-contrasts(df)
  write_result(co,'contrasts_complete',out)
  write_result(subset(co,age=='all'),'principal_economic_comparisons',out)
  allc<-subset(co,age=='all',select=c('model','region','contrast','incremental_cost'))
  names(allc)[4]<-'total_incremental_cost'
  child<-merge(subset(co,age=='6-59'),allc,by=c('model','region','contrast'))
  child$full_cost_per_child_daly<-child$total_incremental_cost/child$dalys_averted
  write_result(child,'child_outcomes_with_full_cost_ratio',out)
  # Frontier among C,D,E,F: remove strictly dominated strategies, then extended dominance.
  g<-subset(df,model=='reference'&region=='both'&age=='all'&scenario%in%c('C','D','E','F'))
  base<-subset(g,scenario=='C');g$benefit<-base$dalys-g$dalys;g$incremental_cost<-g$cost-base$cost
  g<-g[order(g$benefit,g$incremental_cost),];g$status<-'frontier'
  for(i in seq_len(nrow(g)))if(any(g$benefit>=g$benefit[i]&g$incremental_cost<=g$incremental_cost[i]&
      (g$benefit>g$benefit[i]|g$incremental_cost<g$incremental_cost[i])))g$status[i]<-'strictly_dominated'
  repeat {
    ii<-which(g$status=='frontier');if(length(ii)<3)break
    slopes<-diff(g$incremental_cost[ii])/diff(g$benefit[ii])
    bad<-which(diff(slopes)<0);if(!length(bad))break
    g$status[ii[bad[1]+1L]]<-'extendedly_dominated'
  }
  g$sequential_icer<-NA_real_;ii<-which(g$status=='frontier')
  if(length(ii)>1)g$sequential_icer[ii[-1]]<-diff(g$incremental_cost[ii])/diff(g$benefit[ii])
  write_result(g[,c('scenario','benefit','incremental_cost','status','sequential_icer')],'economic_frontier',out)
  invisible(df)
}
