# Model specification

## Populations and states

The two populations are independent illustrative rural and urban settings. Each begins with 100,000 people. The first 60 age strata represent individual completed months from birth to 59 months; two further strata represent ages 5-14 and 15 years or older. Human states are susceptible (S), exposed (E), untreated infection (I), recovered (R), awaiting care (W) and treated infection (T). Dose number and protection component further subdivide each human state.

The native-vector system is present in both populations. Anopheles stephensi is introduced only in the urban population in scenarios C-F. Each vector system contains immature, susceptible adult, exposed adult and infectious adult states. Carrying capacities are fixed within each scenario. Vector density is not maintained at a constant ratio to the changing human population.

## Infection, treatment and outcome accounting

The human force of infection sums infectious bites from the two vector systems and weights exposure by age. The denominator is the age-weighted total human population. Mosquito infection depends on the weighted untreated and awaiting-care reservoir plus treated infection multiplied by its residual infectiousness.

Progression from E is the common event used to calculate clinical episodes, severe episodes and malaria deaths. The clinical fraction and severe fraction depend on age. Fatal infections leave the living population at progression. Surviving infections assigned to care enter W, or enter T directly when the assumed treatment delay is zero. W progresses to T and T clears to R. Untreated infection clears separately. Natural mortality applies in every human state.

The care-routing fraction excludes fatal severe infections. The care-assignment outcome and provider cost count admitted severe episodes, including those that end in death. Consequently, the `treated` output is not identical to the surviving flow into W or T.

The reference setting assumes complete temporary protection against reinfection in R. Partial or absent infection protection is examined through susceptibility multipliers of 0.5 and 1. Loss of temporary immunity returns R to S. Treatment duration, infectiousness, delay and care seeking are transferred parameters or assumptions; treatment success, gametocyte tails and post-treatment prophylaxis are not separately represented.

## Vaccination and monthly events

Births accumulate continuously and enter the susceptible neonatal stratum at the monthly boundary. The under-five population ages by one completed month at that boundary. Ages 5-14 leave their broad stratum continuously at a rate of one per ten years. Vaccination follows ageing, at 6, 7, 9 and 24 completed months. Receipt of dose d requires receipt of dose d-1. There is no catch-up or independent recruitment directly into later dose groups.

The reference marginal coverage proportions of 0.72, 0.66, 0.58 and 0.54 become conditional probabilities of 0.72, 0.66/0.72, 0.58/0.66 and 0.54/0.58. Deaths and age transitions mean observed dose totals during the finite follow-up need not reproduce these proportions exactly.

Protection reduces infection acquisition and does not directly modify clinical severity. Dose-3 and dose-4 protection use two exponentially waning components. The reference gives no acquisition protection after doses 1 or 2. Exploratory early-dose protection uses the dose-3 component weights and rates. Vaccination changes dose/protection membership while preserving infection status.

## Initialization and calibration

Each calibration begins with 3.5% of the population infected and the remainder susceptible, using the fixed age shares. Without vaccination or invader establishment, the system is integrated for 14 years. Human states are then rescaled within each age stratum to the specified initial age distribution, and native-vector abundance is rescaled to the candidate density. This is a fixed-duration initialization procedure, not a claim of endemic equilibrium.

Native-vector densities are fitted in log space to infection prevalence at ages 6-59 months. The reference targets are 0.038 multiplied by 0.959 and 0.010 multiplied by 0.933. Alternative microscopy sensitivities divide these targets. A damped Newton method is used; independent populations give a diagonal density-to-prevalence Jacobian. The fit is required to achieve an absolute prevalence discrepancy below 1e-6. The tighter optimizer convergence criterion is applied to scaled residuals.

The lake alternative replaces the first population's target by 0.105 multiplied by 0.955 and changes its care-seeking proxy to 0.567. The lower and upper lake targets use 0.078 and 0.132. The broader-age prevalence comparison is unfitted, but does not constitute independent clinical-outcome validation. The 28- and 56-year initialization analyses assess dependence on initial conditions.

Structural changes that affect pre-intervention dynamics are recalibrated. Vaccination-only changes, intervention costs, discount rates and follow-up horizons reuse the reference biological initial state. The urban prevalence-matched invasion alternative solves for an invader density giving an end-of-follow-up target of 0.105 multiplied by 0.955. This is a prevalence-matched scenario, not an observed urban invader density.

## Numerical integration

The implementation uses classical fourth-order Runge-Kutta integration. A year contains 365.25 days and a month contains 30.4375 days. Each reference month has 31 equal substeps; monthly events are applied exactly at the boundary. A second calculation halves the maximum permitted step for the convergence check. Non-finite values and materially negative biological states stop execution.

Unvaccinated simulations omit dose/protection cells that remain identically zero. Results are restored to the common full state layout before reporting. A run that would discard an existing vaccinated population is rejected.

## Economic evaluation

The provider/programme perspective includes vaccination, provider treatment and additional invader control. Costs are in 2020 US dollars. Reference delivered-dose costs are 9.01 for each of the first three doses and 9.71 for dose 4, including the specified historical acquisition-price assumption of 5 per dose. Acquisition-price changes use the increment `(price_dose - 5) * 1.076 / 0.9`. This is the manuscript costing scenario, not an estimate of current acquisition cost.

Provider costs apply to care-seeking uncomplicated episodes and admitted severe episodes. The reference control cost is 1.50 per urban resident-year and is charged once to the urban population. Cost is allocated to age groups using age-specific person-time. Control cost is not multiplied by the number of vaccine, protection or infection compartments.

The annual discount rate is 3% in the reference analysis. The event-time discount factor is `(1 + r)^(-t/365.25)`. Disability duration is expressed in years. Future life years lost are integrated using `log(1 + r)` as the continuous equivalent of the annual discount rate and then discounted to the event time. Remaining-life estimates are coarse age mappings and are tested in sensitivity analyses.

Principal ICERs use all-age health benefits and all-age costs within the same region. Child-only health ratios retain full regional programme costs and are reported separately. Counts per 1,000 completed courses summarise population-level effects per delivered course; they are not individual causal efficacy estimates. No willingness-to-pay threshold is used to declare an intervention cost-effective.

## Sensitivity and validation scope

The structural analysis examines treatment access, treatment delay, residual infectiousness, admission, immunity, early-dose protection, diagnosis, older-age clinical/severity/fatality mappings, initialization, biting weights, population growth, coverage, waning, follow-up horizon, treatment costs and remaining lifetime. Vaccine price, discount rates, invader density and control-price boundaries are also examined. The zero-natural-growth alternative sets births equal to natural deaths; malaria deaths can still reduce the population.

The global analysis uses a fixed 128-point Latin-hypercube design over invader density, vaccine-protection multiplier, invader-biting multiplier and adult-mortality multiplier. Partial rank correlations are calculated for child episodes averted and the vaccination ICER. Intervals are percentile intervals from 500 resamples of the design points, with one-based indices provided as input files. The first 64 points provide a sample-size diagnostic; they are not a separately stratified Latin hypercube. Partial rank correlations summarise associations over the selected design and should be interpreted alongside the density curve because non-monotonic responses can be incompletely represented. Bootstrap intervals describe resampling variation in these sensitivity summaries, not uncertainty in all model parameters.

The transported 30-fold incidence benchmark compares the urban clinical episode rate in year seven with and without establishment. It is a numerical transportability check rather than a fit to Kenyan or Djiboutian clinical records. The benchmark is not reached in the reference density-only scan.

Verification tests address numerical conservation, dose timing, clearance, step size, accounting identities, disease-free behaviour, model nesting and agreement with reference calculations. They do not resolve structural uncertainty or replace independent validation against observed clinical outcomes.
