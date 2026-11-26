# Input integrity checks. Run from the project directory:
# Rscript tests/input_audit.R
source('R/model.R')
i<-load_inputs(getwd());f<-i$f;cfg<-i$cfg
raw<-read.csv('data/parameters.csv',stringsAsFactors=FALSE)
stopifnot(!anyDuplicated(raw[,c('parameter','index')]))
for(g in split(raw,raw$parameter))stopifnot(identical(sort(g$index),seq_len(nrow(g))))
expected<-c(MU=1,BIRTH=1,NU_H=1,GAMMA=1,RHO=1,ECL=2,ETA=2,PHI=2,DV=2,
 SIGV=2,B=2,C=2,BITES_G=2,BITES_T=2,PCLIN=62,PSEV=62,PDEATH_SEV=62,
 DW_MOD=1,DW_SEV=1,DUR_MOD=1,DUR_SEV=1,LIFE_REMAIN=62,COST_UNCOMPL=1,
 COST_SEV=1,DOSE_ATTEMPT=4,PROFILE_E=5,PROFILE_W=5,PROFILE_RATE=10,
 BITE_WEIGHT=62,AGE_SHARES=62,AGE_REP=62,PRICE_DOSE=1,COST_CONTROL_URBAN=1,DISCOUNT=1)
stopifnot(all(names(expected)%in%names(f)))
for(k in names(expected))stopifnot(length(f[[k]])==expected[[k]],all(is.finite(f[[k]])))
positive<-c('MU','BIRTH','NU_H','GAMMA','ECL','ETA','PHI','DV','SIGV',
            'BITE_WEIGHT','LIFE_REMAIN','DUR_MOD','DUR_SEV')
stopifnot(all(unlist(f[positive])>0),all(f$RHO>=0),
          all(f$AGE_SHARES>0),abs(sum(f$AGE_SHARES)-1)<1e-10)
probs<-c('B','C','PCLIN','PSEV','PDEATH_SEV','DOSE_ATTEMPT','PROFILE_E','PROFILE_W')
stopifnot(all(unlist(f[probs])>=0),all(unlist(f[probs])<=1))
stopifnot(all(f$PROFILE_RATE>=0),all(f$COST_UNCOMPL>=0),all(f$COST_SEV>=0))
stopifnot(max(abs(cumprod(f$DOSE_ATTEMPT)-c(.72,.66,.58,.54)))<1e-12)
stopifnot(abs(cfg$txinfect-.0219/.068)<1e-14,all(f$PDEATH_SEV==.07),
          abs(f$DUR_MOD*365.25-4.8)<1e-10,abs(f$DUR_SEV*365.25-8.75)<1e-10)
stopifnot(abs(f$COST_UNCOMPL-2.77*258.811/214.537)<1e-10,
          abs(f$COST_SEV-20.86*258.811/214.537)<1e-10)
stopifnot(abs(f$PROFILE_E[4]-.93*(1-1/(1+(593/99.2)^.74)))<1e-12,
          abs(f$PROFILE_E[5]-.93*(1-1/(1+(231/99.2)^.74)))<1e-12)
stopifnot(all(f$PHI*f$ETA/(f$DV*(f$ETA+f$ECL))>1))
stopifnot(max(abs(f$BITE_WEIGHT-(1-.85*exp(-f$AGE_REP/8))))<1e-12)
stopifnot(abs(cfg$price_dose-f$PRICE_DOSE)<1e-12,
          abs(cfg$control_cost-f$COST_CONTROL_URBAN)<1e-12,
          abs(cfg$discount-f$DISCOUNT)<1e-12)
validate_inputs(initial_state(cfg,f),f,cfg,10,1)
design<-read.csv('data/global_design_128.csv')
labels<-c('density','protection','biting','mortality')
stopifnot(nrow(design)==128L,all(labels%in%names(design)))
lower<-c(.2,.75,.7,.75);upper<-c(1.2,1.25,1.3,1.25)
for(j in seq_along(labels)) {
  u<-(design[[labels[j]]]-lower[j])/(upper[j]-lower[j])
  stopifnot(all(is.finite(u)),all(u>=0 & u<1),
            identical(sort(as.integer(floor(128*u))),0:127))
}
for(endpoint in c('episodes','icer')) {
  indices<-as.matrix(read.csv(paste0('data/bootstrap_',endpoint,'_indices.csv'),header=FALSE))
  stopifnot(identical(dim(indices),c(500L,128L)),all(is.finite(indices)),
            all(indices==floor(indices)),all(indices>=1 & indices<=128))
}
cat('Input integrity audit passed.\n')
