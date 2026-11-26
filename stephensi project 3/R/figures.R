# Figures generated directly from newly calculated R results.
# All labels are black; line styles and symbols remain distinguishable in print.
make_figures <- function(out,full=TRUE) {
  fig<-file.path(out,'figures');dir.create(fig,showWarnings=FALSE)
  render<-function(name,width,height,draw) {
    for(kind in c('pdf','png')) {
      path<-file.path(fig,paste0(name,'.',kind))
      if(kind=='pdf')pdf(path,width=width,height=height,family='serif',useDingbats=FALSE)
      else png(path,width=width,height=height,units='in',res=300,type=if(capabilities('cairo'))'cairo' else getOption('bitmapType'))
      tryCatch({par(family='serif',col='black',col.axis='black',col.lab='black',col.main='black',
                    las=1,bty='l',cex=.95);draw()},finally=dev.off())
    }
  }
  render('schematic',10,5.3,function() {
    par(mar=c(0,0,0,0));plot.new();plot.window(c(0,10),c(0,5.3),xaxs='i',yaxs='i')
    box_state<-function(x,y,w,h,label){rect(x,y,x+w,y+h,col='gray97');text(x+w/2,y+h/2,label,cex=.9)}
    arrow<-function(x,y,u,v,label='',dy=.15){arrows(x,y,u,v,length=.07);text((x+u)/2,(y+v)/2+dy,label,cex=.75)}
    box_state(.1,2.5,1.35,.7,'Susceptible\nS');box_state(2.1,2.5,1.35,.7,'Exposed\nE')
    box_state(4.3,3.5,1.65,.7,'Untreated\ninfection I');box_state(4.3,1.5,1.65,.7,'Awaiting care\nW')
    box_state(6.6,1.5,1.35,.7,'Treated\nT');box_state(8.4,2.5,1.35,.7,'Recovered\nR')
    arrow(1.45,2.85,2.1,2.85,'Infection');arrow(3.45,3.05,4.3,3.8,'Onset',.2)
    arrow(3.45,2.65,4.3,1.9,'Care');arrow(5.95,1.85,6.6,1.85,'Delay')
    arrow(7.95,1.9,8.4,2.6,'Clearance',.2);arrow(5.95,3.8,8.4,3.1,'Clearance')
    lines(c(9.1,9.1,.75),c(3.2,4.7,4.7));arrows(.75,4.7,.75,3.2,length=.07)
    text(4.8,4.9,'Loss of temporary immunity',cex=.85)
    text(4.9,.6,'Native mosquitoes and urban invader interact with human infection\nVaccination reduces acquisition; control changes invader transmission\nOnset determines clinical episodes, severe episodes, deaths, costs and DALYs',cex=.85)
  })
  trajectories<-lapply(names(SCENARIOS),function(sid)read.csv(file.path(out,paste0('trajectory_reference_',sid,'.csv'))))
  names(trajectories)<-names(SCENARIOS)
  render('trajectories',10,4.5,function() {
    par(mfrow=c(1,2),mar=c(4.5,4.7,2,1))
    ltys<-c(3,3,2,2,1,1);cols<-rep(c('gray50','black'),3)
    ylim<-range(unlist(lapply(trajectories,function(x)x$prev_u*100)))
    ylim[2]<-ylim[2]+.18*diff(ylim)
    plot(0,0,type='n',xlim=c(0,10),ylim=ylim,xlab='Years',ylab='Urban child infection prevalence (%)',main='A. Conditional trajectories')
    for(j in 1:6)lines(trajectories[[j]]$month/12,trajectories[[j]]$prev_u*100,lty=ltys[j],col=cols[j],lwd=1.5)
    legend('topleft',legend=names(trajectories),lty=ltys,col=cols,ncol=3,bty='n',cex=.8)
    yy<-sapply(list(c('A','B'),c('C','D'),c('E','F')),function(pair)trajectories[[pair[1]]]$child_clinical-trajectories[[pair[2]]]$child_clinical)
    matplot(trajectories$A$month/12,yy,type='l',lty=c(3,2,1),lwd=1.5,col='black',xlab='Years',ylab='Child clinical episodes averted',main='B. Added vaccination benefit')
    legend('topleft',c('B versus A','D versus C','F versus E'),lty=c(3,2,1),bty='n',cex=.8)
  })
  render('frontier',7,4.7,function() {
    d<-read.csv(file.path(out,'economic_frontier.csv'),stringsAsFactors=FALSE)
    par(mar=c(4.7,4.9,1.5,1));plot(d$benefit,d$incremental_cost/1e6,pch=16,
      xlab='All-age DALYs averted versus C',ylab='Incremental cost (million 2020 US$)',
      xlim=c(-100,max(d$benefit)*1.08),ylim=c(-.05,max(d$incremental_cost)/1e6*1.1))
    text(d$benefit,d$incremental_cost/1e6,labels=d$scenario,pos=4)
    k<-d$status=='frontier';lines(d$benefit[k],d$incremental_cost[k]/1e6)
  })
  if(!full)return(invisible(fig))
  d<-read.csv(file.path(out,'density_curve.csv'))
  render('density',10,4.5,function() {
    par(mfrow=c(1,2),mar=c(4.7,4.7,1.7,1))
    labels<-c('Child clinical episodes averted','US$ per all-age DALY averted')
    for(j in 1:2) {
      key<-c('clinical_averted','icer')[j]
      plot(d$prev_u*100,d[[key]],type='l',lwd=1.5,
           xlab='Urban child infection prevalence (%)\nYear ten',ylab=labels[j])
      k<-which.min(abs(d$density-.7));points(d$prev_u[k]*100,d[[key]][k],pch=15)
      legend(if(j==1)'topright' else 'topleft','Reference density: 0.7',pch=15,bty='n',cex=.75)
    }
  })
  ref<-read.csv(file.path(out,'calibration_reference.csv'));lake<-read.csv(file.path(out,'calibration_lake.csv'))
  render('calibration',10,4.7,function() {
    par(mfrow=c(1,2),mar=c(4.7,4.5,2.4,1))
    obs<-list(c(3.8,1,10.5),c(6.8,2.5,18.9));lo<-list(c(2.7,.4,7.8),c(5.4,1.3,15.5))
    hi<-list(c(4.9,1.6,13.2),c(8.2,3.8,22.3))
    pred<-list(c(ref$fit_r/.959,ref$fit_u/.933,lake$fit_r/.955)*100,
               c(ref$broad_r,ref$broad_u,lake$broad_r)*100)
    for(j in 1:2) {
      x<-1:3;plot(x-.08,obs[[j]],pch=16,xaxt='n',xlim=c(.5,3.5),ylim=c(0,max(hi[[j]])*1.25),
        xlab='',ylab='All-species proxy prevalence (%)',
        main=c('A. Ages 6-59 months (fitted)','B. Ages 6-179 months (unfitted)')[j])
      arrows(x-.08,lo[[j]],x-.08,hi[[j]],angle=90,code=3,length=.05)
      points(x+.08,pred[[j]],pch=15,col='gray50');axis(1,at=x,labels=c('Rural','Urban','Lake-endemic'))
      legend('topleft',c('KMIS microscopy','Model observation proxy'),pch=c(16,15),col=c('black','gray50'),bty='n',cex=.75)
    }
  })
  d<-read.csv(file.path(out,'prcc.csv'),stringsAsFactors=FALSE)
  render('prcc',10,4.5,function() {
    par(mfrow=c(1,2),mar=c(4.5,7.8,2.3,1))
    for(j in 1:2) {
      z<-d[d$endpoint==c('episodes','icer')[j],]
      plot(z$prcc,4:1,pch=16,xlim=c(-1,1),ylim=c(.5,4.5),yaxt='n',ylab='',
        xlab='Partial rank correlation',main=c('Child clinical episodes averted','Vaccination ICER')[j])
      abline(v=0,col='gray60');arrows(z$lower,4:1,z$upper,4:1,angle=90,code=3,length=.04)
      axis(2,at=4:1,labels=c('Invader density','Protection multiplier','Biting multiplier','Mortality multiplier'),las=1,cex.axis=.85)
    }
  })
  invisible(fig)
}
