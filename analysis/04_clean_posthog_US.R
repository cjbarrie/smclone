# Load necessary libraries
library(dplyr)
library(readr)

# Step 1: Read in the data
posthogdat <- read_csv("data/US/test/export.csv")

# Step 2: Filter and retain only the relevant columns and rows for  after certain date
posthogdat_filtered <- posthogdat %>%
  mutate(date_only = as.Date(`*.properties.$sent_at`)) %>%  # Extract date from timestamp
  filter(date_only >= "2025-04-25") %>%                     # Filter for specific date
  select(
    session_id = `*.properties.$session_id`,
    # Select necessary columns
    respondent_id = `*.properties.romId`,
    tweet_id = `*.properties.properties.tweet_id`,
    event_type = `*.event`
  )

# Step 3: Fill missing prolific IDs based on session_id
posthogdat_filtered <- posthogdat_filtered %>%
  group_by(session_id) %>%
  mutate(respondent_id = ifelse(is.na(respondent_id), first(na.omit(respondent_id)), respondent_id)) %>%
  ungroup()

# Step 4: Save the cleaned dataset
write_csv(posthogdat_filtered, "data/US/test/posthog.csv")

# # Remove the original data file as too large
# file.remove("data/main/export.csv")


# library(stringr)
# 
# # Search for either string in **any** column:
# matches <- posthogdat %>%
#   filter(
#     if_any(
#       everything(),
#       ~ str_detect(as.character(.), "test")
#     )
#   )
# 
# # How many hits?
# n_matches <- nrow(matches)
# message("Found ", n_matches, " matching rows.")
# 
# # View the matches
# print(matches)