library(dplyr)
library(readr)

options(scipen = 999)
set.seed(123L)

# Read the CSV file
dat <- read_csv("data/tweets_pre-elec_classified.csv") %>%
  filter(use == 1)

# Sample tweets from each classification
sampled_tweets <- bind_rows(
  dat %>% filter(classification == "Very right") %>% slice_sample(n = 30),
  dat %>% filter(classification == "Somewhat right") %>% slice_sample(n = 30),
  dat %>% filter(classification == "Very left") %>% slice_sample(n = 30),
  dat %>% filter(classification == "Somewhat left") %>% slice_sample(n = 30)
) %>%
  select(id_str, text, classification)

write_csv(sampled_tweets, "data/pre-election_to_use.csv")

# Get full tweets data 

datfull <- read_csv("data/tweets_pre-election_ALL.csv") %>%
  select(
    id_str,
    user.id_str,
    text,
    retweet_count,
    favorite_count,
    user.screen_name,
    user.name,
    user.profile_image_url
  )

sampled_tweetids <- sampled_tweets %>%
  select(id_str)

# Join sampled_tweets with datfull on id_str in sampled_tweets and id in datfull
final_data <- left_join(sampled_tweetids, datfull, by = c("id_str"))

final_datat <- final_data %>%
  rename(
    id = id_str,
    user_id = user.id_str,
    tweet = text,
    retweets_count = retweet_count,
    likes_count = favorite_count,
    name = user.name,
    username = user.screen_name,
    profile_image_url = user.profile_image_url
  )

write_csv(sampled_tweets, "data/final/pre-election_to_use_final.csv")

