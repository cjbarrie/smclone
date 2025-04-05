# Load necessary libraries
library(dplyr)
library(purrr)
library(readr)

# 1. Read in the three CSV files.
df_aa <- read.csv("data/us/usa_timeline_manual_aa.csv", stringsAsFactors = FALSE)
df_ak <- read.csv("data/us/usa_timeline_manual_ak.csv.csv", stringsAsFactors = FALSE)
df_cb <- read.csv("data/us/usa_timeline_manual_cb.csv", stringsAsFactors = FALSE)


df_aa <- df_aa %>% filter(use == 1) %>%
  select(id, text, code_gpt)
df_ak <- df_ak %>% filter(use == 1) %>%
  select(id)
df_cb <- df_cb %>% filter(use == 1) %>%
  select(id)

df_merged <- list(df_aa, df_ak, df_cb) %>% 
  reduce(function(x, y) merge(x, y, by = "id"))

# For balancing the data: find the minimum count across each level of 'code_gpt'
group_counts <- df_merged %>% 
  group_by(code_gpt) %>% 
  summarise(n = n())

min_n <- min(group_counts$n) -2  #get 15 of each by subtracting 2 from lowest count (17)

# 5. Sample exactly 'min_n' rows from each group so that each code_gpt label has the same number of rows.
df_balanced <- df_merged %>% 
  group_by(code_gpt) %>% 
  sample_n(min_n) %>% 
  ungroup()

# Create the directory if it doesn't exist
if (!dir.exists("data/us/final")) {
  dir.create("data/us/final", recursive = TRUE)
}

# Read the CSV file
tweets <- read_csv("data/us/usa_tweets_filtered_classified.csv") %>%
  select(-code_gpt, -tweet_gpt, -text)

df_balanced_merged <- df_balanced %>%
  left_join(tweets, by = "id") %>%
  select(id, created_at, text, screen_name, code_gpt) %>%
  rename(classification = code_gpt,
         tweet = text)

# Write the balanced dataset to CSV
write_csv(df_balanced_merged, "data/us/final/usa_timeline_final.csv")


