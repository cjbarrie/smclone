library(dplyr)
library(readr)
library(stringr)

# Read the CSV file
tweets <- read_csv("data/us/usa_tweets_filtered_classified.csv")

# Filter the tweets: keep rows where code_gpt is not "Neither left nor right", 
# is not NA, and double check the text ends with "... Read more"
dat <- tweets %>%
  filter(code_gpt != "Neither left nor right" & 
           !is.na(code_gpt) &
           str_ends(text, fixed("... Read more")))

# Sample tweets from each code_gpt
sampled_tweets <- bind_rows(
  dat %>% filter(code_gpt == "Very right") %>% slice_sample(n = 60),
  dat %>% filter(code_gpt == "Somewhat right") %>% slice_sample(n = 60),
  dat %>% filter(code_gpt == "Very left") %>% slice_sample(n = 60),
  dat %>% filter(code_gpt == "Somewhat left") %>% slice_sample(n = 60)
) %>%
  select(id, text, code_gpt)

write_csv(sampled_tweets, "data/us/usa_timeline.csv")


################MANUAL CODING saved as usa_timeline_manual################

