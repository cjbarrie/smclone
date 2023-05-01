library(dplyr)
library(academictwitteR)
library(tidylog)
set.seed(123L)
options(scipen = 999)

tweets <- read.csv("/Users/cbarrie6/Dropbox/pd_projects/MP_enviro/data/output/mptweetsdat17.csv")

# tweets_short <- tweets %>%
#   select(id, user_id, username, name, tweet, retweets_count, likes_count)
# 
# tweets_short_sample <- tweets_short %>%
#   sample_n(20)
# 
# write.csv(tweets_short_sample, "/Users/cbarrie6/Dropbox/sandbox/smclone/backend/tweets.csv")

users <- unique(tweets$username)

for (i in seq_along(users)) {
  
  get_all_tweets(
    users = users[[i]],
    start_tweets = "2023-01-01T00:00:00Z",
    end_tweets = "2023-04-30T00:00:00Z",
    is_retweet = F,
    bind_tweets = F,
    data_path = "tweetdata/",
    n = 100 # max. 100 tweets per user
  )

}

users <- bind_tweets("tweetdata/", user = T)
tweets <- bind_tweets("tweetdata/")

tweets$retweets_count <- tweets$public_metrics$retweet_count
tweets$likes_count <- tweets$public_metrics$like_count
tweets$user_id <- tweets$author_id
tweets$tweet <- tweets$text

tweets_short <- tweets %>%
  select(id, user_id, tweet, retweets_count, likes_count)

users_short <- users %>%
  select(id, username, name, profile_image_url)

users$user_id <- users$id

users_short <- users %>%
  select(user_id, username, name, profile_image_url)


tweets_joined <- tweets_short %>%
  left_join(users_short, by = "user_id")


tweets_joined_sample <- tweets_joined %>%
  sample_n(100)

write.csv(tweets_short_sample, "/Users/cbarrie6/Dropbox/sandbox/smclone/backend/tweets.csv")
