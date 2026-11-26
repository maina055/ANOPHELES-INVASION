# Code structure and execution flow

## Model functions

| Function | Responsibility |
| --- | --- |
| `load_inputs()` | Read named arrays and apply the reference treatment configuration. |
| `validate_inputs()` | Check state dimensions, probability bounds, vaccine waning rates and permissible switches. |
| `make_context()` | Precompute coefficients and indices for one trajectory, including discounted remaining life and vaccine component rates. |
| `rhs()` | Calculate continuous human, mosquito and outcome derivatives. |
| `boundary()` | Apply monthly ageing, accumulated births and scheduled vaccination. |
| `run_model()` | Integrate with RK4, check state validity and optionally retain monthly states. |
| `initial_state()` | Construct the specified pre-calibration seed. |
| `baseline()` | Integrate for the specified initialization duration and rescale the biological state. |
| `calibrate()` | Fit the two native-vector densities and record target discrepancies. |
| `scenario()` | Apply intervention settings and seed the invader when required. |
| `summary_state()` | Aggregate cumulative outcomes by region and age. |
| `contrasts()` | Calculate averted outcomes, incremental costs, ICERs and course-standardised benefits. |

## State layout

`unpack()` represents humans as an array with dimensions 6 states, 3 protection components, 5 dose categories, 62 age strata and 2 populations. The first dimension varies fastest. R indices are one-based; the indexing helper functions accept the scientific zero-based labels specified at the top of `model.R` and return R indices.

The `make_context()` object uses `nq` for the number of combined dose/protection cells per age and population: 15 during vaccination, and one when vaccination is disabled. `n` is the number of human cells before multiplying by six infection states. `nh` is the number of active human scalar states. The compact integration state is expanded to the common 13,036-element state layout for output.

The full state contains 11,160 human states, 16 mosquito states and 1,860 cumulative outcome/birth-accounting entries. Mosquito states are stored as 4 states by 2 vector systems by 2 populations. Outcome accounting uses 15 entries by 62 age strata by 2 populations.

## Analysis functions

`run_variant()` creates a calibrated baseline or reuses the reference baseline when appropriate. `structural_job()` and `extra_job()` define the prespecified model alternatives. `density_job()` evaluates a single invader-density comparison. `benchmark_analyses()` handles lake-envelope, prevalence-matching, species-fraction and transported-incidence comparisons.

`control_boundaries()` separates control effect from its assumed price. `economic_analyses()` varies vaccine acquisition price and discounting. `global_analysis()` reruns the complete model for each sensitivity-design point, then calculates partial rank correlations with the fixed bootstrap tables. `aggregate_results()` enforces unique scenario keys and creates the principal economic outputs.

`verify_model()` performs numerical and structural regression checks. `verify_output_integrity()` checks outcome bounds, regional and age-group accounting, costs, dose counts and required analyses. `compare_reference()` compares calculated tables with numerical expectations. `export_manuscript_tables()` derives reportable tables from the current results; `compare_reported_values()` checks them against manuscript rounding precision. Missing comparison inputs or calculated tables stop execution. `make_figures()` draws figures from newly calculated results. `run_analysis()` calls these functions in their required order and records execution status.

## Editing and rerunning

Reference fixed values are stored in `data/parameters.csv`; configuration values are in `data/config.csv` and `data/extension_config.csv`. Prespecified sensitivity alternatives are defined in `R/analysis.R`. A new run is required after changing these files or the model equations. Numerical comparisons identify departures from the manuscript calculations.

For methodological extensions, the runner can be loaded without automatic execution and the comparison step disabled explicitly:

```r
options(stephensi.autorun = FALSE)
source("run_analysis.R")
run_analysis(mode = "full", workers = 2, compare = FALSE)
```

The numerical checks still run. Some checks encode reference assumptions, such as the 7% severe fatality mapping and the reference prevalence targets; these should remain unchanged for manuscript reproduction. A distinct methodological extension requires its own scientifically justified verification expectations.
