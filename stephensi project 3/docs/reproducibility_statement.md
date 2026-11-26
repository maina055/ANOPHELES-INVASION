# Software and reproducibility

The model and analysis workflow were implemented in R version 4.5.0 using packages distributed with R. The code specifies the transmission equations, monthly vaccination and ageing events, fixed-step fourth-order Runge-Kutta integration, prevalence calibration, clinical and economic accounting, structural sensitivity analyses and figure generation. Fixed input and resampling tables permit reproduction without network access or patient-level data.

Numerical verification included conservation of population flows, scheduled dose administration, analytical treatment clearance, step-size convergence, cost and fatality accounting, disease-free behaviour and nesting of the earlier model structure. The native R results were compared with the reference manuscript calculations using explicit numerical tolerances. These checks establish numerical consistency; they do not establish independent clinical predictive validity.

The distributed files include source code, parameter values and provenance, fixed sensitivity designs, verification results, model outputs and R session information. The principal economic results use all-age costs and all-age DALYs; child-only health ratios retaining total regional costs are reported separately.
