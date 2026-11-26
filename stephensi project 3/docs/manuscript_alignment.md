# Software and manuscript alignment

The analysis implements the six-state treated-infection model and the parameter settings described in the manuscript and its supplement. All transmission calculations, calibration, sensitivity analyses and graphics are performed in R. The numerical results are compared with both full-precision expectations and the reported precision of the manuscript tables.

## Software description

The software paragraphs in supplement section S9 describe an earlier execution pathway. For this implementation, the applicable description is:

The model and analyses were implemented in R 4.5.0 using packages distributed with R. Classical fourth-order Runge-Kutta integration used steps no longer than one day, aligned exactly with monthly ageing and vaccination events. Non-finite values and biological states below minus 1e-7 stopped execution. Calibration fitted native-vector densities to the specified prevalence targets. Fixed Latin-hypercube and bootstrap sampling tables were supplied with the analysis to preserve the manuscript sensitivity design.

## Verification count

The manuscript reports 72 numerical checks. This implementation includes those checks and six additional checks of vaccination timing and prevalence calibration, giving 78 numerical checks. Output-accounting checks and comparisons with reported values are separate verification categories; their totals are recorded in the execution report.

## Interpretation

Successful execution and numerical agreement support implementation consistency. They do not demonstrate endemic equilibrium, independent clinical prediction, measured intervention effects or a probability of cost-effectiveness. The assumed historical costs, transferred clinical mappings, illustrative invader densities and initialization dependence remain part of the interpretation.

## Source-document fingerprints

The reporting-precision expectations were transcribed from the following document versions. SHA-256 fingerprints identify their exact contents. The documents are not model inputs.

| Document | SHA-256 |
| --- | --- |
| Manuscript_Revised_Highlighted.docx | `41782a9f42b16e1527000749197a18c62eaf97edaf639219e92eb2fef28dfbad` |
| Additional_File_1_Supplement.docx | `b4967b226230e22b23ff1859fdca26587fae36147938fd4dc7ace2df33635004` |
