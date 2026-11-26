# Computational verification

Execution status: completed
Analysis mode: full
R: R version 4.5.0 (2025-04-11)
Workers: 8
Started: 2026-11-25 12:34:53.39321
Finished: 2026-11-25 12:59:46.420462
Elapsed minutes: 24.88

| Verification group | Passed | Total |
| --- | ---: | ---: |
| Numerical model checks | 78 | 78 |
| Output accounting checks | 22 | 22 |
| Full-precision output comparisons | 99 | 99 |
| Manuscript reporting-precision comparisons | 264 | 264 |
| Whole-trajectory population balances | 178 | 178 |

Model variants: 45
Scenario summary rows: 2208
Largest scaled numerical comparison discrepancy: 4.7887285e-08
Largest relative population balance residual: 4.3655746e-15

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
