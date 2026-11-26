# Numerical verification report

The full analysis completed in R 4.5.0 on Linux on 25 November 2026. It used eight workers and took 24.88 minutes on the verification machine. A separate run through the source() entry point completed in 3.33 minutes with one worker. Runtime depends on hardware and worker count.

## Completed calculations

The full run recalculated 45 model variants and generated 2,208 scenario summary rows. It includes the 21-point invader-density curve, control cost-effect boundaries, vaccine-price and discount alternatives, lake comparisons, the 25-point transported-incidence scan, and the 128-point global sensitivity design. Each sensitivity endpoint uses 500 fixed bootstrap resamples. Parameter and resampling tables are inputs; numerical comparison targets are read only after simulation.

## Verification results

| Verification category | Passed | Total |
| --- | ---: | ---: |
| Numerical model checks | 78 | 78 |
| Output accounting checks | 22 | 22 |
| Full-precision output comparisons | 99 | 99 |
| Reported manuscript values | 264 | 264 |
| Whole-trajectory population balances | 178 | 178 |

The largest scaled numerical comparison discrepancy was 4.7887285e-08. Scaling divides the absolute difference by the larger of one and the absolute comparison value. The principal small differences arise in the prevalence-matched urban alternative, where root-finding implementations differ. All 264 displayed manuscript values agree within their reporting precision.

The largest relative whole-trajectory population-balance residual was 4.3655746e-15. This check reconciles final human population size with the initial population, integrated births, natural deaths and malaria deaths for every saved intervention state.

The 78 numerical checks include 60 earlier-model nesting comparisons, two population-flow checks, analytical treatment clearance, five integration-step comparisons, two outcome-accounting identities, zero-protection and disease-free limits, five dose-scheduling checks and reference calibration. Six dose/calibration checks extend the 72-check set described in the manuscript.

Input checks confirmed array dimensions, parameter ranges, coverage conversion, inflation-adjusted costs, protection inputs, age exposure weights, Latin-hypercube stratification and bootstrap-index validity. Execution checks confirmed that non-empty output directories, changed inputs, changed run modes and missing comparison files are rejected as specified.

The independent reference-mode run passed 78 numerical checks, 18 output-accounting checks, 43 numerical-output comparisons, 87 manuscript-value comparisons and six whole-trajectory population balances. All six figure types were generated in R and inspected for readable labels and plotting consistency.

## Records and interpretation

The detailed full-run results are in [the computational verification summary](../results/verification_summary.md), with individual residuals and tolerances in the associated CSV files. The separate source-entry run is recorded in [its verification summary](../results/reference_run/verification_summary.md). Execution logs, R session information, calibration histories, fitted states, dose-specific results and source/input fingerprints are included.

These checks support numerical reproducibility and implementation consistency. They do not establish independent clinical predictive validity or identify the appropriate intervention for a particular Kenyan population. Model assumptions and transferred inputs remain explicit in [the assumptions register](assumptions.md). The software-description discrepancy in the supplied supplement is documented in [the manuscript alignment note](manuscript_alignment.md).

Execution was verified on Linux. The code uses packages distributed with R and PSOCK parallel workers; separate Windows and macOS executions have not been performed.
