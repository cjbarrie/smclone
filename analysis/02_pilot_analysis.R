library(dplyr)
library(readr)
library(ggplot2)
library(broom)
options(scipen = 999)

# Read in data
qualtricsdat <- read_csv("data/test/qualtrics_pilot1.csv")
qualtricsdat <- qualtricsdat[-c(1:2),]
posthogdat <- read_csv("data/test/posthog_pilot1.csv")
tweetsdat <- read_csv("data/test/tweets.csv") %>%
  select(id, classification)

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

# Merge in tweets and qualtrics data
data_merged <- posthogdat_filtered %>%
  left_join(tweetsdat, by = c("tweet_id" = "id")) %>%
  filter(!is.na(classification)) %>%
  left_join(qualtricsdat, by = c("prolific_id" = "Q1")) %>%
  filter(!is.na(prolific_id))

data_merged$StartDate <- as.Date(data_merged$StartDate)
data_merged <- data_merged %>%
  filter(StartDate >= "2024-08-23")

# Map plot function
plot_map <- function(data) {
  UK <- map_data(map = "world", region = "UK")
  ggplot() +
    geom_polygon(data = UK, aes(x = long, y = lat, group = group), fill = "lightblue", color = "white") +
    geom_point(data = data, aes(x = LocationLongitude, y = LocationLatitude), color = "red", size = 2) +
    coord_quickmap(xlim = c(-10, 5), ylim = c(49, 61)) +
    theme_minimal() +
    labs(title = "Respondent IP address locations",
         x = "Longitude",
         y = "Latitude")
}

# Plot the map
data_merged$LocationLatitude <- as.numeric(data_merged$LocationLatitude)
data_merged$LocationLongitude <- as.numeric(data_merged$LocationLongitude)
plot_map(data_merged)

# Plot distribution of ideology scores
data_merged$ideo_numeric <- as.numeric(data_merged$Q2_1)
hist(data_merged$ideo_numeric)

# Tabulate attention checks
attention_merged <- data_merged %>%
  select(prolific_id, Q13_1, Q13_2, Q13_3) %>%
  mutate(attention_combination = paste(Q13_1, Q13_2, Q13_3, sep = " ")) %>%
  distinct(.keep_all = T)

attention_tabulation <- attention_merged %>%
  count(attention_combination) %>%
  arrange(desc(n))

# Function to recode variables and run logistic regression
run_analysis <- function(data, event_type_filter) {
  filtered_data <- data %>%
    filter(event_type == event_type_filter)
  
  filtered_data$binary_tweet <- ifelse(filtered_data$classification %in% c("Very left", "Somewhat left"), 1, 0)
  filtered_data$gender <- ifelse(filtered_data$Q9 == "Prefer not to say", NA, filtered_data$Q9)
  filtered_data$age <- as.numeric(filtered_data$Q8)
  
  # Recode Education
  filtered_data$education <- dplyr::case_when(
    filtered_data$Q10 == "20+" ~ 20,
    filtered_data$Q10 == "15 or under" ~ 15,
    filtered_data$Q10 == "19" ~ 19,
    filtered_data$Q10 == "17-18" ~ 18,
    filtered_data$Q10 == "16" ~ 16,
    filtered_data$Q10 == "Can't remember" ~ NA_real_,
    filtered_data$Q10 == "Still at school/Full time student" ~ NA_real_,  # Temporary NA for now
    TRUE ~ NA_real_  # Catch all for any other unexpected values
  )
  
  # Randomly assign 16 or 19 to "Still at school/Full time student"
  still_at_school_rows <- which(filtered_data$Q10 == "Still at school/Full time student")
  filtered_data$education[still_at_school_rows] <- sample(c(16, 19), length(still_at_school_rows), replace = TRUE)
  
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
  
  filtered_data$income <- unname(income_levels[filtered_data$Q11])
  
  # Count the number of social media platforms
  filtered_data$smuse <- sapply(strsplit(filtered_data$Q7, ","), length)
  
  # Running the logistic regression
  logistic_model <- glm(binary_tweet ~ ideo_numeric + gender + age + income + smuse + education, 
                        data = filtered_data, 
                        family = binomial)
  
  return(summary(logistic_model))
}

# Run the analysis for expand_tweet
expand_tweet_summary <- run_analysis(data_merged, "expand_tweet")
print(expand_tweet_summary)

# Run the analysis for like_click
like_click_summary <- run_analysis(data_merged, "like_click")
print(like_click_summary)

# Run the analysis for retweet_click
retweet_click_summary <- run_analysis(data_merged, "retweet_click")
print(retweet_click_summary)

# Function to run analysis and extract coefficients
run_analysis_extract_coef <- function(data, event_type_filter) {
  filtered_data <- data %>%
    filter(event_type == event_type_filter)
  
  filtered_data$binary_tweet <- ifelse(filtered_data$classification %in% c("Very left", "Somewhat left"), 1, 0)
  filtered_data$gender <- ifelse(filtered_data$Q9 == "Prefer not to say", NA, filtered_data$Q9)
  filtered_data$age <- as.numeric(filtered_data$Q8)
  
  # Recode Education
  filtered_data$education <- dplyr::case_when(
    filtered_data$Q10 == "20+" ~ 20,
    filtered_data$Q10 == "15 or under" ~ 15,
    filtered_data$Q10 == "19" ~ 19,
    filtered_data$Q10 == "17-18" ~ 18,
    filtered_data$Q10 == "16" ~ 16,
    filtered_data$Q10 == "Can't remember" ~ NA_real_,
    filtered_data$Q10 == "Still at school/Full time student" ~ NA_real_,  # Temporary NA for now
    TRUE ~ NA_real_  # Catch all for any other unexpected values
  )
  
  # Randomly assign 16 or 19 to "Still at school/Full time student"
  still_at_school_rows <- which(filtered_data$Q10 == "Still at school/Full time student")
  filtered_data$education[still_at_school_rows] <- sample(c(16, 19), length(still_at_school_rows), replace = TRUE)
  
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
  
  filtered_data$income <- unname(income_levels[filtered_data$Q11])
  
  # Count the number of social media platforms
  filtered_data$smuse <- sapply(strsplit(filtered_data$Q7, ","), length)
  
  # Running the logistic regression
  logistic_model <- glm(binary_tweet ~ ideo_numeric + gender + age + income + smuse + education, 
                        data = filtered_data, 
                        family = binomial)
  
  # Extract coefficient for ideo_numeric
  coef_data <- tidy(logistic_model) %>%
    filter(term == "ideo_numeric") %>%
    mutate(event_type = event_type_filter)
  
  return(coef_data)
}

# Run analysis for each event type and extract coefficients
coef_like_click <- run_analysis_extract_coef(data_merged, "like_click")
coef_retweet_click <- run_analysis_extract_coef(data_merged, "retweet_click")
coef_expand_tweet <- run_analysis_extract_coef(data_merged, "expand_tweet")

# Combine the coefficients into one data frame
coef_data_combined <- bind_rows(coef_like_click, coef_retweet_click, coef_expand_tweet)

# Plotting the coefficients with error bars
ggplot(coef_data_combined, aes(x = event_type, y = estimate, ymin = estimate - std.error, ymax = estimate + std.error)) +
  geom_pointrange() +
  theme_minimal() +
  labs(title = "Effect of Ideology Score on Different Event Types",
       x = "Event Type",
       y = "Coefficient Estimate (with 95% CI)") +
  geom_hline(yintercept = 0, linetype = "dashed", color = "red") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))