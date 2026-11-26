# Inputs and outputs

## Input files

| File | Definition |
| --- | --- |
| `parameters.csv` | Named numeric arrays. The `index` column is one-based and determines array order. Parameter units and sources are in the parameter register. |
| `config.csv` | Reference intervention, transmission and economic settings. Native-density values are calibration starting values, not fitted estimates. |
| `extension_config.csv` | Treatment and immunity settings; these are applied after the base configuration. |
| `global_design_128.csv` | Fixed Latin-hypercube values for density, protection, biting and mortality multipliers. |
| `bootstrap_episodes_indices.csv` | A 500-by-128 table of one-based row indices for episode-endpoint resampling. |
| `bootstrap_icer_indices.csv` | A 500-by-128 table of one-based row indices for ICER-endpoint resampling. |
| `initial_state.csv.gz` | Earlier four-state model state, used only for the legacy nesting check. |
| `legacy_reference.csv` | Earlier model summaries, used only as regression-test expectations. |

The global design and the two bootstrap tables preserve the sampling design used for the manuscript calculations. Their random-generation seed was 20261119. Loading fixed design tables avoids differences between random-number generators. No patient-level data are included.

## Scenario tables

Rows are identified by `model`, `scenario`, `region` and `age`. Counts are expected model counts and may be non-integers. The two settings begin with 100,000 people each. Populations subsequently change through births, ageing and mortality.

| Column | Meaning |
| --- | --- |
| `infections` | Cumulative progression from exposed to blood-stage infection; includes asymptomatic infections. |
| `clinical` | Cumulative uncomplicated plus severe clinical malaria episodes. |
| `severe` | Cumulative severe episodes before applying admission probability. |
| `hospitalisations` | Severe episodes multiplied by admission probability. |
| `deaths` | Cumulative malaria-attributable deaths; excludes natural deaths. |
| `doses` | Undiscounted vaccine administrations. |
| `completed_courses` | Dose-4 administrations in the selected region over follow-up. This regional denominator is repeated across age-summary rows. |
| `discounted_doses` | Dose administrations weighted by the cost discount factor; used for economic accounting, not delivery counts. |
| `cost` | Discounted vaccination, provider treatment and additional control costs in 2020 US dollars. |
| `dalys` | Discounted years of life lost plus years lived with disability. |
| `person_years` | Integrated person-time in the selected region and age group. |
| `treated` | Clinical episodes assigned to the modelled care pathway, including admitted severe episodes; not the number alive in the treated-infection state. |
| `control_cost` | Discounted additional urban invader-control costs. |
| `treatment_cost` | Discounted provider costs for care-seeking uncomplicated episodes and admitted severe episodes. |
| `vaccine_cost` | Discounted delivered-dose costs. |
| `prev_r`, `prev_u` | End-of-follow-up infected fraction, ages 6-59 months, including untreated, awaiting-care and treated infection. |

The primary clinical comparison uses ages 6-59 completed months. The `all` category includes every represented age. Indices 0-59 are individual completed months; indices 60 and 61 represent ages 5-14 and 15 years or older. The `both` region sums the two populations. No individual moves between regions.

## Contrasts and economics

A contrast named `D-C` means intervention D compared with C. Averted outcomes equal comparator minus intervention. Incremental cost equals intervention minus comparator. ICER equals incremental cost divided by DALYs averted, and is left missing when DALYs averted are non-positive.

`cases_per_1000_courses` divides the population-level episodes averted in the selected age group by completed courses in the intervention population and multiplies by 1,000. The primary child result uses ages 6-59 months. It includes indirect population effects and is not an individual vaccine-effectiveness estimate. Control-only comparisons have no completed-course denominator.

`principal_economic_comparisons.csv` contains all-age comparisons. The raw age-specific cost columns allocate vaccination cost to dose age, provider cost to event age and control cost by age-specific person-time. These allocations are accounting diagnostics.

`child_outcomes_with_full_cost_ratio.csv` combines child DALYs with full regional incremental costs. Its `full_cost_per_child_daly` column must be used when restricting health benefit to children but retaining total programme costs.

`economic_frontier.csv` distinguishes strict dominance from extended dominance. Sequential ICERs are calculated only between adjacent strategies remaining on the frontier. Equal-ratio control-price boundaries do not establish strict dominance.

## Verification and reproducibility outputs

| File | Purpose |
| --- | --- |
| `verification.csv` | Check name, observed numerical discrepancy, tolerance and pass/fail result. |
| `reference_comparison.csv` | Scaled differences from reference manuscript calculations. |
| `calibration_history_*.csv` | Density evaluations and prevalence values during calibration. |
| `calibration_*.csv` | Targets, fitted densities, achieved prevalence and initialization duration. |
| `baseline_*.rds` | Newly calculated R calibration records and initial intervention states. |
| `states/final_*.rds` | Final full state vectors for reference and structural intervention runs. |
| `dose_deliveries_*.csv` | Separate dose-1 to dose-4 counts by scenario and population. |
| `tables/` | Numerical manuscript tables calculated from the current model results. |
| `output_integrity.csv` | Regional, age, cost, dose, bounds and analysis-completeness checks. |
| `reported_value_comparison.csv` | Agreement with values displayed in the manuscript, allowing only their stated rounding precision. |
| `source_input_checksums.csv` | MD5 fingerprints for detecting changes to source and input files. |
| `sessionInfo.txt` | R version, platform and attached packages. |
| `run_manifest.rds`, `run_status.txt` | Execution status, settings and timing. |

Figures are regenerated from newly calculated tables. Numerical comparison targets are used only after simulation.

The `verification_targets/reported_values.csv` file records manuscript table identifiers, row identifiers, variables, reported values and decimal places. It is used only for reporting-precision comparisons. The tolerance is half of the final reported decimal unit, plus 1e-8 for numerical arithmetic. These comparisons do not estimate empirical uncertainty.
