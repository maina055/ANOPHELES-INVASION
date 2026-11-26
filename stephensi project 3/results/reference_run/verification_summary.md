# Computational verification

Execution status: completed
Analysis mode: reference
R: R version 4.5.0 (2025-04-11)
Workers: 1
Started: 2026-11-25 12:48:32.814054
Finished: 2026-11-25 12:51:52.458457
Elapsed minutes: 3.33

| Verification group | Passed | Total |
| --- | ---: | ---: |
| Numerical model checks | 78 | 78 |
| Output accounting checks | 18 | 18 |
| Full-precision output comparisons | 43 | 43 |
| Manuscript reporting-precision comparisons | 87 | 87 |
| Whole-trajectory population balances | 6 | 6 |

Model variants: 1
Scenario summary rows: 72
Largest scaled numerical comparison discrepancy: 7.294491e-12
Largest relative population balance residual: 2.3283064e-15

## Reference comparisons

| Comparison | Child clinical episodes averted | All-age US$ per DALY averted |
| --- | ---: | ---: |
| B-A | 1651.183059 | 10869.746729 |
| D-C | 5162.578546 | 4507.116413 |
| E-C | 30447.499734 | 269.149964 |
| F-E | 5590.021317 | 3991.266258 |

## Interpretation

These checks assess numerical consistency and agreement with the reported calculations. Independent clinical predictive validation has not been established. Economic values retain the historical 2020 US-dollar convention. Assumptions and input transfers remain applicable.

Source and input fingerprints are recorded in source_input_checksums.csv. Detailed discrepancies and tolerances are retained in the individual verification tables.
