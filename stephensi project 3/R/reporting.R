# Output integrity and tables linked to the manuscript.
# All numerical table entries are derived from the current simulation outputs.

verify_output_integrity <- function(out, full=TRUE) {
  d <- read.csv(file.path(out, 'scenarios_complete.csv'), stringsAsFactors=FALSE)
  records <- list()
  check <- function(name, discrepancy, tolerance=1e-9) {
    pass <- length(discrepancy)==1L && is.finite(discrepancy) && abs(discrepancy)<=tolerance
    records[[length(records)+1L]] <<- data.frame(check=name, value=discrepancy,
                                               tolerance=tolerance, passed=pass)
    write_result(do.call(rbind, records), 'output_integrity', out)
    if(!pass) stop('Output integrity check failed: ', name)
  }
  scaled <- function(a,b) max(abs(a-b)/pmax(1,abs(b)))
  numeric_values <- as.matrix(d[,vapply(d,is.numeric,FALSE),drop=FALSE])
  check('finite_scenario_values', sum(!is.finite(numeric_values)), 0)
  check('unique_scenario_rows', anyDuplicated(d[,c('model','scenario','region','age')]), 0)
  check('nonnegative_scenario_values', max(0,-min(numeric_values)), 1e-7)
  check('clinical_within_infection_onsets', max(0,max(d$clinical-d$infections)), 1e-7)
  check('severe_within_clinical', max(0,max(d$severe-d$clinical)), 1e-7)
  check('admissions_within_severe', max(0,max(d$hospitalisations-d$severe)), 1e-7)
  check('deaths_within_severe', max(0,max(d$deaths-d$severe)), 1e-7)
  check('prevalence_within_probability_bounds', max(0,max(c(d$prev_r,d$prev_u))-1), 1e-12)
  check('scenario_cost_decomposition', scaled(d$cost,d$control_cost+d$treatment_cost+d$vaccine_cost))
  cols <- c('infections','clinical','severe','deaths','doses','cost','dalys',
            'discounted_doses','person_years','hospitalisations','treated',
            'control_cost','treatment_cost','vaccine_cost')
  age_err <- region_err <- 0
  for(g in split(d,interaction(d$model,d$scenario,d$region,drop=TRUE))) {
    total <- as.numeric(g[g$age=='6-59',cols])
    parts <- colSums(g[g$age%in%c('6-23','24-59'),cols,drop=FALSE])
    age_err <- max(age_err,scaled(total,parts))
  }
  for(g in split(d,interaction(d$model,d$scenario,d$age,drop=TRUE))) {
    cc <- c(cols,'completed_courses')
    total <- as.numeric(g[g$region=='both',cc])
    parts <- colSums(g[g$region%in%c('rural','urban'),cc,drop=FALSE])
    region_err <- max(region_err,scaled(total,parts))
  }
  check('age_group_additivity',age_err)
  check('population_additivity',region_err)
  unvaccinated <- d$scenario%in%c('A','C','E')
  check('unvaccinated_doses_and_costs',max(abs(c(d$doses[unvaccinated],d$vaccine_cost[unvaccinated]))),1e-10)
  check('control_absent_in_A_to_D',max(abs(d$control_cost[d$scenario%in%c('A','B','C','D')])),1e-10)
  check('courses_within_all_age_doses',max(0,max(subset(d,age=='all')$completed_courses-subset(d,age=='all')$doses)),1e-10)
  cal_paths <- list.files(out,pattern='^calibration_.*[.]csv$',full.names=TRUE)
  cal_paths <- cal_paths[!grepl('calibration_history_',basename(cal_paths),fixed=TRUE)]
  calibration_errors <- vapply(cal_paths,function(p)read.csv(p)$max_residual,0.)
  check('all_calibration_targets',max(calibration_errors),1e-6)
  dose_paths <- list.files(out,pattern='^dose_deliveries_.*[.]csv$',full.names=TRUE)
  dose_err <- course_err <- 0
  for(p in dose_paths) {
    z <- read.csv(p,stringsAsFactors=FALSE)
    all_age <- subset(d,age=='all')
    key <- function(x)paste(x$model,x$scenario,x$region,sep='|')
    ix <- match(key(z),key(all_age));stopifnot(!anyNA(ix))
    dose_err <- max(dose_err,scaled(z$all_doses,all_age$doses[ix]))
    course_err <- max(course_err,scaled(z$dose4,all_age$completed_courses[ix]))
  }
  check('dose_specific_totals',dose_err)
  check('dose_four_equals_courses',course_err)
  expected_models <- if(full)c('reference',STRUCTURAL_TAGS,EXTRA_TAGS,
                              'lake_lower','lake_upper','species_under5','lake_matched_urban') else 'reference'
  check('required_model_variants',length(setdiff(expected_models,unique(d$model))),0)
  if(full) {
    global <- read.csv(file.path(out,'global_128.csv'))
    check('global_design_size',abs(nrow(global)-128L),0)
    check('global_sample_identifiers',as.integer(!identical(sort(global$sample),0:127)),0)
    check('density_curve_size',abs(nrow(read.csv(file.path(out,'density_curve.csv')))-21L),0)
    check('transported_benchmark_scan_size',abs(nrow(read.csv(file.path(out,'external_benchmark_scan.csv')))-25L),0)
  }
  message('Passed ',length(records),' output-integrity checks')
  invisible(do.call(rbind,records))
}

export_manuscript_tables <- function(out, root, full=TRUE) {
  tab <- file.path(out,'tables');dir.create(tab,showWarnings=FALSE)
  write_table <- function(x,name) write_result(x,name,tab)
  d <- read.csv(file.path(out,'scenarios_complete.csv'),stringsAsFactors=FALSE)
  co <- read.csv(file.path(out,'contrasts_complete.csv'),stringsAsFactors=FALSE)
  write_table(data.frame(row_id=names(SCENARIOS),establishment=c('No','No',rep('Urban',4)),
    vaccination=c('No','Yes','No','Yes','No','Yes'),
    invader_control=c(rep('No',4),'Yes','Yes')),'Main_Table_1')
  z <- subset(d,model=='reference' & region=='both' & age=='6-59')
  write_table(data.frame(row_id=z$scenario,z[,c('clinical','severe','hospitalisations','deaths','dalys')]),'Main_Table_2')
  z <- subset(co,model=='reference' & region=='both' & age=='6-59' & contrast%in%c('B-A','D-C','F-E'))
  write_table(data.frame(row_id=z$contrast,z[,c('clinical_averted','hospitalisations_averted',
    'deaths_averted','dalys_averted','cases_per_1000_courses')]),'Main_Table_3')
  z <- subset(co,model=='reference' & region=='both' & age=='all' & contrast%in%c('D-C','E-C','F-E','F-C'))
  write_table(data.frame(row_id=z$contrast,z[,c('incremental_cost','dalys_averted','icer')]),'Main_Table_4')
  z <- subset(co,model=='reference' & region=='both' & age%in%c('6-23','24-59') & contrast%in%c('B-A','D-C','F-E'))
  write_table(data.frame(row_id=paste(z$contrast,z$age,sep='/'),z[,c('clinical_averted',
    'hospitalisations_averted','deaths_averted','dalys_averted')]),'Table_S5')
  z <- read.csv(file.path(out,'dose_deliveries_reference.csv'),stringsAsFactors=FALSE)
  z <- subset(z,region=='both' & scenario%in%c('B','D','F'))
  write_table(data.frame(row_id=z$scenario,z[,c('dose1','dose2','dose3','dose4','all_doses')]),'Table_S6')
  v <- read.csv(file.path(out,'verification.csv'),stringsAsFactors=FALSE)
  write_table(data.frame(row_id=v$check,v[,c('value','tolerance','passed')]),'Table_S10')
  if(!full)return(invisible(tab))
  ref <- read.csv(file.path(out,'calibration_reference.csv'))
  lake <- read.csv(file.path(out,'calibration_lake.csv'))
  write_table(data.frame(row_id=c('Rural 6-59','Urban 6-59','Lake 6-59',
     'Rural 6-179','Urban 6-179','Lake 6-179'),
     observed_percent=c(3.8,1,10.5,6.8,2.5,18.9),
     survey_lower=c(2.7,.4,7.8,5.4,1.3,15.5),survey_upper=c(4.9,1.6,13.2,8.2,3.8,22.3),
     model_proxy_percent=100*c(ref$fit_r/.959,ref$fit_u/.933,lake$fit_r/.955,
                              ref$broad_r,ref$broad_u,lake$broad_r)), 'Table_S4')
  co_all <- rbind(co,read.csv(file.path(out,'economic_contrasts.csv'),stringsAsFactors=FALSE))
  sensitivity <- function(tags,name) {
    ch <- subset(co_all,region=='both' & age=='6-59' & contrast=='D-C')
    ec <- subset(co_all,region=='both' & age=='all' & contrast=='D-C')
    a <- match(tags,ch$model);b <- match(tags,ec$model);stopifnot(!anyNA(a),!anyNA(b))
    write_table(data.frame(row_id=tags,clinical_averted=ch$clinical_averted[a],
                dalys_averted=ec$dalys_averted[b],icer=ec$icer[b]),name)
  }
  sensitivity(c('reference','lake','partial_immunity','no_infection_immunity','early_low','early_high',
    'diagnostic_80','diagnostic_60','older_clinical_low','older_clinical_high','older_mortality_low',
    'older_mortality_high','older_severity_low','older_severity_high','init28','init56','care_half',
    'care_full','delay_zero','delay_four','txinfect_zero','txinfect_full','admission_half','combined',
    'species_under5','lake_matched_urban','equal_biting','zero_natural_growth'),'Table_S7')
  sensitivity(c('severity_low','severity_high','fatality_low','fatality_high','protection_low',
    'protection_high','waning_slow','waning_fast','coverage_observed','horizon5','horizon20',
    'treatment_cost_low','treatment_cost_high','adult_lifetime_low','adult_lifetime_high',
    'price2','price10','discount0','discount5'),'Table_S8')
  z <- read.csv(file.path(out,'control_boundaries.csv'))
  write_table(data.frame(row_id=c('0','1/3','2/3','1','4/3'),z),'Table_S9')
  metrics <- list()
  add <- function(id,value) metrics[[length(metrics)+1L]] <<- data.frame(row_id=id,value=value)
  ch <- subset(co,model=='reference' & region=='both' & age=='6-59')
  ec <- subset(co,model=='reference' & region=='both' & age=='all')
  add('additional_child_episodes_averted',ch$clinical_averted[ch$contrast=='D-C']-ch$clinical_averted[ch$contrast=='B-A'])
  add('vaccination_icer_without_establishment',ec$icer[ec$contrast=='B-A'])
  add('control_minus_vaccination_cost',ec$incremental_cost[ec$contrast=='E-C']-ec$incremental_cost[ec$contrast=='D-C'])
  for(pair in c('B-A','D-C','F-E'))add(paste0('cases_per_1000_courses_',pair),ch$cases_per_1000_courses[ch$contrast==pair])
  for(tag in c('lake','lake_lower','lake_upper')) {
    z <- subset(co,model==tag & region=='rural' & contrast=='B-A')
    add(paste0(tag,'_icer'),z$icer[z$age=='all'])
    add(paste0(tag,'_child_episodes_averted'),z$clinical_averted[z$age=='6-59'])
  }
  z <- read.csv(file.path(out,'density_curve.csv'))
  for(density in c(.2,1.2)) {
    row <- z[which.min(abs(z$density-density)),]
    add(paste0('density_',density,'_prevalence_percent'),100*row$prev_u)
    add(paste0('density_',density,'_child_episodes_averted'),row$clinical_averted)
  }
  add('maximum_transported_rate_ratio',max(read.csv(file.path(out,'external_benchmark_scan.csv'))$rate_ratio))
  add('urban_prevalence_matched_density',read.csv(file.path(out,'prevalence_match.csv'))$density)
  write_table(do.call(rbind,metrics),'Narrative_results')
  invisible(tab)
}

# Reported manuscript values are comparison targets only; they never enter the model.
compare_reported_values <- function(out, root, full=TRUE) {
  expected <- read.csv(file.path(root,'verification_targets','reported_values.csv'),stringsAsFactors=FALSE)
  if(!full)expected <- expected[expected$table%in%c('Main_Table_2','Main_Table_3','Main_Table_4','Table_S5','Table_S6'),]
  tables <- lapply(unique(expected$table),function(n)read.csv(file.path(out,'tables',paste0(n,'.csv')),stringsAsFactors=FALSE))
  names(tables) <- unique(expected$table)
  actual <- vapply(seq_len(nrow(expected)),function(i) {
    e <- expected[i,];d <- tables[[e$table]];row <- match(e$row_id,d$row_id)
    if(is.na(row)||!e$variable%in%names(d))stop('Missing manuscript table entry: ',e$table,' / ',e$row_id,' / ',e$variable)
    d[[e$variable]][row]
  },0.)
  tolerance <- .5*10^(-expected$decimal_places)+1e-8
  expected$calculated_value <- actual
  expected$absolute_difference <- abs(actual-expected$reported_value)
  expected$tolerance <- tolerance
  expected$passed <- is.finite(actual) & expected$absolute_difference<=tolerance
  write_result(expected,'reported_value_comparison',out)
  if(!all(expected$passed))stop('A manuscript value differs beyond its reporting precision; inspect reported_value_comparison.csv')
  message('Passed ',nrow(expected),' manuscript reporting-precision comparisons')
  invisible(expected)
}
