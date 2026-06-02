# Load necessary libraries
library(dplyr)
library(readr)
library(tidylog)

# Step 1: Read in the data
posthogdat <- read_csv("data/UK/main/export.csv")

# Step 2: Filter and retain only the relevant columns and rows for August 28, 2024
posthogdat_filtered <- posthogdat %>%
  mutate(date_only = as.Date(`*.properties.$sent_at`)) %>%  # Extract date from timestamp
  filter(date_only == "2024-08-28") %>%                     # Filter for specific date
  select(
    session_id = `*.properties.$session_id`,
    # Select necessary columns
    prolific_id = `*.properties.PROLIFIC_PID`,
    tweet_id = `*.properties.properties.tweet_id`,
    event_type = `*.event`
  )

# Step 3: Fill missing prolific IDs based on session_id
posthogdat_filtered <- posthogdat_filtered %>%
  group_by(session_id) %>%
  mutate(prolific_id = ifelse(is.na(prolific_id), first(na.omit(prolific_id)), prolific_id)) %>%
  ungroup()

# Remove multiple engagement click events
posthogdat_filtered <- posthogdat_filtered %>%
  group_by(prolific_id, tweet_id, event_type) %>%
  mutate(
    is_like_rt = event_type %in% c("like_click", "retweet_click") &
      !is.na(prolific_id) & !is.na(tweet_id),
    n_events   = dplyr::n()
  ) %>%
  ungroup() %>%
  # Drop all rows in groups where there was more than one like/RT
  filter(!(is_like_rt & n_events > 1)) %>%
  select(-is_like_rt, -n_events)

# Step 4: Save the cleaned dataset
write_csv(posthogdat_filtered, "data/UK/main/posthog.csv")

# # Remove the original data file as too large
# file.remove("data/main/export.csv")


