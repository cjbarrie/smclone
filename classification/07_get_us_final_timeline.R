library(dplyr)
library(purrr)
library(readr)
library(stringr)

script_args <- commandArgs(trailingOnly = FALSE)
script_file_arg <- grep("^--file=", script_args, value = TRUE)
script_file <- if (length(script_file_arg) > 0) {
  normalizePath(sub("^--file=", "", script_file_arg[[1]]))
} else {
  tryCatch(normalizePath(sys.frame(1)$ofile), error = function(e) NA_character_)
}
script_dir <- if (!is.na(script_file)) dirname(script_file) else getwd()
if (!dir.exists(file.path(script_dir, "data/us")) && dir.exists(file.path(getwd(), "classification/data/us"))) {
  script_dir <- file.path(getwd(), "classification")
}

# 1. Read in the three CSVs, and rename `use` so we can tell them apart
df_aa <- read_csv(file.path(script_dir, "data/us/usa_timeline_manual_aa.csv")) %>% 
  select(id, text, code_gpt, use_aa = use)

df_ak <- read_csv(file.path(script_dir, "data/us/usa_timeline_manual_ak.csv")) %>% 
  select(id, use_ak = use)

df_cb <- read_csv(file.path(script_dir, "data/us/usa_timeline_manual_cb.csv")) %>% 
  select(id, use_cb = use)

# 2. Join them all by id
df_all <- list(df_aa, df_ak, df_cb) %>% 
  reduce(full_join, by = "id")

# 2. Join them all by id
df_all <- list(df_aa, df_ak, df_cb) %>% 
  reduce(full_join, by = "id")

# 3. Filter to those with agreement from at least two coders
df_agree2 <- df_all %>% 
  # compute the row‐wise sum of the three use flags
  mutate(agree_count = use_aa + use_ak + use_cb) %>% 
  # keep rows where two or three coders said “use”
  filter(agree_count >= 2) %>% 
  select(-agree_count)

# For balancing the data: find the minimum count across each level of 'code_gpt'
group_counts <- df_agree2 %>% 
  group_by(code_gpt) %>% 
  summarise(n = n())

min_n <- min(group_counts$n) -4  #get 45 of each by subtracting 2 from lowest count (17)

# 5. Sample exactly 'min_n' rows from each group so that each code_gpt label has the same number of rows.
df_balanced <- df_agree2 %>% 
  group_by(code_gpt) %>% 
  sample_n(min_n) %>% 
  ungroup()  %>%
  select(-use_aa, -use_ak, -use_cb) %>%
  rename(text_truncated = text)

# Read in original tweets for full text

tweets <- read_csv(file.path(script_dir, "data/us/usa_tweets.csv"))

df_balanced_merged <- df_balanced %>%
  left_join(tweets, by = "id") %>%
  select(id, created_at, text_truncated, text, screen_name, code_gpt) %>%
  rename(classification = code_gpt,
         tweet = text)


# 6. Remove any truncated texts where a link start ("http…") precedes "Read more"
df_clean <- df_balanced_merged %>%
  filter(
    # keep only those that do NOT match "http" followed (anywhere) by "Read more"
    !str_detect(text_truncated, "http.*Read more")
  )

# Option A: compute the minimum count first...
min_n <- df_clean %>% 
  count(classification) %>% 
  pull(n) %>% 
  min()

df_balanced_final <- df_clean %>% 
  group_by(classification) %>% 
  slice_sample(n = 30) %>% 
  ungroup()

if (!dir.exists(file.path(script_dir, "data/us/final"))) {
  dir.create(file.path(script_dir, "data/us/final"), recursive = TRUE)
}

# 7. Write out the final data set 
write_csv(df_balanced_final, file.path(script_dir, "data/us/final/usa_timeline_final.csv"))
