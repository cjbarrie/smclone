library(dplyr)
library(readr)

# Read the CSV file
tweetselec <- read_csv("data/tweets_sample_filtered_classified_election.csv")

# Filter the tweets
tweetseleclr <- tweetselec %>%
  # filter(code_gpt == "Very left" | code_gpt == "Very right")
  filter(code_gpt != "Neither left nor right" & !is.na(code_gpt))

write_csv(tweetseleclr, "data/election_timeline.csv")


# Read the CSV file
tweetsprelec <- read_csv("data/tweets_sample_filtered_classified_pre-election.csv")

# Filter the tweets
tweetspreleclr <- tweetsprelec %>%
  # filter(code_gpt == "Very left" | code_gpt == "Very right")
  filter(code_gpt != "Neither left nor right" & !is.na(code_gpt))

write_csv(tweetspreleclr, "data/pre-election_timeline.csv")
