# Anopheles stephensi vaccination and vector-control model

Reproducible R analysis accompanying:

Projected Impact and Cost-Effectiveness of Malaria Vaccination and Vector Control Under Hypothetical Anopheles stephensi Establishment in Kenya: A Mathematical Modelling Study

The analysis represents two illustrative populations and six intervention scenarios. It includes treatment pathways, age-dependent exposure, routine malaria vaccination, vector control, clinical outcomes and economic evaluation. The results are conditional scenarios; matching prevalence targets and reproducing numerical outputs do not establish clinical predictive validity.

## Requirements

R 4.5.0 was used for verification. Only packages distributed with R are required: base, stats, utils, graphics, grDevices, compiler, tools and parallel. No package installation or network access is required during a run. RStudio is optional. The scripts contain the model equations, integration, calibration and analysis directly in R.

## Run the complete analysis

Extract the files into one folder. Open `stephensi.Rproj`, or set the R working directory to that folder. Run:

```r
source("run_analysis.R")
```

This starts the full analysis with one worker. For two workers, or to set other options:

```r
options(stephensi.autorun = FALSE)
source("run_analysis.R")
run_analysis(mode = "full", workers = 2)
```

From a terminal:

```sh
Rscript run_analysis.R --mode full --workers 2
```

Each run writes to a new directory under `runs/`. A full run includes repeated calibration and hundreds of trajectories; allow substantial computation time, particularly with one worker. Progress is printed during execution.

For the reference calibration, all six intervention scenarios, verification checks and three figures:

```r
options(stephensi.autorun = FALSE)
source("run_analysis.R")
run_analysis(mode = "reference", workers = 1)
```

To resume an interrupted run, supply its existing output directory:

```r
run_analysis(mode = "full", workers = 2,
             out = "runs/full_analysis", resume = TRUE)
```

Replace the example directory with the actual run directory. Resumption is permitted only when analysis source, input and comparison-target files have unchanged checksums and the run mode is unchanged. Start a new run after editing model code or inputs. A completed run has `Status: completed` in `run_status.txt`. Failures stop execution and are recorded; partial output must not be interpreted as a completed analysis.

## File organisation

| Path | Contents |
| --- | --- |
| `run_analysis.R` | Analysis entry point, execution order, run records and resumption guard |
| `R/model.R` | State structure, equations, monthly events, RK4 integration, calibration and outcome summaries |
| `R/analysis.R` | Intervention comparisons, structural analyses, economic analyses, global sensitivity and aggregation |
| `R/checks.R` | Numerical checks and comparison with manuscript calculations |
| `R/reporting.R` | Output accounting checks, manuscript tables and reporting-precision comparisons |
| `R/figures.R` | Six figures in PDF and 300-dpi PNG formats |
| `data/` | Exact parameter values, sampling designs and regression-test inputs |
| `docs/` | Model specification, input provenance, output definitions and verification report |
| `verification_targets/` | Numerical expectations used only for comparison after simulation |
| `results/` | Verified tables, diagnostics, figures and execution record |
| `tests/run_reference.R` | Executable reference analysis and numerical checks |
| `tests/run_all.R` | Input, execution, numerical-output, reporting and saved-state checks |
| `tests/input_audit.R` | Input dimensions, probability ranges, coverage, costs and protection checks |
| `tests/run_guard_checks.R` | Non-empty-output and changed-input resumption safeguards |
| `tests/check_results.R` | Check the supplied results against the manuscript and accounting identities |
| `tests/check_comparisons.R` | Check that missing comparison files are rejected |
| `tests/check_files.R` | Verify the supplied file inventory and MD5 fingerprints |
| `tests/check_state_balance.R` | Check whole-trajectory human population balance using the saved states |
| `stephensi.Rproj` | RStudio project settings |

The fixed vaccine-mixture coefficients are the manuscript approximation inputs; the transmission calibration estimates native-vector densities. The distributed `results/` folder contains the complete executed analysis, including calibration records, final intervention states, dose-specific counts, tables and figures. New executions and resumable checkpoints are written under `runs/`. The `verification_targets/` directory is read only by the comparison functions after simulation. Its values never determine calibrated parameters or simulated outcomes. The legacy initial-state file is used only to test nesting of the earlier four-state model. Reference and sensitivity calibrations begin from the specified 3.5% infection seed.

## Calculation sequence

1. Read and validate the fixed parameters and configuration.
2. Construct the two initial populations and calibrate native-vector densities to the reference prevalence targets.
3. Run the six intervention scenarios over ten years.
4. Recalibrate where a sensitivity change affects pre-intervention dynamics, and run the corresponding structural alternatives.
5. Calculate the invader-density curve, control-cost boundaries, economic alternatives, lake comparisons and transported incidence benchmark.
6. Evaluate the fixed 128-point global sensitivity design and 500 bootstrap resamples per endpoint.
7. Calculate clinical and economic contrasts, including the incremental efficiency frontier.
8. Run numerical and accounting checks, calculate the manuscript tables, compare numerical and rounded reporting values, generate figures and record the R session and input checksums.

For a separate input-integrity check, run `Rscript tests/input_audit.R` from the project directory.

To check the supplied results without repeating the integrations, run:

```sh
Rscript tests/run_all.R
```

This checks existing calculations; it is separate from a complete model rerun.
The results of these checks are summarised in `results/verification_summary.md`.

Before editing files or rerunning the checks, `Rscript tests/check_files.R` verifies that the supplied files match `CHECKSUMS.csv`. The file fingerprints detect accidental changes; they do not establish scientific validity.

## Tables and figures

`results/tables/` contains the numerical values for main Tables 1-4, supplementary Tables S4-S10 and selected results stated in the text. Values retain computational precision. Display rounding is tested separately against the corresponding manuscript entries. Input Tables S1-S3 are documented by the exact parameter files and input registers in `docs/`.

The figure mapping is: Figure 1, `schematic`; Figure 2, `trajectories`; Figure 3, `density`; Figure 4, `frontier`; Figure S1, `calibration`; Figure S2, `prcc`. Each is available in PDF and PNG under `results/figures/`. `docs/output_map.csv` links manuscript items to their generating functions and output files.

`results/reference_run/` contains an additional independently executed reference-mode run through the `source()` entry point. The main full analysis is stored directly under `results/`.

The fixed seed 20261119 identifies the original sampling design and bootstrap indices. The supplied sampling tables are read directly. Calibration and integration are deterministic, and no new random draws are needed to reproduce the supplied analysis.

## Intervention scenarios

| Scenario | Invader established in urban population | Vaccination | Additional invader control |
| --- | --- | --- | --- |
| A | No | No | No |
| B | No | Yes | No |
| C | Yes | No | No |
| D | Yes | Yes | No |
| E | Yes | No | Yes |
| F | Yes | Yes | Yes |

Vaccination is scheduled at 6, 7, 9 and 24 completed months. There is no catch-up mechanism. Primary clinical summaries cover children aged 6-59 completed months; additional summaries cover 6-23 months, 24-59 months and all ages. The dose-4 count measures completed courses delivered during follow-up.

Principal economic comparisons use all-age costs and all-age DALYs within the same region. The main pooled results use `region = both` and `age = all`. The lake-only comparison uses `model = lake`, `region = rural` and `age = all`; in that alternative, the first population is calibrated to the lake-endemic target. Child-only health ratios retain total regional incremental costs in a separate output file.

## Expected reference results

| Contrast | Clinical episodes averted at ages 6-59 months | All-age incremental US$ per DALY averted |
| --- | ---: | ---: |
| B versus A | 1651.183059 | 10869.746729 |
| D versus C | 5162.578546 | 4507.116413 |
| E versus C | 30447.499734 | 269.149964 |
| F versus E | 5590.021317 | 3991.266258 |

The fitted native-vector density parameters are approximately 0.0795756258 and 0.1242386836 in the reference populations. These are calibrated model parameters, not measured mosquito densities. Comparisons use numerical tolerances because arithmetic and root-finding may differ slightly across platforms.

Counts, clinical episodes, deaths and delivered doses are undiscounted. Costs and DALYs use the specified discount rate. Costs are historical 2020 US dollars. Vaccine acquisition and delivery costs are modelling inputs from the cited costing scenario, not current procurement quotations.

## Interpretation

The global analysis assesses four selected inputs using partial rank correlations. It is not a complete probabilistic cost-effectiveness analysis or a probability that an intervention is cost-effective. Care seeking, several age mappings, vaccine-response transfer, control effects and transmission settings remain assumptions. Initialization duration materially affects some results. The transported 30-fold incidence benchmark is not fitted by the density-only analysis.

Parameter sources and assumptions are documented in `docs/parameter_register.csv`, `docs/configuration_register.csv`, `docs/implementation_constants.csv`, `docs/evidence_register.csv` and `docs/model_specification.md`. Exact structural sensitivity settings are recorded in `docs/sensitivity_register.csv`. Numerical verification and limits of validation are described in `docs/verification_report.md`.
