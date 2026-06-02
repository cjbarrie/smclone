# -----------------------------------
# Libraries & Options
# -----------------------------------
library(dplyr)
library(readr)
library(ggplot2)
library(cowplot)
library(knitr)
library(kableExtra)
library(stringr)
options(scipen = 999)

# -----------------------------------
# 1. Read & Merge UK Data (Study 1)
# -----------------------------------
qualtrics_uk <- read_csv("data/UK/main/qualtrics.csv") %>% slice(-1:-2)
posthog_uk   <- read_csv("data/UK/main/posthog.csv")
tweets_uk    <- read_csv("data/UK/main/tweets.csv") %>%
  select(id, classification, tweet, retweets_count, likes_count) %>%
  mutate(endorsement = retweets_count + likes_count)

data_uk <- posthog_uk %>%
  left_join(tweets_uk, by = c("tweet_id" = "id")) %>%
  filter(!is.na(classification)) %>%
  left_join(qualtrics_uk, by = c("prolific_id" = "Q1")) %>%
  filter(!is.na(prolific_id)) %>%
  mutate(ideo_numeric = as.numeric(str_extract(Q2_1, "\\d+"))) %>%
  filter(!is.na(ideo_numeric)) %>%
  mutate(sample = "Study 1 (UK)")

# -----------------------------------
# 2. Read & Merge US Data (main) – Study 2
# -----------------------------------
qualtrics_us1 <- read_csv("data/US/main/qualtrics.csv") %>% slice(-1:-2)
posthog_us1   <- read_csv("data/US/main/posthog.csv")
tweets_us1    <- read_csv("data/US/test/tweets.csv") %>%
  select(id, classification, tweet, rt_rand, like_rand) %>%
  rename(retweets_count = rt_rand, likes_count = like_rand) %>%
  mutate(endorsement = retweets_count + likes_count)

data_us1 <- posthog_us1 %>%
  left_join(tweets_us1, by = c("tweet_id" = "id")) %>%
  filter(!is.na(classification)) %>%
  left_join(qualtrics_us1, by = c("respondent_id" = "rom_id")) %>%
  filter(!is.na(respondent_id)) %>%
  mutate(ideo_numeric = as.numeric(str_extract(Q2_1, "\\d+"))) %>%
  filter(!is.na(ideo_numeric)) %>%
  mutate(sample = "Study 2 (US)")

# -----------------------------------
# 3. Read & Merge US Data (main2) – Study 3
# -----------------------------------
qualtrics_us2 <- read_csv("data/US/main2/qualtrics.csv") %>% slice(-1:-2)
posthog_us2   <- read_csv("data/US/main2/posthog.csv")
tweets_us2    <- read_csv("data/US/main2/tweets.csv") %>%
  select(id, classification, tweet, rt_rand, like_rand) %>%
  rename(retweets_count = rt_rand, likes_count = like_rand) %>%
  mutate(endorsement = retweets_count + likes_count)

data_us2 <- posthog_us2 %>%
  left_join(tweets_us2, by = c("tweet_id" = "id")) %>%
  filter(!is.na(classification)) %>%
  left_join(qualtrics_us2, by = c("prolific_id" = "Q1")) %>%
  filter(!is.na(prolific_id)) %>%
  mutate(ideo_numeric = as.numeric(str_extract(Q2_1, "\\d+"))) %>%
  filter(!is.na(ideo_numeric)) %>%
  mutate(sample = "Study 3 (US)")

# -----------------------------------
# 3b. Read & Merge US Data (main3) – Study 4
# -----------------------------------
qualtrics_us3 <- read_csv("data/US/main3/qualtrics.csv") %>% slice(-1:-2)
posthog_us3   <- read_csv("data/US/main3/posthog.csv")
tweets_us3    <- read_csv("data/US/main3/tweets.csv") %>%
  select(id, classification, tweet, rt_rand, like_rand) %>%
  rename(retweets_count = rt_rand, likes_count = like_rand) %>%
  mutate(endorsement = retweets_count + likes_count)

data_us3 <- posthog_us3 %>%
  left_join(tweets_us3, by = c("tweet_id" = "id")) %>%
  filter(!is.na(classification)) %>%
  left_join(qualtrics_us3, by = c("prolific_id" = "Q1")) %>%
  filter(!is.na(prolific_id)) %>%
  mutate(ideo_numeric = as.numeric(str_extract(Q2_1, "\\d+"))) %>%
  filter(!is.na(ideo_numeric)) %>%
  mutate(sample = "Study 4 (US)")


# -----------------------------------
# 4. Combine All Studies
# -----------------------------------
data_all <- bind_rows(
  data_uk  %>% rename(user_id = prolific_id),
  data_us1 %>% rename(user_id = respondent_id),
  data_us2 %>% rename(user_id = prolific_id),
  data_us3 %>% rename(user_id = prolific_id)   # NEW
)

# -----------------------------------
# 5. Distribution of User Interactions per User
# -----------------------------------
user_clicks <- data_all %>%
  filter(event_type %in% c("expand_tweet", "like_click", "retweet_click")) %>%
  mutate(event = recode(event_type,
                        expand_tweet  = "Read more",
                        like_click    = "Like",
                        retweet_click = "Share")) %>%
  group_by(sample, user_id, event) %>%
  summarise(n_clicks = n(), .groups = "drop")

dist_plot <- ggplot(user_clicks, aes(x = log(n_clicks), fill = sample)) +
  geom_histogram(aes(y = ..density..),
                 binwidth = 1, position = "identity", alpha = 0.4, colour = NA) +
  geom_density(aes(y = ..density..), alpha = 0.3) +
  facet_wrap(~ event, nrow = 1) +
  labs(
    x    = "# Clicks per user (logged)",
    y    = "Density",
    fill = "Study"
  ) +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom")

ggsave("plots/user_clicks_distribution.png", dist_plot, width = 10, height = 4, dpi = 300)

# -----------------------------------
# 6. Find & Display Top-Clicked Tweets
# -----------------------------------
tweet_clicks_by_sample <- data_all %>%
  filter(event_type %in% c("expand_tweet", "like_click", "retweet_click")) %>%
  group_by(sample, event_type, tweet_id, tweet) %>%
  summarise(clicks = n(), .groups = "drop")

top_tweets <- tweet_clicks_by_sample %>%
  group_by(sample, event_type) %>%
  slice_max(clicks, n = 5, with_ties = FALSE) %>%
  ungroup() %>%
  mutate(Event = recode(event_type,
                        expand_tweet  = "Read more",
                        like_click    = "Like",
                        retweet_click = "Share")) %>%
  select(Study = sample, Event, Tweet = tweet, Clicks = clicks)

top_tweets %>%
  arrange(Study, Event, desc(Clicks)) %>%
  kable() %>%
  kable_styling(full_width = FALSE)
