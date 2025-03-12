library(margins)
library(dplyr)
library(readr)
library(ggplot2)
library(broom)
library(cowplot)
options(scipen = 999)

# --------------------------
# Read and Merge Data
# --------------------------
qualtricsdat <- read_csv("data/main/qualtrics.csv")
qualtricsdat <- qualtricsdat[-c(1:2),]
posthogdat_filtered <- read_csv("data/main/posthog.csv")
tweetsdat <- read_csv("data/main/tweets.csv") %>%
  select(id, classification, retweets_count, likes_count)
tweetsdat$endorsement <- tweetsdat$retweets_count + tweetsdat$likes_count

data_merged <- posthogdat_filtered %>%
  left_join(tweetsdat, by = c("tweet_id" = "id")) %>%
  filter(!is.na(classification)) %>%
  left_join(qualtricsdat, by = c("prolific_id" = "Q1")) %>%
  filter(!is.na(prolific_id))

data_merged$ideo_numeric <- as.numeric(data_merged$Q2_1)

# --------------------------
# Recode and Standardize Variables
# --------------------------
variables_to_standardize <- c("ideo_numeric", "polint", "age", "education", "income", "smuse", "endorsement")

data_standardized <- data_merged %>%
  mutate(binary_tweet = ifelse(classification %in% c("Very left", "Somewhat left"), 0, 1),
         polint = case_when(
           Q14_1 == "0 (Not at all interested)" ~ 0,
           Q14_1 == "1" ~ 1,
           Q14_1 == "2" ~ 2,
           Q14_1 == "3" ~ 3,
           Q14_1 == "4" ~ 4,
           Q14_1 == "5 (Very interested)" ~ 5,
           TRUE ~ NA_real_
         ),
         gender = ifelse(Q9 == "Prefer not to say", NA, as.numeric(factor(Q9))),
         age = as.numeric(Q8),
         education = case_when(
           Q10 == "20+" ~ 20,
           Q10 == "15 or under" ~ 15,
           Q10 == "19" ~ 19,
           Q10 == "17-18" ~ 18,
           Q10 == "16" ~ 16,
           Q10 == "Can't remember" ~ NA_real_,
           Q10 == "Still at school/Full time student" ~ as.numeric(age),
           TRUE ~ NA_real_
         ),
         income = case_when(
           Q11 == "Less than £5,000" ~ 1,
           Q11 == "£5,000–£9,999" ~ 2,
           Q11 == "£10,000–£14,999" ~ 3,
           Q11 == "£15,000–£19,999" ~ 4,
           Q11 == "£20,000–£24,999" ~ 5,
           Q11 == "£25,000–£29,999" ~ 6,
           Q11 == "£30,000–£34,999" ~ 7,
           Q11 == "£35,000–£39,999" ~ 8,
           Q11 == "£40,000–£44,999" ~ 9,
           Q11 == "£45,000–£49,999" ~ 10,
           Q11 == "£50,000–£59,999" ~ 11,
           Q11 == "£60,000–£69,999" ~ 12,
           Q11 == "£70,000–£99,999" ~ 13,
           Q11 == "£100,000–£149,999" ~ 14,
           Q11 == "Prefer not to say" ~ NA_real_
         ),
         smuse = sapply(strsplit(Q7, ","), length),
         endorsement = endorsement
  ) %>%
  mutate(across(all_of(variables_to_standardize), ~ as.numeric(scale(.))))

# --------------------------
# Full-Sample Ideomargins Analysis
# --------------------------
# Fit logistic regression models
data_like_click <- data_standardized %>% filter(event_type == "like_click")
model_like_click <- glm(binary_tweet ~ ideo_numeric + polint + gender + age + income + smuse + education + endorsement, 
                        data = data_like_click, 
                        family = binomial)

data_retweet_click <- data_standardized %>% filter(event_type == "retweet_click")
model_retweet_click <- glm(binary_tweet ~ ideo_numeric + polint + gender + age + income + smuse + education + endorsement, 
                           data = data_retweet_click, 
                           family = binomial)

data_expand_tweet <- data_standardized %>% filter(event_type == "expand_tweet")
model_expand_tweet <- glm(binary_tweet ~ ideo_numeric + polint + gender + age + income + smuse + education + endorsement, 
                          data = data_expand_tweet, 
                          family = binomial)

models <- list(
  like_click = model_like_click,
  retweet_click = model_retweet_click,
  expand_tweet = model_expand_tweet
)

# Generate margins plot data
cdat_list <- lapply(names(models), function(event_type) {
  cdat <- cplot(models[[event_type]], "ideo_numeric", draw = FALSE)
  cdat$event_type <- event_type
  cdat
})
cdat_combined <- do.call(rbind, cdat_list)
cdat_combined <- cdat_combined %>%
  mutate(event_type = factor(event_type, 
                             levels = c("expand_tweet", "like_click", "retweet_click"),
                             labels = c("Read more", "Like", "Share")))

# Create margins plot (Predicted Probabilities)
margins_plot <- ggplot(cdat_combined, aes(x = xvals, color = event_type)) + 
  geom_line(aes(y = yvals), size = 1) +              
  geom_line(aes(y = upper), linetype = "dashed") +     
  geom_line(aes(y = lower), linetype = "dashed") +     
  geom_hline(yintercept = 0, linetype = "dotted", color = "black") +
  xlab("Standardized Ideology") +
  ylab("Predicted Probability") +
  labs(color = "Event Type") +
  scale_color_brewer(palette = "Dark2") +
  theme_minimal(base_size = 14) +
  theme(
    legend.position = "bottom",
    legend.title = element_text(size = 14),
    legend.text = element_text(size = 12),
    panel.grid.major = element_line(color = "grey90"),
    panel.grid.minor = element_blank(),
    plot.title = element_text(size = 16, face = "bold")
  )

# Compute AMEs for each model
ame_like <- summary(margins(model_like_click, variables = "ideo_numeric"))
ame_retweet <- summary(margins(model_retweet_click, variables = "ideo_numeric"))
ame_expand <- summary(margins(model_expand_tweet, variables = "ideo_numeric"))

ame_df <- data.frame(
  Outcome = c("Read more", "Like", "Share"),
  AME = c(ame_expand$AME, ame_like$AME, ame_retweet$AME),
  Lower = c(ame_expand$lower, ame_like$lower, ame_retweet$lower),
  Upper = c(ame_expand$upper, ame_like$upper, ame_retweet$upper)
)
ame_df$Outcome <- factor(ame_df$Outcome, levels = c("Read more", "Like", "Share"))
ratio <- ((ame_like$AME + ame_retweet$AME) / 2) / ame_expand$AME

ame_plot <- ggplot(ame_df, aes(x = Outcome, y = AME, fill = Outcome)) +
  geom_bar(stat = "identity", width = 0.6, show.legend = FALSE) +
  geom_errorbar(aes(ymin = Lower, ymax = Upper), width = 0.2) +
  coord_flip() +
  ylab("AME (Predicted Change)") +
  xlab("") +
  scale_fill_brewer(palette = "Dark2") +
  labs(caption = paste("Avg(Like, Share)/Read more =", round(ratio, 2))) +
  theme_minimal(base_size = 14) +
  theme(
    legend.position = "none",
    plot.title = element_text(size = 16, face = "bold"),
    axis.title = element_text(size = 14),
    plot.caption = element_text(size = 12, hjust = 0.5, margin = margin(t = 10))
  )

combined_plot <- plot_grid(
  margins_plot, ame_plot,
  labels = c("A", "B"),
  ncol = 2,
  rel_widths = c(1, 1)
)
print(combined_plot)
if (!dir.exists("plots")) { dir.create("plots") }
ggsave(filename = "plots/ideomargins.png", plot = combined_plot, width = 14, height = 7, dpi = 300)

# --------------------------
# Now repeat ideomargins for attention-passing respondents
# (Those who answered "No" to Q13_1, Q13_2, and Q13_3)
# --------------------------
data_standardized_attention <- data_standardized %>% 
  filter(Q13_1 == "No", Q13_2 == "No", Q13_3 == "No")

# Fit logistic regression models on attention subset
data_like_click_att <- data_standardized_attention %>% filter(event_type == "like_click")
model_like_click_att <- glm(binary_tweet ~ ideo_numeric + polint + gender + age + income + smuse + education + endorsement, 
                            data = data_like_click_att, 
                            family = binomial)

data_retweet_click_att <- data_standardized_attention %>% filter(event_type == "retweet_click")
model_retweet_click_att <- glm(binary_tweet ~ ideo_numeric + polint + gender + age + income + smuse + education + endorsement, 
                               data = data_retweet_click_att, 
                               family = binomial)

data_expand_tweet_att <- data_standardized_attention %>% filter(event_type == "expand_tweet")
model_expand_tweet_att <- glm(binary_tweet ~ ideo_numeric + polint + gender + age + income + smuse + education + endorsement, 
                              data = data_expand_tweet_att, 
                              family = binomial)

models_att <- list(
  like_click = model_like_click_att,
  retweet_click = model_retweet_click_att,
  expand_tweet = model_expand_tweet_att
)

# Generate margins plot data for the attention subset
cdat_list_att <- lapply(names(models_att), function(event_type) {
  cdat <- cplot(models_att[[event_type]], "ideo_numeric", draw = FALSE)
  cdat$event_type <- event_type
  cdat
})
cdat_combined_att <- do.call(rbind, cdat_list_att)
cdat_combined_att <- cdat_combined_att %>%
  mutate(event_type = factor(event_type, 
                             levels = c("expand_tweet", "like_click", "retweet_click"),
                             labels = c("Read more", "Like", "Share")))

# Create margins plot for attention subset
margins_plot_att <- ggplot(cdat_combined_att, aes(x = xvals, color = event_type)) + 
  geom_line(aes(y = yvals), size = 1) +              
  geom_line(aes(y = upper), linetype = "dashed") +     
  geom_line(aes(y = lower), linetype = "dashed") +     
  geom_hline(yintercept = 0, linetype = "dotted", color = "black") +
  xlab("Standardized Ideology") +
  ylab("Predicted Probability") +
  labs(color = "Event Type") +
  scale_color_brewer(palette = "Dark2") +
  theme_minimal(base_size = 14) +
  theme(
    legend.position = "bottom",
    legend.title = element_text(size = 14),
    legend.text = element_text(size = 12),
    panel.grid.major = element_line(color = "grey90"),
    panel.grid.minor = element_blank(),
    plot.title = element_text(size = 16, face = "bold")
  )

# Compute AMEs for the attention subset
ame_like_att <- summary(margins(model_like_click_att, variables = "ideo_numeric"))
ame_retweet_att <- summary(margins(model_retweet_click_att, variables = "ideo_numeric"))
ame_expand_att <- summary(margins(model_expand_tweet_att, variables = "ideo_numeric"))

ame_df_att <- data.frame(
  Outcome = c("Read more", "Like", "Share"),
  AME = c(ame_expand_att$AME, ame_like_att$AME, ame_retweet_att$AME),
  Lower = c(ame_expand_att$lower, ame_like_att$lower, ame_retweet_att$lower),
  Upper = c(ame_expand_att$upper, ame_like_att$upper, ame_retweet_att$upper)
)
ame_df_att$Outcome <- factor(ame_df_att$Outcome, levels = c("Read more", "Like", "Share"))
ratio_att <- ((ame_like_att$AME + ame_retweet_att$AME) / 2) / ame_expand_att$AME

ame_plot_att <- ggplot(ame_df_att, aes(x = Outcome, y = AME, fill = Outcome)) +
  geom_bar(stat = "identity", width = 0.6, show.legend = FALSE) +
  geom_errorbar(aes(ymin = Lower, ymax = Upper), width = 0.2) +
  coord_flip() +
  ylab("AME (Predicted Change)") +
  xlab("") +
  scale_fill_brewer(palette = "Dark2") +
  labs(caption = paste("Avg(Like, Share)/Read more =", round(ratio_att, 2))) +
  theme_minimal(base_size = 14) +
  theme(
    legend.position = "none",
    plot.title = element_text(size = 16, face = "bold"),
    axis.title = element_text(size = 14),
    plot.caption = element_text(size = 12, hjust = 0.5, margin = margin(t = 10))
  )

combined_plot_att <- plot_grid(
  margins_plot_att, ame_plot_att,
  labels = c("A", "B"),
  ncol = 2,
  rel_widths = c(1, 1)
)
print(combined_plot_att)
ggsave(filename = "plots/ideomargins_attention.png", plot = combined_plot_att, width = 14, height = 7, dpi = 300)
