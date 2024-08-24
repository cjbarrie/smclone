library(dplyr)
library(readr)
library(ggplot2)
options(scipen = 999)

qualtricsdat <- read_csv("data/test/qualtrics_pilot1.csv")
qualtricsdat <- qualtricsdat[-c(1:2),]
posthogdat <- read_csv("data/test/posthog_pilot1.csv")
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

# Merge in qualtrics data
data_merged <- posthogdat_filtered %>%
  left_join(qualtricsdat, by = c("prolific_id" = "Q1")) %>%
  filter(!is.na(prolific_id))

data_merged$StartDate <- as.Date(data_merged$StartDate)

# Merge in qualtrics data
data_merged <- data_merged %>%
  filter(StartDate >= "2024-08-23")

UK <- map_data(map = "world", region = "UK") # changed map to "world"

data_merged$LocationLatitude <- as.numeric(data_merged$LocationLatitude)
data_merged$LocationLongitude <- as.numeric(data_merged$LocationLongitude)

# Plot the map
ggplot() +
  geom_polygon(data = UK, aes(x = long, y = lat, group = group), fill = "lightblue", color = "white") +
  geom_point(data = data_merged, aes(x = LocationLongitude, y = LocationLatitude), color = "red", size = 2) +
  coord_quickmap(xlim = c(-10, 5), ylim = c(49, 61)) +
  theme_minimal() +
  labs(title = "Respondent IP address locations",
       x = "Longitude",
       y = "Latitude")

# Plot distribution of ideology scores
data_merged$ideo_numeric <- as.numeric(data_merged$Q2_1)
hist(data_merged$ideo_numeric)

data_readmore <- data_merged %>%
  filter(event_type=="expand_tweet")

data_readmore$binary_tweet <- ifelse(data_readmore$classification %in% c("Very left", "Somewhat left"), 1, 0)

data_readmore$gender <- ifelse(data_readmore$Q9 == "Prefer not to say", NA, data_readmore$Q9)

data_readmore$age <- as.numeric(data_readmore$Q8)

# Recode Education
# First, recode the other education categories, leaving "Still at school/Full time student" as is
data_readmore$education <- dplyr::case_when(
  data_readmore$Q10 == "20+" ~ 20,
  data_readmore$Q10 == "15 or under" ~ 15,
  data_readmore$Q10 == "19" ~ 19,
  data_readmore$Q10 == "17-18" ~ 18,
  data_readmore$Q10 == "16" ~ 16,
  data_readmore$Q10 == "Can't remember" ~ NA_real_,
  data_readmore$Q10 == "Still at school/Full time student" ~ NA_real_,  # Temporary NA for now
  TRUE ~ NA_real_  # Catch all for any other unexpected values
)

# Now, randomly assign either 16 or 19 to rows where Q10 was "Still at school/Full time student"
still_at_school_rows <- which(data_readmore$Q10 == "Still at school/Full time student")
data_readmore$education[still_at_school_rows] <- sample(c(16, 19), length(still_at_school_rows), replace = TRUE)


# Create a numeric scale for income
income_levels <- c("Less than £5,000" = 1,
                   "£5,000–£9,999" = 2,
                   "£10,000–£14,999" = 3,
                   "£15,000–£19,999" = 4,
                   "£20,000–£24,999" = 5,
                   "£25,000–£29,999" = 6,
                   "£30,000–£34,999" = 7,
                   "£35,000–£39,999" = 8,
                   "£40,000–£44,999" = 9,
                   "£45,000–£49,999" = 10,
                   "£50,000–£59,999" = 11,
                   "£60,000–£69,999" = 12,
                   "£70,000–£99,999" = 13,
                   "£100,000–£149,999" = 14,
                   "Prefer not to say" = NA_real_)

# Apply the mapping to the column
data_readmore$income <- unname(income_levels[data_readmore$Q11])

# Count the number of social media platforms
data_readmore$smuse <- sapply(strsplit(data_readmore$Q7, ","), length)


# Running the logistic regression
logistic_model <- glm(binary_tweet ~ ideo_numeric + gender + age + income + smuse + education, 
                      data = data_readmore, 
                      family = binomial)

# Summary of the logistic regression model
summary(logistic_model)