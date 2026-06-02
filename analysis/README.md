# Analysis Pipeline

This directory contains the scripts that reproduce the article's reported models, robustness checks, figures, and appendix tables.

## R Packages

Install the following R packages before running the pipeline:

```r
install.packages(c(
  "broom",
  "cowplot",
  "dplyr",
  "fixest",
  "forcats",
  "ggplot2",
  "kableExtra",
  "metafor",
  "modelsummary",
  "purrr",
  "RColorBrewer",
  "readr",
  "stringr",
  "tibble",
  "tidyr",
  "tidylog"
))
```

## Run Order

From the repository root, run:

```bash
Rscript analysis/run_all.R
```

This executes:

1. `01_clean_posthog_UK.R`
2. `02_clean_posthog_US.R`
3. `03_clean_posthog_US-2.R`
4. `04_clean_posthog-US-3.R`
5. `11_combined_analysis.R`
6. `12_combined_analysis_attention.R`
7. `13_combined_analysis_zeros.R`
8. `14_combined_analysis_zeros_attention.R`
9. `21_user_comparisons.R`

## Inputs

The scripts read study data from:

- `analysis/data/UK/main/`
- `analysis/data/US/main/`
- `analysis/data/US/main2/`
- `analysis/data/US/main3/`

Pilot/test data are retained under `analysis/data/UK/test/`, `analysis/data/US/test/`, and `analysis/data/US/test2/`, but the final article analyses use the main study folders listed above.

The `export.csv` files are column-pruned PostHog exports. They retain only the event timestamp, session id, participant id, tweet id, and event name needed to regenerate the cleaned `posthog.csv` files.

## Outputs

Main outputs are written to:

- `analysis/plots/joint_fe_gradients.png`
- `analysis/plots/joint_fe_gradients_attention.png`
- `analysis/plots/joint_fe_gradients_zeros.png`
- `analysis/plots/joint_fe_gradients_zeros_attention.png`
- `analysis/plots/sensitivity_combined.png`
- `analysis/plots/user_clicks_distribution.png`
- `analysis/tables/joint_fe_glm_ideology_gradients.tex`
- `analysis/tables/joint_fe_glm_ideology_gradients_attention.tex`
- `analysis/tables/joint_fe_glm_ideology_gradients_zeros.tex`
- `analysis/tables/joint_fe_glm_ideology_gradients_zeros_attention.tex`
