#############################################
# Joint FE-GLM: Ideology × Engagement vs Attention
# -----------------------------------------------
# Key change:
# - "Respondent universe" is defined as:
#     Qualtrics-analysis-eligible ∩ (any PostHog event)
# - Exposure panel = all such respondents × full tweet set
#   with expand/like/share = 0 if no tweet event occurred.
#############################################

library(dplyr)
library(readr)
library(tidyr)
library(forcats)
library(stringr)
library(fixest)
library(broom)
library(tibble)
library(ggplot2)
library(RColorBrewer)
library(cowplot)
library(metafor)
library(modelsummary)

options(scipen = 999)
set.seed(42)

# --------------------
# 1. Helpers
# --------------------

# Standardize numeric vectors (z-score)
z <- function(x) as.numeric(scale(x))

# Simple factor, keeping "Prefer not to say" as level (no exclusion)
fct <- function(x) factor(x, exclude = NULL)

# Build exposure frames with FULL exposure grid (all *valid* respondents x all tweets)
# - 'events' should contain tweet-level events (one row per PostHog event on a tweet)
# - 'persons' is the respondent-level dataset (Qualtrics) for valid IDs
# - id_var is the ID column name in 'persons' (and in 'events')
prep_exposure_full <- function(events,
                               persons,
                               id_var,
                               tweets_meta,   # columns: tweet_id, binary_tweet, endorsement (optional)
                               tweet_id_col = "tweet_id") {
  
  id_sym <- rlang::sym(id_var)
  
  # 1) Collapse tweet-level events to respondent–tweet binary indicators
  clicks <- events %>%
    filter(event_type %in% c("expand_tweet", "like_click", "retweet_click")) %>%
    transmute(
      id       = !!id_sym,
      tweet_id = .data[[tweet_id_col]],
      expand   = as.integer(event_type == "expand_tweet"),
      like     = as.integer(event_type == "like_click"),
      share    = as.integer(event_type == "retweet_click")
    ) %>%
    group_by(id, tweet_id) %>%
    summarise(
      expand = as.integer(any(expand == 1L)),
      like   = as.integer(any(like   == 1L)),
      share  = as.integer(any(share  == 1L)),
      .groups = "drop"
    )
  
  # 2) Universe: all VALID respondents x all tweets
  respondents <- persons %>%
    distinct(id = !!id_sym)
  
  tweets <- tweets_meta %>%
    distinct(tweet_id = .data[[tweet_id_col]])
  
  grid <- tidyr::expand_grid(id = respondents$id, tweet_id = tweets$tweet_id)
  
  # 3) Left-join clicks (fill missing as 0)
  expo <- grid %>%
    left_join(clicks, by = c("id", "tweet_id")) %>%
    mutate(
      expand = tidyr::replace_na(expand, 0L),
      like   = tidyr::replace_na(like,   0L),
      share  = tidyr::replace_na(share,  0L)
    )
  
  # 4) Join tweet attributes: binary_tweet (0=left, 1=right), endorsement
  tmeta <- tweets_meta %>%
    transmute(
      tweet_id     = .data[[tweet_id_col]],
      binary_tweet = as.integer(binary_tweet),
      endorsement  = dplyr::coalesce(endorsement, NA_real_)
    )
  
  expo <- expo %>% left_join(tmeta, by = "tweet_id")
  
  # 5) Join person covariates (at least ideology)
  pmeta <- persons %>%
    distinct(
      id = !!id_sym,
      ideo_numeric
      # add other covariates if desired
    )
  
  expo <- expo %>%
    left_join(pmeta, by = "id") %>%
    # Keep rows with valid ideology & tweet label
    filter(!is.na(ideo_numeric), !is.na(binary_tweet)) %>%
    # Rename "id" back to original id_var name for downstream convenience
    rename(!!id_var := id)
  
  expo
}

# Joint FE-GLM for a single study:
#  - expo_df: output from prep_exposure_full
#  - id_var:  respondent ID column name in expo_df
#  - study_label: label for output
fit_joint_fe_study <- function(expo_df, id_var, study_label) {
  
  # 1) Make "id" generic for formula convenience
  expo <- expo_df %>%
    rename(id = !!rlang::sym(id_var)) %>%
    filter(!is.na(ideo_numeric), !is.na(binary_tweet))
  
  # 2) Stack expand / like / share into long format
  expo_long <- expo %>%
    tidyr::pivot_longer(
      cols = c(expand, like, share),
      names_to  = "event_type",
      values_to = "y"
    ) %>%
    mutate(
      # baseline: expand (Read more) = attention
      event_type = factor(event_type, levels = c("expand", "like", "share"))
    )
  
  # 3) Joint FE logit with tweet FE + user FE and two-way clustering
  m_joint <- feglm(
    y ~ (ideo_numeric:binary_tweet) * event_type | tweet_id + id,
    data    = expo_long,
    family  = "binomial",
    cluster = ~ tweet_id + id
  )
  
  # 4) Extract coefficients & variance-covariance
  cf <- coef(m_joint)
  vc <- vcov(m_joint)
  
  base_term      <- "ideo_numeric:binary_tweet"
  like_int_term  <- "ideo_numeric:binary_tweet:event_typelike"
  share_int_term <- "ideo_numeric:binary_tweet:event_typeshare"
  
  needed <- c(base_term, like_int_term, share_int_term)
  if (!all(needed %in% names(cf))) {
    stop(sprintf("Missing expected coefficients in study '%s'. Check event_type levels.", study_label))
  }
  
  # Baseline slope (right-aligned tweets, event_type == expand/Read more)
  b_base <- cf[base_term]
  v_base <- vc[base_term, base_term]
  
  # Differences for Like and Share vs Read (interaction terms)
  b_like_diff  <- cf[like_int_term]
  v_like_diff  <- vc[like_int_term, like_int_term]
  
  b_share_diff <- cf[share_int_term]
  v_share_diff <- vc[share_int_term, share_int_term]
  
  # Full slopes for Like & Share: b_base + interaction
  cov_base_like  <- vc[base_term, like_int_term]
  cov_base_share <- vc[base_term, share_int_term]
  
  b_like  <- b_base + b_like_diff
  v_like  <- v_base + v_like_diff + 2 * cov_base_like
  
  b_share <- b_base + b_share_diff
  v_share <- v_base + v_share_diff + 2 * cov_base_share
  
  # SEs & 95% CIs
  se_base  <- sqrt(v_base)
  se_like  <- sqrt(v_like)
  se_share <- sqrt(v_share)
  
  se_like_diff  <- sqrt(v_like_diff)
  se_share_diff <- sqrt(v_share_diff)
  
  z <- 1.96
  
  summary_gradients <- tibble::tibble(
    study     = study_label,
    type      = c("slope", "slope", "slope", "difference", "difference"),
    outcome   = c("Read more", "Like", "Share", "Like - Read", "Share - Read"),
    estimate  = c(b_base, b_like, b_share, b_like_diff, b_share_diff),
    std.error = c(se_base, se_like, se_share, se_like_diff, se_share_diff),
    conf.low  = estimate - z * std.error,
    conf.high = estimate + z * std.error
  )
  
  list(model = m_joint, summary = summary_gradients)
}

# --------------------
# 2. Load & harmonize data (UK, US1, US2, US3)
# --------------------

##### Study 1: UK #####

cat("\n================ Study 1 (UK) ================\n")

qual_uk_raw  <- read_csv("data/UK/main/qualtrics.csv")
qual_uk      <- qual_uk_raw %>% slice(-1, -2)  # drop Qualtrics metadata rows

post_uk      <- read_csv("data/UK/main/posthog.csv")
tweets_uk    <- read_csv("data/UK/main/tweets.csv") %>%
  select(id, classification, retweets_count, likes_count) %>%
  mutate(
    endorsement_display = retweets_count + likes_count
  )

# Tweet-level meta: left vs right only (drop neutrals later via binary_tweet NA)
tweets_uk_meta <- tweets_uk %>%
  mutate(
    is_left  = classification %in% c("Very left","Somewhat left"),
    is_right = classification %in% c("Very right","Somewhat right"),
    binary_tweet = dplyr::case_when(
      is_left  ~ 0L,
      is_right ~ 1L,
      TRUE     ~ NA_integer_
    ),
    endorsement = endorsement_display
  ) %>%
  transmute(tweet_id = id, binary_tweet, endorsement)

# Qualtrics analysis-eligible respondents
qual_uk_clean <- qual_uk %>%
  mutate(
    ideo_numeric = as.numeric(gsub("\\D+", "", Q2_1)),
    gender       = if_else(Q9 == "Prefer not to say", NA_character_, Q9),
    gender       = fct(gender),
    age          = suppressWarnings(as.numeric(Q8))
  ) %>%
  filter(
    !is.na(Q1),
    !is.na(ideo_numeric),
    !is.na(age),
    age >= 18, age <= 65
  ) %>%
  mutate(
    ideo_numeric = z(ideo_numeric)
  ) %>%
  filter(Q13_1 == "No", Q13_2 == "No", Q13_3 == "No") %>%
  rename(prolific_id = Q1)

qual_uk_ids_analysis <- qual_uk_clean %>%
  pull(prolific_id) %>%
  unique()

cat("Qualtrics analysis-eligible IDs (UK): ", length(qual_uk_ids_analysis), "\n")

# PostHog IDs with any event
post_uk_ids_any <- post_uk %>%
  filter(!is.na(prolific_id)) %>%
  pull(prolific_id) %>%
  unique()

cat("PostHog IDs with any event (UK): ", length(post_uk_ids_any), "\n")

# Tweet-level events (join with tweets to keep only tweet rows)
post_uk_tweets <- post_uk %>%
  left_join(tweets_uk, by = c("tweet_id" = "id")) %>%
  filter(!is.na(classification))

post_uk_ids_tweets <- post_uk_tweets %>%
  filter(!is.na(prolific_id)) %>%
  pull(prolific_id) %>%
  unique()

cat("PostHog IDs with any TWEET event (UK): ", length(post_uk_ids_tweets), "\n")

# Valid IDs: intersection of Qualtrics-analysis-eligible and PostHog-any-event
valid_ids_uk <- intersect(qual_uk_ids_analysis, post_uk_ids_any)

cat("Valid IDs (Qualtrics ∩ PostHog-any) (UK): ", length(valid_ids_uk), "\n")

# Among valid IDs, how many actually have any tweet event?
valid_ids_uk_with_tweet <- intersect(valid_ids_uk, post_uk_ids_tweets)
cat("Valid IDs with at least one tweet event (UK): ", length(valid_ids_uk_with_tweet), "\n")

# Persons table for UK (universe of respondents in exposure grid)
persons_uk <- qual_uk_clean %>%
  filter(prolific_id %in% valid_ids_uk)

cat("Persons_uk n IDs (should match valid IDs): ",
    n_distinct(persons_uk$prolific_id), "\n")

##### Study 2: US1 #####

cat("\n================ Study 2 (US1) ================\n")

qual_us1_raw <- read_csv("data/US/main/qualtrics.csv")
qual_us1     <- qual_us1_raw %>% slice(-1, -2)

post_us1     <- read_csv("data/US/main/posthog.csv")
tweets_us1   <- read_csv("data/US/test/tweets.csv") %>%
  select(id, classification, rt_rand, like_rand) %>%
  rename(retweets_count = rt_rand, likes_count = like_rand) %>%
  mutate(
    endorsement_display = retweets_count + likes_count
  )

tweets_us1_meta <- tweets_us1 %>%
  mutate(
    is_left  = classification %in% c("Very left","Somewhat left"),
    is_right = classification %in% c("Very right","Somewhat right"),
    binary_tweet = dplyr::case_when(
      is_left  ~ 0L,
      is_right ~ 1L,
      TRUE     ~ NA_integer_
    ),
    endorsement = endorsement_display
  ) %>%
  transmute(tweet_id = id, binary_tweet, endorsement)

# Qualtrics analysis-eligible respondents (US1)
qual_us1_clean <- qual_us1 %>%
  mutate(
    ideo_numeric = as.numeric(gsub("\\D+", "", Q2_1)),
    gender       = if_else(Q9 == "Prefer not to say", NA_character_, Q9),
    gender       = fct(gender),
    age          = suppressWarnings(as.numeric(Q8))
  ) %>%
  filter(
    !is.na(rom_id),
    !is.na(ideo_numeric),
    !is.na(age),
    age >= 18, age <= 65
  ) %>%
  mutate(
    ideo_numeric = z(ideo_numeric)
  ) %>%
  filter(Q13_1 == "No", Q13_2 == "No", Q13_3 == "No") %>%
  rename(respondent_id = rom_id)

qual_us1_ids_analysis <- qual_us1_clean %>%
  pull(respondent_id) %>%
  unique()

cat("Qualtrics analysis-eligible IDs (US1): ", length(qual_us1_ids_analysis), "\n")

# PostHog IDs with any event
post_us1_ids_any <- post_us1 %>%
  filter(!is.na(respondent_id)) %>%
  pull(respondent_id) %>%
  unique()

cat("PostHog IDs with any event (US1): ", length(post_us1_ids_any), "\n")

# Tweet-level events
post_us1_tweets <- post_us1 %>%
  left_join(tweets_us1, by = c("tweet_id" = "id")) %>%
  filter(!is.na(classification))

post_us1_ids_tweets <- post_us1_tweets %>%
  filter(!is.na(respondent_id)) %>%
  pull(respondent_id) %>%
  unique()

cat("PostHog IDs with any TWEET event (US1): ", length(post_us1_ids_tweets), "\n")

# Valid IDs: intersection
valid_ids_us1 <- intersect(qual_us1_ids_analysis, post_us1_ids_any)

cat("Valid IDs (Qualtrics ∩ PostHog-any) (US1): ", length(valid_ids_us1), "\n")

valid_ids_us1_with_tweet <- intersect(valid_ids_us1, post_us1_ids_tweets)
cat("Valid IDs with at least one tweet event (US1): ", length(valid_ids_us1_with_tweet), "\n")

persons_us1 <- qual_us1_clean %>%
  filter(respondent_id %in% valid_ids_us1)

cat("Persons_us1 n IDs (should match valid IDs): ",
    n_distinct(persons_us1$respondent_id), "\n")

##### Study 3: US2 #####

cat("\n================ Study 3 (US2) ================\n")

qual_us2_raw <- read_csv("data/US/main2/qualtrics.csv")
qual_us2     <- qual_us2_raw %>% slice(-1, -2)

post_us2     <- read_csv("data/US/main2/posthog.csv")
tweets_us2   <- read_csv("data/US/main2/tweets.csv") %>%
  select(id, classification, rt_rand, like_rand) %>%
  rename(retweets_count = rt_rand, likes_count = like_rand) %>%
  mutate(
    endorsement_display = retweets_count + likes_count
  )

tweets_us2_meta <- tweets_us2 %>%
  mutate(
    is_left  = classification %in% c("Very left","Somewhat left"),
    is_right = classification %in% c("Very right","Somewhat right"),
    binary_tweet = dplyr::case_when(
      is_left  ~ 0L,
      is_right ~ 1L,
      TRUE     ~ NA_integer_
    ),
    endorsement = endorsement_display
  ) %>%
  transmute(tweet_id = id, binary_tweet, endorsement)

# Qualtrics analysis-eligible respondents (US2)
qual_us2_clean <- qual_us2 %>%
  mutate(
    ideo_numeric = as.numeric(gsub("\\D+", "", Q2_1)),
    gender       = if_else(Q9 == "Prefer not to say", NA_character_, Q9),
    gender       = fct(gender),
    age          = suppressWarnings(as.numeric(Q8))
  ) %>%
  filter(
    !is.na(Q1),
    !is.na(ideo_numeric),
    !is.na(age),
    age >= 18, age <= 65
  ) %>%
  mutate(
    ideo_numeric = z(ideo_numeric)
  ) %>%
  filter(Q13_1 == "No", Q13_2 == "No", Q13_3 == "No") %>%
  rename(prolific_id = Q1)

qual_us2_ids_analysis <- qual_us2_clean %>%
  pull(prolific_id) %>%
  unique()

cat("Qualtrics analysis-eligible IDs (US2): ", length(qual_us2_ids_analysis), "\n")

# PostHog IDs with any event
post_us2_ids_any <- post_us2 %>%
  filter(!is.na(prolific_id)) %>%
  pull(prolific_id) %>%
  unique()

cat("PostHog IDs with any event (US2): ", length(post_us2_ids_any), "\n")

# Tweet-level events
post_us2_tweets <- post_us2 %>%
  left_join(tweets_us2, by = c("tweet_id" = "id")) %>%
  filter(!is.na(classification))

post_us2_ids_tweets <- post_us2_tweets %>%
  filter(!is.na(prolific_id)) %>%
  pull(prolific_id) %>%
  unique()

cat("PostHog IDs with any TWEET event (US2): ", length(post_us2_ids_tweets), "\n")

# Valid IDs: intersection
valid_ids_us2 <- intersect(qual_us2_ids_analysis, post_us2_ids_any)

cat("Valid IDs (Qualtrics ∩ PostHog-any) (US2): ", length(valid_ids_us2), "\n")

valid_ids_us2_with_tweet <- intersect(valid_ids_us2, post_us2_ids_tweets)
cat("Valid IDs with at least one tweet event (US2): ", length(valid_ids_us2_with_tweet), "\n")

persons_us2 <- qual_us2_clean %>%
  filter(prolific_id %in% valid_ids_us2)

cat("Persons_us2 n IDs (should match valid IDs): ",
    n_distinct(persons_us2$prolific_id), "\n")

##### Study 4: US3 (Prolific Rep) #####

cat("\n================ Study 4 (US3) ================\n")

qual_us3_raw <- read_csv("data/US/main3/qualtrics.csv")
qual_us3     <- qual_us3_raw %>% slice(-1, -2)

post_us3     <- read_csv("data/US/main3/posthog.csv")
tweets_us3   <- read_csv("data/US/main3/tweets.csv") %>%
  select(id, classification, rt_rand, like_rand) %>%
  rename(retweets_count = rt_rand, likes_count = like_rand) %>%
  mutate(
    endorsement_display = retweets_count + likes_count
  )

tweets_us3_meta <- tweets_us3 %>%
  mutate(
    is_left  = classification %in% c("Very left","Somewhat left"),
    is_right = classification %in% c("Very right","Somewhat right"),
    binary_tweet = dplyr::case_when(
      is_left  ~ 0L,
      is_right ~ 1L,
      TRUE     ~ NA_integer_
    ),
    endorsement = endorsement_display
  ) %>%
  transmute(tweet_id = id, binary_tweet, endorsement)

# Qualtrics analysis-eligible respondents (US3)
qual_us3_clean <- qual_us3 %>%
  mutate(
    ideo_numeric = as.numeric(gsub("\\D+", "", Q2_1)),
    gender       = if_else(Q9 == "Prefer not to say", NA_character_, Q9),
    gender       = fct(gender),
    age          = suppressWarnings(as.numeric(Q8))
  ) %>%
  filter(
    !is.na(Q1),
    !is.na(ideo_numeric),
    !is.na(age),
    age >= 18, age <= 65
  ) %>%
  mutate(
    ideo_numeric = z(ideo_numeric)
  ) %>%
  filter(Q13_1 == "No", Q13_2 == "No", Q13_3 == "No") %>%
  rename(prolific_id = Q1)

qual_us3_ids_analysis <- qual_us3_clean %>%
  pull(prolific_id) %>%
  unique()

cat("Qualtrics analysis-eligible IDs (US3): ", length(qual_us3_ids_analysis), "\n")

# PostHog IDs with any event (any type)
post_us3_ids_any <- post_us3 %>%
  filter(!is.na(prolific_id)) %>%
  pull(prolific_id) %>%
  unique()

cat("PostHog IDs with any event (US3): ", length(post_us3_ids_any), "\n")

# Tweet-level events
post_us3_tweets <- post_us3 %>%
  left_join(tweets_us3, by = c("tweet_id" = "id")) %>%
  filter(!is.na(classification))

post_us3_ids_tweets <- post_us3_tweets %>%
  filter(!is.na(prolific_id)) %>%
  pull(prolific_id) %>%
  unique()

cat("PostHog IDs with any TWEET event (US3): ", length(post_us3_ids_tweets), "\n")

# Valid IDs: intersection
valid_ids_us3 <- intersect(qual_us3_ids_analysis, post_us3_ids_any)

cat("Valid IDs (Qualtrics ∩ PostHog-any) (US3): ", length(valid_ids_us3), "\n")

valid_ids_us3_with_tweet <- intersect(valid_ids_us3, post_us3_ids_tweets)
cat("Valid IDs with at least one tweet event (US3): ", length(valid_ids_us3_with_tweet), "\n")

persons_us3 <- qual_us3_clean %>%
  filter(prolific_id %in% valid_ids_us3)

cat("Persons_us3 n IDs (should match valid IDs): ",
    n_distinct(persons_us3$prolific_id), "\n")

# --------------------
# 3. Build exposure-level data (user x tweet)
# --------------------

cat("\n================ Build exposure panels ================\n")

data_uk_expo <- prep_exposure_full(
  events      = post_uk_tweets,
  persons     = persons_uk,
  id_var      = "prolific_id",
  tweets_meta = tweets_uk_meta
)

cat("Exposure IDs (UK): ",
    n_distinct(data_uk_expo$prolific_id), "\n")

data_us1_expo <- prep_exposure_full(
  events      = post_us1_tweets,
  persons     = persons_us1,
  id_var      = "respondent_id",
  tweets_meta = tweets_us1_meta
)

cat("Exposure IDs (US1): ",
    n_distinct(data_us1_expo$respondent_id), "\n")

data_us2_expo <- prep_exposure_full(
  events      = post_us2_tweets,
  persons     = persons_us2,
  id_var      = "prolific_id",
  tweets_meta = tweets_us2_meta
)

cat("Exposure IDs (US2): ",
    n_distinct(data_us2_expo$prolific_id), "\n")

data_us3_expo <- prep_exposure_full(
  events      = post_us3_tweets,
  persons     = persons_us3,
  id_var      = "prolific_id",
  tweets_meta = tweets_us3_meta
)

cat("Exposure IDs (US3): ",
    n_distinct(data_us3_expo$prolific_id), "\n")

# Quick diagnostic: how many exposure respondents have zero clicks of ANY type?
check_zero_clicks <- function(expo_df, id_var) {
  expo_df %>%
    group_by(!!rlang::sym(id_var)) %>%
    summarise(
      any_expand = any(expand == 1L),
      any_like   = any(like   == 1L),
      any_share  = any(share  == 1L),
      .groups    = "drop"
    ) %>%
    summarise(
      n_total     = n(),
      n_no_clicks = sum(!any_expand & !any_like & !any_share)
    )
}

cat("\nZero-click diagnostics:\n")
cat("UK:\n");   print(check_zero_clicks(data_uk_expo,  "prolific_id"))
cat("US1:\n");  print(check_zero_clicks(data_us1_expo, "respondent_id"))
cat("US2:\n");  print(check_zero_clicks(data_us2_expo, "prolific_id"))
cat("US3:\n");  print(check_zero_clicks(data_us3_expo, "prolific_id"))

# --------------------
# 4. Fit joint FE-GLMs and extract condensed gradients
# --------------------

joint_uk  <- fit_joint_fe_study(data_uk_expo,  id_var = "prolific_id",   study_label = "Study 1 (UK)")
joint_us1 <- fit_joint_fe_study(data_us1_expo, id_var = "respondent_id", study_label = "Study 2 (US)")
joint_us2 <- fit_joint_fe_study(data_us2_expo, id_var = "prolific_id",   study_label = "Study 3 (US)")
joint_us3 <- fit_joint_fe_study(data_us3_expo, id_var = "prolific_id",   study_label = "Study 4 (US)")

joint_summary_all <- bind_rows(
  joint_uk$summary,
  joint_us1$summary,
  joint_us2$summary,
  joint_us3$summary
)

cat("\n===== Condensed gradients & differences =====\n")
print(joint_summary_all)

# Ensure plots dir exists
dir.create("plots", showWarnings = FALSE, recursive = TRUE)

# Make sure 'study' and 'outcome' are nicely ordered
joint_summary_all <- joint_summary_all %>%
  mutate(
    study = factor(
      study,
      levels = c("Study 1 (UK)", "Study 2 (US)", "Study 3 (US)", "Study 4 (US)")
    ),
    outcome = factor(
      outcome,
      levels = c("Read more", "Like", "Share", "Like - Read", "Share - Read")
    )
  )

# Palette
pal3 <- brewer.pal(3, "Set1")
pal_named <- c(
  "Read more" = pal3[1],
  "Like"      = pal3[2],
  "Share"     = pal3[3]
)

## ------------------------
## A) Slopes plot (gradients)
## ------------------------

slopes_df <- joint_summary_all %>%
  filter(type == "slope") %>%
  filter(!is.na(estimate)) %>%
  mutate(
    outcome = factor(outcome, levels = c("Read more", "Like", "Share"))
  )

slopes_plot <- ggplot(
  slopes_df,
  aes(
    x = outcome,
    y = estimate,
    ymin = conf.low,
    ymax = conf.high,
    color = outcome
  )
) +
  geom_hline(yintercept = 0, linetype = "dashed", linewidth = 0.5, color = "grey50") +
  geom_pointrange(
    position = position_dodge(width = 0.4),
    linewidth = 0.8
  ) +
  coord_flip() +
  facet_wrap(~ study, nrow = 1, scales = "fixed") +
  scale_color_manual(values = pal_named, drop = FALSE) +
  labs(
    x = NULL,
    y = "Ideology gradient (log-odds per 1 SD)",
    color = NULL
  ) +
  theme_minimal(base_size = 14) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.major.x = element_line(color = "grey90", linewidth = 0.4),
    panel.grid.minor = element_blank(),
    axis.ticks.y = element_blank(),
    strip.text = element_text(size = 13, face = "bold"),
    legend.position = "right",
    legend.box = "horizontal",
    legend.margin = margin(t = 4, b = 4),
    plot.margin = margin(t = 10, r = 12, b = 5, l = 5)
  )

## ------------------------
## B) Differences plot
## ------------------------

diff_df <- joint_summary_all %>%
  filter(type == "difference") %>%
  filter(!is.na(estimate)) %>%
  mutate(
    outcome = factor(outcome, levels = c("Like - Read", "Share - Read"))
  )

diff_plot <- ggplot(
  diff_df,
  aes(
    x = outcome,
    y = estimate,
    ymin = conf.low,
    ymax = conf.high
  )
) +
  geom_hline(yintercept = 0, linetype = "dashed", linewidth = 0.5, color = "grey50") +
  geom_pointrange(
    linewidth = 0.8,
    color = "black"
  ) +
  coord_flip() +
  facet_wrap(~ study, nrow = 1, scales = "fixed") +
  labs(
    x = NULL,
    y = "Difference in gradient (log-odds per 1 SD)\nvs. Read more"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.major.x = element_line(color = "grey90", linewidth = 0.4),
    panel.grid.minor = element_blank(),
    axis.ticks.y = element_blank(),
    strip.text = element_text(size = 13, face = "bold"),
    legend.position = "none",
    plot.margin = margin(t = 5, r = 12, b = 10, l = 5)
  )

# ------------------------
# 5. Meta-analysis with FE and REML
# ------------------------

joint_summary_all <- joint_summary_all %>%
  mutate(
    study = factor(
      study,
      levels = c("Study 1 (UK)", "Study 2 (US)", "Study 3 (US)", "Study 4 (US)")
    ),
    outcome = factor(
      outcome,
      levels = c("Read more", "Like", "Share", "Like - Read", "Share - Read")
    )
  )

meta_all <- joint_summary_all %>%
  filter(
    !is.na(estimate),
    !is.na(std.error),
    std.error > 0
  ) %>%
  group_by(type, outcome) %>%
  group_modify(~{
    dat <- .x
    
    # Fixed-effect meta-analysis
    fit_fe <- rma.uni(
      yi  = dat$estimate,
      sei = dat$std.error,
      method = "FE"
    )
    
    # Random-effects (REML) meta-analysis
    fit_re <- rma.uni(
      yi  = dat$estimate,
      sei = dat$std.error,
      method = "REML"
    )
    
    tibble(
      meta_method = c("FE", "REML"),
      estimate    = c(as.numeric(fit_fe$b),  as.numeric(fit_re$b)),
      std.error   = c(fit_fe$se,             fit_re$se),
      conf.low    = c(fit_fe$ci.lb,          fit_re$ci.lb),
      conf.high   = c(fit_fe$ci.ub,          fit_re$ci.ub),
      tau2        = c(fit_fe$tau2,           fit_re$tau2),
      Q           = c(fit_fe$QE,             fit_re$QE),
      Q_p         = c(fit_fe$QEp,            fit_re$QEp),
      I2          = c(fit_fe$I2,             fit_re$I2)
    )
  }) %>%
  ungroup() %>%
  mutate(
    meta_method = factor(
      meta_method,
      levels = c("FE", "REML"),
      labels = c("Fixed-effect (FE)", "Random-effects (REML)")
    ),
    outcome = factor(
      outcome,
      levels = c("Read more", "Like", "Share", "Like - Read", "Share - Read")
    )
  )

# ------------------------
# 5.2 Build combined datasets for facets (studies + pooled)
# ------------------------

# A) Slopes (gradients)

slopes_study_df <- joint_summary_all %>%
  filter(type == "slope") %>%
  filter(!is.na(estimate)) %>%
  mutate(
    outcome     = factor(outcome, levels = c("Read more", "Like", "Share")),
    meta_method = factor("Study-level",
                         levels = c("Study-level", "Fixed-effect (FE)", "Random-effects (REML)")),
    study       = factor(
      study,
      levels = c("Study 1 (UK)", "Study 2 (US)", "Study 3 (US)", "Study 4 (US)")
    )
  )

slopes_meta_df <- meta_all %>%
  filter(type == "slope") %>%
  mutate(
    study = factor("Pooled", levels = c("Study 1 (UK)", "Study 2 (US)", "Study 3 (US)",
                                        "Study 4 (US)", "Pooled")),
    meta_method = factor(meta_method,
                         levels = c("Study-level", "Fixed-effect (FE)", "Random-effects (REML)")),
    outcome = factor(outcome, levels = c("Read more", "Like", "Share"))
  )

slopes_study_df <- slopes_study_df %>%
  mutate(
    study = factor(
      as.character(study),
      levels = c("Study 1 (UK)", "Study 2 (US)", "Study 3 (US)", "Study 4 (US)", "Pooled")
    )
  )

slopes_all_df <- bind_rows(
  slopes_study_df,
  slopes_meta_df
)

# B) Differences (Like-Read / Share-Read)

diff_study_df <- joint_summary_all %>%
  filter(type == "difference") %>%
  filter(!is.na(estimate)) %>%
  mutate(
    outcome     = factor(outcome, levels = c("Like - Read", "Share - Read")),
    meta_method = factor("Study-level",
                         levels = c("Study-level", "Fixed-effect (FE)", "Random-effects (REML)")),
    study       = factor(
      study,
      levels = c("Study 1 (UK)", "Study 2 (US)", "Study 3 (US)", "Study 4 (US)")
    )
  )

diff_meta_df <- meta_all %>%
  filter(type == "difference") %>%
  mutate(
    study = factor("Pooled", levels = c("Study 1 (UK)", "Study 2 (US)", "Study 3 (US)",
                                        "Study 4 (US)", "Pooled")),
    meta_method = factor(meta_method,
                         levels = c("Study-level", "Fixed-effect (FE)", "Random-effects (REML)")),
    outcome = factor(outcome, levels = c("Like - Read", "Share - Read"))
  )

diff_study_df <- diff_study_df %>%
  mutate(
    study = factor(
      as.character(study),
      levels = c("Study 1 (UK)", "Study 2 (US)", "Study 3 (US)", "Study 4 (US)", "Pooled")
    )
  )

diff_all_df <- bind_rows(
  diff_study_df,
  diff_meta_df
)

# ------------------------
# 5.3 Plot aesthetics
# ------------------------

meta_cols <- c(
  "Study-level"          = "grey40",
  "Fixed-effect (FE)"    = "#1b9e77",
  "Random-effects (REML)"= "#d95f02"
)

meta_shapes <- c(
  "Study-level"          = 16,  # solid circle
  "Fixed-effect (FE)"    = 17,  # triangle
  "Random-effects (REML)"= 15   # square
)

# ------------------------
# 5.4 Final plots: Row A (slopes) & Row B (differences),
#      with pooled FE/REML as last facet
# ------------------------

slopes_plot_all <- ggplot(
  slopes_all_df,
  aes(
    x = outcome,
    y = estimate,
    ymin = conf.low,
    ymax = conf.high,
    color = meta_method,
    shape = meta_method
  )
) +
  geom_hline(yintercept = 0, linetype = "dashed", linewidth = 0.5, color = "grey50") +
  geom_pointrange(
    position = position_dodge(width = 0.3),
    linewidth = 0.7
  ) +
  coord_flip() +
  facet_wrap(~ study, nrow = 1, scales = "fixed") +
  scale_color_manual(values = meta_cols, name = NULL) +
  scale_shape_manual(values = meta_shapes, name = NULL) +
  labs(
    x = NULL,
    y = "Ideology gradient (log-odds per 1 SD)"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.major.x = element_line(color = "grey90", linewidth = 0.4),
    panel.grid.minor   = element_blank(),
    axis.ticks.y       = element_blank(),
    strip.text         = element_text(size = 13, face = "bold"),
    legend.position    = "right",
    legend.box         = "horizontal",
    legend.margin      = margin(t = 4, b = 4),
    plot.margin        = margin(t = 10, r = 12, b = 5, l = 5)
  )

diff_plot_all <- ggplot(
  diff_all_df,
  aes(
    x = outcome,
    y = estimate,
    ymin = conf.low,
    ymax = conf.high,
    color = meta_method,
    shape = meta_method
  )
) +
  geom_hline(yintercept = 0, linetype = "dashed", linewidth = 0.5, color = "grey50") +
  geom_pointrange(
    position = position_dodge(width = 0.3),
    linewidth = 0.7
  ) +
  coord_flip() +
  facet_wrap(~ study, nrow = 1, scales = "fixed") +
  scale_color_manual(values = meta_cols, name = NULL) +
  scale_shape_manual(values = meta_shapes, name = NULL) +
  labs(
    x = NULL,
    y = "Difference in gradient (log-odds per 1 SD)\nvs. Read more"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.major.x = element_line(color = "grey90", linewidth = 0.4),
    panel.grid.minor   = element_blank(),
    axis.ticks.y       = element_blank(),
    strip.text         = element_text(size = 13, face = "bold"),
    legend.position    = "right",
    plot.margin        = margin(t = 5, r = 12, b = 10, l = 5)
  )

combined_joint_meta <- plot_grid(
  slopes_plot_all,
  diff_plot_all,
  ncol = 1,
  labels = c("A", "B"),
  label_size = 16,
  rel_heights = c(1.5, 1.5)
)

print(combined_joint_meta)

ggsave(
  filename = "plots/joint_fe_gradients_zeros_attention.png",
  plot     = combined_joint_meta,
  width    = 12,
  height   = 8,
  dpi      = 300
)

#############################################
# 6. LaTeX regression table for joint FE-GLMs
#############################################

# Use kableExtra backend for nicer LaTeX
options(modelsummary_factory_latex = "kableExtra")

# Helper: sanitize TeX special characters (no Unicode)
sanitize_tex <- function(x) {
  x <- gsub("–|—", "-", x, perl = TRUE)
  x <- gsub("%", "\\\\%", x, perl = TRUE)
  x <- gsub("&", "\\\\&", x, perl = TRUE)
  x <- gsub("_", "\\\\_", x, perl = TRUE)
  x <- gsub("#", "\\\\#", x, perl = TRUE)
  # IMPORTANT: remove any stray Unicode Delta / times if they ever appear
  x <- gsub("\u0394", "Delta", x, perl = TRUE)   # Δ -> Delta
  x <- gsub("\u00D7", "x",      x, perl = TRUE)   # × -> x
  x
}

# Helper: wrap tables to fit page width + apply Sociological Science / ASA
# table-preparation fixes (readable GOF labels; numbered estimate columns).
wrap_table_for_page_fit <- function(tex_file) {
  if (!file.exists(tex_file)) return(invisible(NULL))
  lines <- readLines(tex_file, warn = FALSE)

  # (0) Undo kableExtra escaping of LaTeX math in coefficient labels.
  lines <- gsub("\\\\textbackslash\\{\\}", "\\\\", lines)

  # (0b) Journal rule: significance signifiers must be one character wide, so
  #      render the p<0.01 marker as a dagger (\dag) rather than '**'.
  lines <- gsub("\\*\\*", "\\\\dag", lines)

  # (a) No software variable names in GOF rows.
  lines <- gsub("Num.Obs.",      "Observations",  lines, fixed = TRUE)
  lines <- gsub("FE: id",        "Respondent FE", lines, fixed = TRUE)
  lines <- gsub("FE: tweet\\_id", "Tweet FE",     lines, fixed = TRUE)

  # (b) Number the estimate columns (1)-(4) just below the study-name header.
  hdr <- which(grepl("Study 1 \\(UK\\)", lines))
  if (length(hdr)) {
    num_row <- " & (1) & (2) & (3) & (4)\\\\"
    lines <- append(lines, num_row, after = hdr[1])
  }

  # (c) Wrap tabular to page width.
  b <- which(grepl("\\\\begin\\{tabular\\}", lines))
  e <- which(grepl("\\\\end\\{tabular\\}",   lines))
  if (length(b) && length(e)) {
    lines <- c(
      lines[1:(b[1]-1)],
      "\\resizebox{\\textwidth}{!}{%",
      lines[b[1]:e[length(e)]],
      "}",
      lines[(e[length(e)]+1):length(lines)]
    )
    lines <- gsub("@\\{\\\\extracolsep\\{5pt\\}\\}", "@{\\\\extracolsep{2pt}}", lines)
  }
  writeLines(lines, tex_file)
  invisible(NULL)
}

# Make sure output directory exists
dir.create("tables", showWarnings = FALSE, recursive = TRUE)

joint_models <- list(
  "Study 1 (UK)" = joint_uk$model,
  "Study 2 (US)" = joint_us1$model,
  "Study 3 (US)" = joint_us2$model,
  "Study 4 (US)" = joint_us3$model
)

coef_map_joint <- c(
  "ideo_numeric:binary_tweet" =
    "Ideology \\(\\times\\) Right (Read more)",
  "ideo_numeric:binary_tweet:event_typelike" =
    "Ideology \\(\\times\\) Right \\(\\times\\) Like (Delta vs. Read)",
  "ideo_numeric:binary_tweet:event_typeshare" =
    "Ideology \\(\\times\\) Right \\(\\times\\) Share (Delta vs. Read)"
)

coef_map_joint_tex <- setNames(
  sanitize_tex(unname(coef_map_joint)),
  names(coef_map_joint)
)

tex_file <- "tables/joint_fe_glm_ideology_gradients_zeros_attention.tex"

msummary(
  joint_models,
  coef_map  = coef_map_joint_tex,
  coef_omit = "^(Intercept)|^event_type",
  gof_map   = c("nobs", "FE: id", "FE: tweet_id"),
  stars     = c('*' = 0.05, '**' = 0.01),
  title     = sanitize_tex("Joint FE Logit: Attention-Check Passers, Expanded Panel Including Non-Clickers"),
  output    = tex_file
)

wrap_table_for_page_fit(tex_file)

message("LaTeX regression table written to: ", tex_file)
