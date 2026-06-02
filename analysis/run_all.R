script_args <- commandArgs(trailingOnly = FALSE)
script_file_arg <- grep("^--file=", script_args, value = TRUE)
script_file <- if (length(script_file_arg) > 0) {
  normalizePath(sub("^--file=", "", script_file_arg[[1]]))
} else {
  tryCatch(normalizePath(sys.frame(1)$ofile), error = function(e) NA_character_)
}

analysis_dir <- if (!is.na(script_file)) dirname(script_file) else getwd()
old_wd <- getwd()
setwd(analysis_dir)
on.exit(setwd(old_wd), add = TRUE)

scripts <- c(
  "01_clean_posthog_UK.R",
  "02_clean_posthog_US.R",
  "03_clean_posthog_US-2.R",
  "04_clean_posthog-US-3.R",
  "11_combined_analysis.R",
  "12_combined_analysis_attention.R",
  "13_combined_analysis_zeros.R",
  "14_combined_analysis_zeros_attention.R",
  "21_user_comparisons.R"
)

for (script in scripts) {
  message("Running ", script)
  source(script, local = new.env(parent = globalenv()))
}

message("Analysis pipeline complete.")
