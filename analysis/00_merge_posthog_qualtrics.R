library(dplyr)
library(readr)
options(scipen = 999)

qualtricsdat <- read_csv("data/test/qualtrics.csv")
qualtricsdat <- qualtricsdat[-c(1:2),]
posthogdat <- read_csv("data/test/posthog.csv")
tweetsdat <- read_csv("data/test/tweets.csv") %>%
  select(id, classification)

# We need to be able to connect posthog returns to qualtrics responses here

# Extract relevant information from posthogdat
posthogdat_filtered <- posthogdat %>%
  select(session_id = `*.properties.$session_id`,
         prolific_id = `*.properties.PROLIFIC_PID`,
         tweet_id = `*.properties.properties.tweet_id`,
         event_type = `*.event`) # Add the event type column

# Fill in where cell doesn't contain prolific ID
posthogdat_filtered <- posthogdat_filtered %>%
  group_by(session_id) %>%
  mutate(prolific_id = ifelse(is.na(prolific_id), first(na.omit(prolific_id)), prolific_id)) %>%
  ungroup()

# Merge in tweets data
posthogdat_filtered <- posthogdat_filtered %>%
  left_join(tweetsdat, by = c("tweet_id" = "id")) %>%
  filter(!is.na(classification))
