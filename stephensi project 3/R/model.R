# Native R implementation of the six-state malaria model.
# Equations, integration, calibration and analyses use packages distributed with R.
# Scientific indices: population p=0,1; age a=0,...,61; dose d=0,...,4;
# protection q=0,1,2; human x=S,E,I,R,W,T=0,...,5.
# States use the same linear ordering as the manuscript's reference implementation.
NH <- 11160L; NV <- 16L; NB <- NH + NV; NS <- 13036L
DAYS_YEAR <- 365.25; DAYS_MONTH <- DAYS_YEAR / 12
hi <- function(p,a,d,q,x) ((((p*62L+a)*5L+d)*3L+q)*6L+x)+1L
vi <- function(p,v,x) NH+(p*2L+v)*4L+x+1L
oi <- function(p,a,x) NB+(p*62L+a)*15L+x+1L
unpack <- function(y) list(h=array(y[seq_len(NH)],c(6,3,5,62,2)),
  v=array(y[NH+seq_len(NV)],c(4,2,2)),o=array(y[NB+seq_len(1860)],c(15,62,2)))
pack <- function(h,v,o=array(0,c(15,62,2))) c(h,v,o)
change <- function(x,...) modifyList(x,list(...))
load_inputs <- function(root) {
  d <- read.csv(file.path(root,'data','parameters.csv'),stringsAsFactors=FALSE)
  f <- lapply(split(d,d$parameter),function(x)as.double(x$value[order(x$index)]))
  cfg <- list()
  for (name in c('config.csv','extension_config.csv')) {
    d <- read.csv(file.path(root,'data',name),stringsAsFactors=FALSE)
    cfg <- modifyList(cfg,as.list(setNames(as.double(d$value),d$parameter)))
  }
  list(f=f,cfg=cfg)
}
capacity <- function(density,j,f) {
  G <- f$PHI[j]*f$ETA[j]/(f$DV[j]*(f$ETA[j]+f$ECL[j]))
  if (G<=1) stop('Vector reproduction number must exceed one for this capacity parameterisation.')
  f$DV[j]*density*1e5/f$ETA[j]/(1-1/G)
}
validate_inputs <- function(y,f,cfg,years,max_step) {
  stopifnot(length(y)==NS,all(is.finite(y)),all(y[seq_len(NB)]>=-1e-7),
    years>0,abs(years*12-round(years*12))<1e-8,max_step>0,max_step<=1,
    all(is.finite(unlist(f))),all(is.finite(unlist(cfg))),
    cfg$dens_r>0,cfg$dens_u>0,cfg$steph_density>0,
    cfg$txdays>0,cfg$delay>=0,cfg$discount>=0,cfg$price_dose>=0,
    all(c(cfg$care_r,cfg$care_u,cfg$admit,cfg$rsus,cfg$txinfect)>=0),
    all(c(cfg$care_r,cfg$care_u,cfg$admit,cfg$rsus,cfg$txinfect)<=1),
    cfg$unfatal>=0,all(c(cfg$vacc,cfg$steph,cfg$mitigation,cfg$treated)%in%c(0,1)),
    all(f$DOSE_ATTEMPT>=0 & f$DOSE_ATTEMPT<=1),
    all(f$PROFILE_W>=0 & f$PROFILE_W<=1),all(f$PROFILE_RATE>=0),
    all(c(f$PROFILE_E,cfg$early1,cfg$early2)*cfg$infection_block>=0),
    all(c(f$PROFILE_E,cfg$early1,cfg$early2)*cfg$infection_block<=1),
    all(f$PCLIN*cfg$clinical_mult>=0 & f$PCLIN*cfg$clinical_mult<=1),
    all(f$PSEV*cfg$severity_mult>=0 & f$PSEV*cfg$severity_mult<=1),
    all(f$PDEATH_SEV*cfg$fatality_mult>=0),
    max(f$PDEATH_SEV*cfg$fatality_mult)*max(1,cfg$unfatal)<=1,
    all(c(cfg$cost_mult,cfg$control_cost,cfg$infection_block)>=0),
    cfg$control_capacity>0,cfg$control_mortality>0,cfg$adult_mortality_mult>0,
    cfg$control_bite>=0,cfg$steph_bite_multiplier>=0,cfg$migrate==0)
  klin<-f$PCLIN*cfg$clinical_mult; sev<-f$PSEV*cfg$severity_mult
  mort<-f$PDEATH_SEV*cfg$fatality_mult
  fatal<-klin*sev*mort*(cfg$admit+(1-cfg$admit)*cfg$unfatal)
  for(care in c(cfg$care_r,cfg$care_u)) {
    routed<-cfg$treated*klin*((1-sev)*care+sev*cfg$admit*(1-mort))
    stopifnot(all(fatal+routed<=1+1e-12))
  }
}
# Precompute indices and coefficients once per trajectory, not at each RHS call.
# Unvaccinated trajectories omit dose/protection cells that are identically zero.
make_context <- function(f,cfg) {
  if (cfg$discount>0) f$LIFE_REMAIN <- -expm1(-log1p(cfg$discount)*f$LIFE_REMAIN)/log1p(cfg$discount)
  f$PROFILE_W[2:3] <- f$PROFILE_W[4]
  f$PROFILE_RATE[3:6] <- rep(f$PROFILE_RATE[7:8],2)
  nq <- if(cfg$vacc)15L else 1L
  n <- 124L*nq; nh<-6L*n
  active <- if(cfg$vacc)seq_len(NH) else as.vector(outer(0:5,0:123*90L,'+'))+1L
  full_index <- c(active,NH+seq_len(NV),NB+seq_len(1860))
  a <- rep(rep(1:62,each=nq),2); p<-rep(1:2,each=62*nq)
  d <- if(cfg$vacc)rep(rep(1:5,each=3),124) else rep(1L,n)
  q <- if(cfg$vacc)rep(1:3,620) else rep(1L,n)
  e <- c(f$PROFILE_E[1],cfg$early1,cfg$early2,f$PROFILE_E[4:5])[d]*cfg$infection_block*(q>1)
  klin<-f$PCLIN[a]*cfg$clinical_mult; sev<-f$PSEV[a]*cfg$severity_mult
  mort<-f$PDEATH_SEV[a]*cfg$fatality_mult; care<-c(cfg$care_r,cfg$care_u)[p]
  fd<-klin*sev*mort*(cfg$admit+(1-cfg$admit)*cfg$unfatal)
  routed<-cfg$treated*klin*((1-sev)*care+sev*cfg$admit*(1-mort))
  bites<-c(f$BITES_G[1],f$BITES_T[1]*cfg$steph_bite_multiplier,
           f$BITES_G[2],f$BITES_T[2]*cfg$steph_bite_multiplier)
  if(cfg$mitigation)bites[4]<-bites[4]*cfg$control_bite
  cap<-c(capacity(cfg$dens_r,1,f),capacity(cfg$steph_density,2,f),
         capacity(cfg$dens_u,1,f),capacity(cfg$steph_density,2,f))
  mv<-rep(f$DV,2);mv[4]<-mv[4]*cfg$adult_mortality_mult
  if(cfg$mitigation){cap[4]<-cap[4]*cfg$control_capacity;mv[4]<-mv[4]*cfg$control_mortality}
  list(f=f,cfg=cfg,nq=nq,n=n,nh=nh,full_index=full_index,
       ih=seq_len(nh),iv=nh+seq_len(16),io=nh+16L+seq_len(1860),
       ibio=seq_len(nh+16L),a=a,p=p,d=d,q=q,
       bw=f$BITE_WEIGHT[a],acq=(1-e)*f$BITE_WEIGHT[a],fd=fd,routed=routed,
       wane=if(cfg$vacc)f$PROFILE_RATE[(d[q>1]-1)*2+q[q>1]-1] else numeric(),
       q0=which(q==1),q1=which(q==2),q2=which(q==3),qpos=which(q>1),
       age60=which(a==61),age61=which(a==62),
       age0=which(a==1),age59=which(a==60),
       age_to=which(a>=2&a<=60),age_from=which(a>=1&a<=59),
       bites=bites,cap=cap,mv=mv,eta=rep(f$ETA,2),phi=rep(f$PHI,2),
       ml=rep(f$ECL,2),sv=rep(f$SIGV,2),b=rep(f$B,2),c=rep(f$C,2),
       vector_active=c(1L,3L,if(cfg$steph)4L else integer()),
       klin=rep(f$PCLIN*cfg$clinical_mult,2),sev=rep(f$PSEV*cfg$severity_mult,2),
       care=rep(c(cfg$care_r,cfg$care_u),each=62),
       life=rep(f$LIFE_REMAIN,2),
       ctrl=c(rep(0,62),rep(if(cfg$mitigation)cfg$control_cost*cfg$cost_mult/DAYS_YEAR else 0,62)))
}
# Force of infection is frequency dependent and uses age-weighted human exposure.
# E progression is the common event behind clinical, severe and fatal outcomes.
rhs <- function(t,y,k) {
  f<-k$f; cfg<-k$cfg
  h<-matrix(y[k$ih],6L,k$n);v<-matrix(y[k$iv],4L,4L)
  cell_n<-colSums(h)
  wn<-colSums(matrix(cell_n*k$bw,nrow=62L*k$nq))
  wi<-colSums(matrix((h[3,]+h[5,]+cfg$txinfect*h[6,])*k$bw,nrow=62L*k$nq))
  lh<-colSums(matrix(k$bites*k$b*v[4,],2L,2L))/wn
  lv<-k$bites*k$c*rep(wi/wn,each=2L)
  force<-k$acq*rep(lh,each=62L*k$nq)
  inf<-force*h[1,]; reinf<-force*cfg$rsus*h[4,]
  prog<-f$NU_H*h[2,];clear<-f$GAMMA*h[3,];loss<-f$RHO*h[4,]
  fatal<-prog*k$fd; routed<-prog*k$routed
  start<-if(cfg$delay>0)h[5,]/cfg$delay else 0
  recovery<-h[6,]/cfg$txdays
  dh<-rbind(-inf+loss,inf+reinf-prog,prog-clear-fatal-routed,
            clear+recovery-loss-reinf,
            if(cfg$delay>0)routed-start else 0*h[5,],
            (if(cfg$delay>0)start else routed)-recovery)-f$MU*h
  if(cfg$vacc) {
    w<-sweep(h[,k$qpos,drop=FALSE],2L,k$wane,'*')
    dh[,k$qpos]<-dh[,k$qpos]-w
    dh[,k$q0]<-dh[,k$q0]+w[,seq.int(1L,ncol(w),2L)]+w[,seq.int(2L,ncol(w),2L)]
  }
  ageing<-h[,k$age60,drop=FALSE]/(10*DAYS_YEAR)
  dh[,k$age60]<-dh[,k$age60]-ageing
  dh[,k$age61]<-dh[,k$age61]+ageing
  onset<-colSums(matrix(prog,k$nq,124L));dead<-colSums(matrix(fatal,k$nq,124L))
  na<-colSums(matrix(cell_n,k$nq,124L));clinic<-onset*k$klin
  severe<-clinic*k$sev;mild<-clinic-severe
  disc<-(1+cfg$discount)^(-t/DAYS_YEAR)
  ctrl<-k$ctrl*na
  txcost<-(mild*f$COST_UNCOMPL*(if(cfg$treated)k$care else 1)+severe*f$COST_SEV*cfg$admit)*cfg$cost_mult
  o<-matrix(0,15L,124L)
  o[1,]<-onset;o[2,]<-mild;o[3,]<-severe;o[4,]<-dead
  o[6,]<-disc*(txcost+ctrl)
  o[7,]<-disc*(dead*k$life+mild*f$DW_MOD*f$DUR_MOD+severe*f$DW_SEV*f$DUR_SEV)
  o[9,c(1L,63L)]<-f$BIRTH*colSums(matrix(na,62L,2L))
  o[10,]<-na/DAYS_YEAR;o[11,]<-severe*cfg$admit
  o[12,]<-cfg$treated*(mild*k$care+severe*cfg$admit)
  o[13,]<-disc*ctrl;o[14,]<-disc*txcost
  recruits<-k$phi*colSums(v[2:4,,drop=FALSE])*pmax(0,1-v[1,]/k$cap)
  dv<-rbind(recruits-(k$eta+k$ml)*v[1,],k$eta*v[1,]-(lv+k$mv)*v[2,],
             lv*v[2,]-(k$sv+k$mv)*v[3,],k$sv*v[3,]-k$mv*v[4,])
  dv[,setdiff(1:4,k$vector_active)]<-0
  c(dh,dv,o)
}
# Discrete monthly ageing precedes dose eligibility at 6,7,9 and 24 completed months.
# All infection states retain their infection status when vaccinated.
boundary <- function(y,k,t) {
  h<-matrix(y[k$ih],6L,k$n);o<-matrix(y[k$io],15L,124L)
  h[,k$age60]<-h[,k$age60]+h[,k$age59]
  h[,k$age_to]<-h[,k$age_from];h[,k$age0]<-0
  h[1,c(1L,62L*k$nq+1L)]<-o[9,c(1L,63L)];o[9,c(1L,63L)]<-0
  if(k$cfg$vacc)for(p in 0:1)for(d in 0:3) {
    a<-c(6L,7L,9L,24L)[d+1L]
    ii<-(p*62L+a)*15L+d*3L+1:3
    dosed<-h[,ii,drop=FALSE]*k$f$DOSE_ATTEMPT[d+1L]
    h[,ii]<-h[,ii]-dosed;tot<-rowSums(dosed)
    h[,ii[1]+4L]<-h[,ii[1]+4L]+tot*k$f$PROFILE_W[d+2L]
    h[,ii[1]+5L]<-h[,ii[1]+5L]+tot*(1-k$f$PROFILE_W[d+2L])
    count<-sum(dosed);disc<-(1+k$cfg$discount)^(-t/DAYS_YEAR)
    unit<-c(9.01,9.01,9.01,9.71)[d+1L]+(k$cfg$price_dose-5)*1.076/.9
    col<-p*62L+a+1L
    o[5,col]<-o[5,col]+count;o[6,col]<-o[6,col]+disc*unit*count
    o[8,col]<-o[8,col]+disc*count;o[15,col]<-o[15,col]+disc*unit*count
  }
  y[k$ih]<-h;y[k$io]<-o;y
}
# Classical RK4 with a step of 30.4375/31 days and exact monthly event boundaries.
# Returning only the final state keeps calibration memory use small.
run_model <- function(y,cfg,f,years=10,max_step=1,keep=FALSE) {
  validate_inputs(y,f,cfg,years,max_step)
  k<-make_context(f,cfg);z<-y[k$full_index]
  if(!cfg$vacc && any(y[setdiff(seq_len(NH),k$full_index[k$full_index<=NH])]!=0))
    stop('Unvaccinated run cannot discard existing vaccinated people.')
  months<-as.integer(round(years*12));steps<-ceiling(DAYS_MONTH/max_step)
  dt<-DAYS_MONTH/steps;t<-0
  if(keep){out<-matrix(0,NS,months+1L);out[,1]<-y}
  for(mo in seq_len(months)) {
    for(s in seq_len(steps)) {
      k1<-rhs(t,z,k);k2<-rhs(t+dt/2,z+dt*k1/2,k)
      k3<-rhs(t+dt/2,z+dt*k2/2,k);k4<-rhs(t+dt,z+dt*k3,k)
      z<-z+dt*(k1+2*k2+2*k3+k4)/6;t<-t+dt
      if(any(!is.finite(z))||any(z[k$ibio] < -1e-7))stop('Non-finite or negative biological state.')
    }
    z<-boundary(z,k,mo*DAYS_MONTH)
    if(keep)out[k$full_index,mo+1L]<-z
  }
  final<-numeric(NS);final[k$full_index]<-z
  if(keep)list(final=final,states=out,months=0:months) else final
}
initial_state <- function(cfg,f) {
  h<-array(0,c(6,3,5,62,2));v<-array(0,c(4,2,2))
  for(p in 1:2) {
    h[1,1,1,,p]<-1e5*f$AGE_SHARES*.965;h[3,1,1,,p]<-1e5*f$AGE_SHARES*.035
    den<-c(cfg$dens_r,cfg$dens_u)[p]
    v[,1,p]<-c(f$DV[1]*den*1e5/f$ETA[1],den*1e5,0,0)
  }
  pack(h,v)
}
prevalence <- function(y,ages=6:59) {
  h<-unpack(y)$h
  vapply(1:2,function(p)sum(h[c(3,5,6),,,ages+1L,p,drop=FALSE])/sum(h[,,,ages+1L,p,drop=FALSE]),0.)
}
# Fixed-duration initialization followed by age-wise population rescaling.
# This is not assumed to be a stationary endemic equilibrium.
baseline <- function(cfg,f,years=14) {
  cfg<-change(cfg,vacc=0,steph=0,mitigation=0)
  x<-unpack(run_model(initial_state(cfg,f),cfg,f,years))
  for(p in 1:2) {
    for(a in 1:62)x$h[,,,a,p]<-x$h[,,,a,p]*(1e5*f$AGE_SHARES[a]/sum(x$h[,,,a,p]))
    den<-c(cfg$dens_r,cfg$dens_u)[p]
    x$v[,1,p]<-x$v[,1,p]*(den*1e5/sum(x$v[2:4,1,p]))
    x$v[1,1,p]<-f$DV[1]*den*1e5/f$ETA[1]
  }
  pack(x$h,x$v)
}
# The populations are uncoupled: perturbing both log-densities simultaneously
# gives the two diagonal Jacobian entries without cross-population effects.
calibrate <- function(cfg,f,target=c(.038,.010),fractions=c(.959,.933),diag=1,
                      years=14,tag='reference',out=NULL) {
  actual<-target*fractions/diag;scale<-pmax(actual,.01);history<-list();last<-NULL
  residual<-function(x) {
    cc<-change(cfg,dens_r=exp(x[1]),dens_u=exp(x[2]));yy<-baseline(cc,f,years)
    pr<-prevalence(yy);history[[length(history)+1L]]<<-data.frame(dens_r=cc$dens_r,dens_u=cc$dens_u,prev_r=pr[1],prev_u=pr[2])
    last<<-list(cfg=cc,state=yy,pr=pr);(pr-actual)/scale
  }
  x<-log(c(cfg$dens_r,cfg$dens_u));r<-residual(x)
  for(it in 1:35) {
    if(max(abs(r))<1e-11)break
    eps<-1e-4;dr<-(residual(x+eps)-r)/eps
    if(any(!is.finite(dr))||any(abs(dr)<1e-12))stop('Singular calibration Jacobian: ',tag)
    step<-pmax(-1,pmin(1,r/dr));accepted<-FALSE
    for(rate in 2^-(0:12)) {
      xx<-pmax(log(.0001),pmin(log(5),x-rate*step));rr<-residual(xx)
      if(sum(rr^2)<sum(r^2)){x<-xx;r<-rr;accepted<-TRUE;break}
    }
    if(!accepted)stop('Calibration did not improve: ',tag)
  }
  if(max(abs(r))>=1e-11)stop('Calibration failed to converge: ',tag)
  err<-max(abs(last$pr-actual));stopifnot(err<1e-6)
  diagnostic<-data.frame(tag=tag,dens_r=last$cfg$dens_r,dens_u=last$cfg$dens_u,
    target_r=actual[1],target_u=actual[2],fit_r=last$pr[1],fit_u=last$pr[2],
    broad_r=prevalence(last$state,6:60)[1]*diag/fractions[1],
    broad_u=prevalence(last$state,6:60)[2]*diag/fractions[2],max_residual=err,init_years=years)
  result<-c(last,list(diagnostic=diagnostic,history=do.call(rbind,history)))
  if(!is.null(out)) {
    write.csv(result$history,file.path(out,paste0('calibration_history_',tag,'.csv')),row.names=FALSE)
    write.csv(diagnostic,file.path(out,paste0('calibration_',tag,'.csv')),row.names=FALSE)
  }
  message('Calibrated ',tag,'; maximum prevalence error = ',format(err,digits=3))
  result
}
SCENARIOS <- list(A=list(),B=list(vacc=1),C=list(steph=1),D=list(steph=1,vacc=1),
                  E=list(steph=1,mitigation=1),F=list(steph=1,mitigation=1,vacc=1))
scenario <- function(y,cfg,f,sid,years=10,max_step=1,keep=FALSE) {
  cfg<-modifyList(cfg,SCENARIOS[[sid]]);y[NB+seq_len(1860)]<-0
  if(cfg$steph)y[NH+13:16]<-c(3000,4500,0,0)
  run_model(y,cfg,f,years,max_step,keep)
}
summary_state <- function(y,tag,sid) {
  o<-unpack(y)$o;pr<-prevalence(y);rows<-list()
  for(region in c('both','rural','urban')) {
    pp<-switch(region,both=1:2,rural=1L,urban=2L)
    for(age in c('all','6-59','6-23','24-59')) {
      aa<-switch(age,all=0:61,'6-59'=6:59,'6-23'=6:23,'24-59'=24:59)+1L
      z<-rowSums(matrix(o[,aa,pp,drop=FALSE],15L))
      rows[[length(rows)+1L]]<-data.frame(model=tag,scenario=sid,region=region,age=age,
        infections=z[1],clinical=z[2]+z[3],severe=z[3],deaths=z[4],doses=z[5],cost=z[6],
        dalys=z[7],discounted_doses=z[8],person_years=z[10],hospitalisations=z[11],
        treated=z[12],control_cost=z[13],treatment_cost=z[14],vaccine_cost=z[15],
        completed_courses=sum(o[5,25,pp]),prev_r=pr[1],prev_u=pr[2])
    }
  }
  do.call(rbind,rows)
}
contrasts <- function(df) {
  keys<-interaction(df$model,df$region,df$age,drop=TRUE);rows<-list()
  for(g in split(df,keys))for(pair in list(c('B','A'),c('D','C'),c('E','C'),c('F','E'),c('F','C'))) {
    if(!all(pair%in%g$scenario))next
    a<-g[g$scenario==pair[1],];b<-g[g$scenario==pair[2],]
    stopifnot(nrow(a)==1,nrow(b)==1)
    z<-a[1,c('model','region','age')];z$contrast<-paste(pair,collapse='-')
    for(k in c('clinical','severe','deaths','dalys','hospitalisations'))z[[paste0(k,'_averted')]]<-b[[k]]-a[[k]]
    z$incremental_cost<-a$cost-b$cost
    z$icer<-if(z$dalys_averted>0)z$incremental_cost/z$dalys_averted else NA_real_
    z$cases_per_1000_courses<-if(a$completed_courses>0)1000*z$clinical_averted/a$completed_courses else NA_real_
    rows[[length(rows)+1L]]<-z
  }
  do.call(rbind,rows)
}
trajectory_table <- function(z) {
  do.call(rbind,lapply(seq_along(z$months),function(j) {
    y<-z$states[,j];o<-unpack(y)$o;pr<-prevalence(y)
    u<-rowSums(o[1:4,,2]);ch<-sum(o[2:3,7:60,])
    data.frame(month=z$months[j],prev_r=pr[1],prev_u=pr[2],urban_infection=u[1],
      urban_mild=u[2],urban_severe=u[3],urban_death=u[4],child_clinical=ch)
  }))
}
