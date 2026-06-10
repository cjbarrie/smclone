#############################################
# Joint FE-GLM: Ideology × Engagement vs Attention
# -----------------------------------------------
# Per study:
# - Build user x tweet exposure data
# - Fit joint FE logit:
#     y ~ (ideo_numeric:binary_tweet) * event_type | tweet_id + id
# - Extract:
#     * slope(Read more), slope(Like), slope(Share)
#     * differences: slope(Like) - slope(Read), slope(Share) - slope(Read)
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
library(dplyr)
library(RColorBrewer)
library(cowplot)
library(metafor)
library(purrr)
library(scales)   # percent_format() used in the sensitivity plot below

options(scipen = 999)
set.seed(42)

# --------------------
# 1. Helpers
# --------------------

# Standardize numeric vectors (z-score)
z <- function(x) as.numeric(scale(x))

# Simple factor, keeping "Prefer not to say" as level (no exclusion)
fct <- function(x) factor(x, exclude = NULL)

# Build exposure frames with FULL exposure grid (all respondents x all tweets)
# Assumes a fixed tweet set shared by all participants.
prep_exposure_full <- function(events,
                               id_var,
                               tweets_meta,   # columns: tweet_id, binary_tweet, endorsement (optional)
                               tweet_id_col = "tweet_id") {
  
  # 1) Summarise clicks per respondent–tweet: any expand / like / share -> 1
  clicks <- events %>%
    filter(event_type %in% c("expand_tweet", "like_click", "retweet_click")) %>%
    transmute(
      id       = .data[[id_var]],
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
  
  # 2) Universe: all respondents x all tweets (standard 120-tweet set)
  respondents <- events %>%
    distinct(id = .data[[id_var]])
  tweets      <- tweets_meta %>%
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
  pmeta <- events %>%
    distinct(
      id = .data[[id_var]],
      ideo_numeric
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

## --- UK

qual_uk  <- read_csv("data/UK/main/qualtrics.csv") %>% slice(-1, -2)
post_uk  <- read_csv("data/UK/main/posthog.csv")
tweets_uk <- read_csv("data/UK/main/tweets.csv") %>%
  select(id, classification, retweets_count, likes_count) %>%
  mutate(
    endorsement_display = retweets_count + likes_count
  )

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

# Event-level data with user covariates
data_uk_full <- post_uk %>%
  left_join(tweets_uk, by = c("tweet_id" = "id")) %>%
  filter(!is.na(classification)) %>%
  left_join(qual_uk, by = c("prolific_id" = "Q1")) %>%
  filter(!is.na(prolific_id)) %>%
  mutate(
    ideo_numeric = as.numeric(gsub("\\D+", "", Q2_1)),
    gender       = if_else(Q9 == "Prefer not to say", NA_character_, Q9),
    gender       = fct(gender),
    age          = suppressWarnings(as.numeric(Q8))
  ) %>%
  filter(!is.na(ideo_numeric), !is.na(age), age >= 18, age <= 65) %>%
  mutate(
    ideo_numeric = z(ideo_numeric)
  )

## --- US1

qual_us1 <- read_csv("data/US/main/qualtrics.csv") %>% slice(-1, -2)
post_us1 <- read_csv("data/US/main/posthog.csv")
tweets_us1 <- read_csv("data/US/test/tweets.csv") %>%
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

data_us1_full <- post_us1 %>%
  left_join(tweets_us1, by = c("tweet_id" = "id")) %>%
  filter(!is.na(classification)) %>%
  left_join(qual_us1, by = c("respondent_id" = "rom_id")) %>%
  filter(!is.na(respondent_id)) %>%
  mutate(
    ideo_numeric = as.numeric(gsub("\\D+", "", Q2_1)),
    gender       = if_else(Q9 == "Prefer not to say", NA_character_, Q9),
    gender       = fct(gender),
    age          = suppressWarnings(as.numeric(Q8))
  ) %>%
  filter(!is.na(ideo_numeric), !is.na(age), age >= 18, age <= 65) %>%
  mutate(
    ideo_numeric = z(ideo_numeric)
  )

## --- US2

qual_us2 <- read_csv("data/US/main2/qualtrics.csv") %>% slice(-1, -2)
post_us2 <- read_csv("data/US/main2/posthog.csv")
tweets_us2 <- read_csv("data/US/main2/tweets.csv") %>%
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

data_us2_full <- post_us2 %>%
  left_join(tweets_us2, by = c("tweet_id" = "id")) %>%
  filter(!is.na(classification)) %>%
  left_join(qual_us2, by = c("prolific_id" = "Q1")) %>%
  filter(!is.na(prolific_id)) %>%
  mutate(
    ideo_numeric = as.numeric(gsub("\\D+", "", Q2_1)),
    gender       = if_else(Q9 == "Prefer not to say", NA_character_, Q9),
    gender       = fct(gender),
    age          = suppressWarnings(as.numeric(Q8))
  ) %>%
  filter(!is.na(ideo_numeric), !is.na(age), age >= 18, age <= 65) %>%
  mutate(
    ideo_numeric = z(ideo_numeric)
  )

## --- US3 (Prolific Rep)

qual_us3 <- read_csv("data/US/main3/qualtrics.csv") %>% slice(-1, -2)
post_us3 <- read_csv("data/US/main3/posthog.csv")
tweets_us3 <- read_csv("data/US/main3/tweets.csv") %>%
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

data_us3_full <- post_us3 %>%
  left_join(tweets_us3, by = c("tweet_id" = "id")) %>%
  filter(!is.na(classification)) %>%
  left_join(qual_us3, by = c("prolific_id" = "Q1")) %>%
  filter(!is.na(prolific_id)) %>%
  mutate(
    ideo_numeric = as.numeric(gsub("\\D+", "", Q2_1)),
    gender       = if_else(Q9 == "Prefer not to say", NA_character_, Q9),
    gender       = fct(gender),
    age          = suppressWarnings(as.numeric(Q8))
  ) %>%
  filter(!is.na(ideo_numeric), !is.na(age), age >= 18, age <= 65) %>%
  mutate(
    ideo_numeric = z(ideo_numeric)
  )

# --------------------
# 3. Build exposure-level data (user x tweet)
# --------------------

data_uk_expo  <- prep_exposure_full(data_uk_full,  id_var = "prolific_id",   tweets_meta = tweets_uk_meta)
data_us1_expo <- prep_exposure_full(data_us1_full, id_var = "respondent_id", tweets_meta = tweets_us1_meta)
data_us2_expo <- prep_exposure_full(data_us2_full, id_var = "prolific_id",   tweets_meta = tweets_us2_meta)
data_us3_expo <- prep_exposure_full(data_us3_full, id_var = "prolific_id",   tweets_meta = tweets_us3_meta)

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

# View condensed gradients & differences
print(joint_summary_all)

# If you want, you can also write this to CSV:
# write_csv(joint_summary_all, "tables/joint_fe_gradients_and_differences.csv")

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

# ------------------------
# 5.1 Meta-analysis with FE and REML
# ------------------------

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

# Study-level slopes (one method: "Study-level")
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

# Pooled slopes (FE & REML) as "Pooled" facet
slopes_meta_df <- meta_all %>%
  filter(type == "slope") %>%
  mutate(
    study = factor("Pooled", levels = c("Study 1 (UK)", "Study 2 (US)", "Study 3 (US)",
                                        "Study 4 (US)", "Pooled")),
    meta_method = factor(meta_method,
                         levels = c("Study-level", "Fixed-effect (FE)", "Random-effects (REML)")),
    outcome = factor(outcome, levels = c("Read more", "Like", "Share"))
  )

# Align study factor levels across both
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

# Row A: slopes
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

# Row B: differences
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
    legend.position    = "right",   # legend already in Row A
    plot.margin        = margin(t = 5, r = 12, b = 10, l = 5)
  )

# ------------------------
# 5.5 Combine rows A & B into one figure
# ------------------------

combined_joint_meta <- plot_grid(
  slopes_plot_all,   # Row A: Study-level + Pooled slopes (FE & REML)
  diff_plot_all,     # Row B: Study-level + Pooled differences (FE & REML)
  ncol = 1,
  labels = c("A", "B"),
  label_size = 16,
  rel_heights = c(1.5, 1.5)
)

print(combined_joint_meta)

ggsave(
  filename = "plots/joint_fe_gradients.png",
  plot     = combined_joint_meta,
  width    = 12,
  height   = 8,
  dpi      = 300
)

#############################################
# 6. LaTeX regression table for joint FE-GLMs
#############################################

library(modelsummary)

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

  # (0) Undo kableExtra escaping of LaTeX math in coefficient labels
  #     (e.g. "\textbackslash{}(\textbackslash{}times\textbackslash{})" -> "\(\times\)").
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

# Collect the four joint FE-GLMs in a named list
joint_models <- list(
  "Study 1 (UK)" = joint_uk$model,
  "Study 2 (US)" = joint_us1$model,
  "Study 3 (US)" = joint_us2$model,
  "Study 4 (US)" = joint_us3$model
)

# Coefficient labels – no Unicode, use LaTeX math for × and plain "Delta"
coef_map_joint <- c(
  "ideo_numeric:binary_tweet" =
    "Ideology \\(\\times\\) Right (Read more)",
  "ideo_numeric:binary_tweet:event_typelike" =
    "Ideology \\(\\times\\) Right \\(\\times\\) Like (Delta vs. Read)",
  "ideo_numeric:binary_tweet:event_typeshare" =
    "Ideology \\(\\times\\) Right \\(\\times\\) Share (Delta vs. Read)"
)

# Sanitize labels for TeX (in case anything weird slipped in)
coef_map_joint_tex <- setNames(
  sanitize_tex(unname(coef_map_joint)),
  names(coef_map_joint)
)

# File name for LaTeX table
tex_file <- "tables/joint_fe_glm_ideology_gradients.tex"

msummary(
  joint_models,
  coef_map  = coef_map_joint_tex,
  # drop intercept and event_type main effects to keep table compact
  coef_omit = "^(Intercept)|^event_type",
  gof_map   = c("nobs", "FE: id", "FE: tweet_id"),
  stars     = c('*' = 0.05, '**' = 0.01),
  title     = sanitize_tex("Joint FE Logit: Baseline Clicker-Restricted Assigned-Post Panel"),
  output    = tex_file
)

wrap_table_for_page_fit(tex_file)

message("LaTeX regression table written to: ", tex_file)


#############################################
# 7. Sample counts for text (fixed join)
#############################################

sample_counts <- function(qual_df,
                          post_df,
                          data_full_df,
                          id_qual,      # name of ID column in Qualtrics (string)
                          id_post,      # name of ID column in PostHog (string)
                          study_label,
                          click_events = c("expand_tweet", "like_click", "retweet_click")) {
  
  # mapping: x = post_df, y = qual_df
  # by = c("x_col" = "y_col")
  by_post_qual <- setNames(id_qual, id_post)  # e.g. c("prolific_id" = "Q1")
  
  # 1) IDs that appear in BOTH Qualtrics and PostHog (any event type)
  ids_in_both <- post_df %>%
    filter(!is.na(.data[[id_post]])) %>%
    semi_join(
      qual_df %>% filter(!is.na(.data[[id_qual]])),
      by = by_post_qual
    ) %>%
    pull(.data[[id_post]]) %>%
    unique()
  
  n_enrolled <- length(ids_in_both)
  
  # 2) Valid analysis IDs: those that survive filters in data_*_full
  #    (ideology, age, etc. already applied there)
  id_full <- intersect(c("prolific_id", "respondent_id"), names(data_full_df))
  if (length(id_full) != 1L) {
    stop("Cannot determine ID column in data_full_df")
  }
  id_full <- id_full[[1]]
  
  valid_ids <- data_full_df %>%
    pull(.data[[id_full]]) %>%
    unique()
  
  n_valid <- length(valid_ids)
  
  # 3) Among valid IDs, who clicked at least once (expand / like / share)?
  clicked_ids <- post_df %>%
    filter(event_type %in% click_events) %>%
    filter(!is.na(.data[[id_post]])) %>%
    semi_join(
      qual_df %>% filter(!is.na(.data[[id_qual]])),
      by = by_post_qual
    ) %>%
    pull(.data[[id_post]]) %>%
    unique()
  
  n_clicked_valid <- sum(valid_ids %in% clicked_ids)
  
  tibble(
    study           = study_label,
    n_enrolled      = n_enrolled,
    n_valid         = n_valid,
    n_clicked_valid = n_clicked_valid
  )
}

# Then re-run:
sample_uk <- sample_counts(
  qual_df      = qual_uk,
  post_df      = post_uk,
  data_full_df = data_uk_full,
  id_qual      = "Q1",
  id_post      = "prolific_id",
  study_label  = "Study 1 (UK)"
)

sample_us1 <- sample_counts(
  qual_df      = qual_us1,
  post_df      = post_us1,
  data_full_df = data_us1_full,
  id_qual      = "rom_id",
  id_post      = "respondent_id",
  study_label  = "Study 2 (US)"
)

sample_us2 <- sample_counts(
  qual_df      = qual_us2,
  post_df      = post_us2,
  data_full_df = data_us2_full,
  id_qual      = "Q1",
  id_post      = "prolific_id",
  study_label  = "Study 3 (US)"
)

sample_us3 <- sample_counts(
  qual_df      = qual_us3,
  post_df      = post_us3,
  data_full_df = data_us3_full,
  id_qual      = "Q1",
  id_post      = "prolific_id",
  study_label  = "Study 4 (US)"
)

sample_summary <- bind_rows(sample_uk, sample_us1, sample_us2, sample_us3)
print(sample_summary)


# ------------------------------------------------------------------
# 8.1 Helper: flip tweet ideological labels under different regimes
# ------------------------------------------------------------------

flip_tweet_labels_mode <- function(tweets_meta,
                                   p_flip,
                                   mode = c("random", "right_only", "left_only"),
                                   tweet_id_col = "tweet_id") {
  mode <- match.arg(mode)
  df   <- tweets_meta
  
  # work only on tweets with defined binary_tweet
  valid_idx <- which(!is.na(df$binary_tweet))
  
  if (length(valid_idx) == 0L || p_flip <= 0) {
    return(df)
  }
  
  if (mode == "random") {
    n_valid <- length(valid_idx)
    n_flip  <- round(p_flip * n_valid)
    if (n_flip == 0L) return(df)
    
    flip_idx <- sample(valid_idx, size = n_flip, replace = FALSE)
    df$binary_tweet[flip_idx] <- 1L - df$binary_tweet[flip_idx]
    return(df)
  }
  
  if (mode == "right_only") {
    right_idx <- valid_idx[df$binary_tweet[valid_idx] == 1L]
    n_valid_right <- length(right_idx)
    if (n_valid_right == 0L) return(df)
    
    n_flip <- round(p_flip * n_valid_right)
    if (n_flip == 0L) return(df)
    
    flip_idx <- sample(right_idx, size = n_flip, replace = FALSE)
    df$binary_tweet[flip_idx] <- 0L
    return(df)
  }
  
  if (mode == "left_only") {
    left_idx <- valid_idx[df$binary_tweet[valid_idx] == 0L]
    n_valid_left <- length(left_idx)
    if (n_valid_left == 0L) return(df)
    
    n_flip <- round(p_flip * n_valid_left)
    if (n_flip == 0L) return(df)
    
    flip_idx <- sample(left_idx, size = n_flip, replace = FALSE)
    df$binary_tweet[flip_idx] <- 1L
    return(df)
  }
  
  df
}

#############################################
# 8. Sensitivity to tweet ideology misclassification
#############################################

set.seed(2025)

# ------------------------------------------------------------------
# 8.1 Random misclassification: helper to flip tweet labels (0 <-> 1)
# ------------------------------------------------------------------

flip_tweet_labels <- function(tweets_meta, p_flip, tweet_id_col = "tweet_id") {
  df <- tweets_meta
  
  # Only flip tweets with defined binary_tweet
  valid_idx <- which(!is.na(df$binary_tweet))
  n_valid   <- length(valid_idx)
  
  if (n_valid == 0L || p_flip <= 0) return(df)
  
  n_flip <- round(p_flip * n_valid)
  if (n_flip == 0L) return(df)
  
  flip_idx <- sample(valid_idx, size = n_flip, replace = FALSE)
  
  # Flip 0 <-> 1
  df$binary_tweet[flip_idx] <- 1L - df$binary_tweet[flip_idx]
  df
}

# ------------------------------------------------------------------
# 8.2 One random misclassification run at rate p_flip
#     - flips labels in ALL four studies
#     - rebuilds exposure panels
#     - re-fits joint FE-GLMs
#     - runs REML meta-analysis for Δ(Like-Read), Δ(Share-Read)
# ------------------------------------------------------------------

run_one_misclass_sim <- function(p_flip) {
  message("Running random misclassification with p_flip = ", p_flip)
  
  # 1) Flip labels in each study's tweet meta
  tweets_uk_meta_mis  <- flip_tweet_labels(tweets_uk_meta,  p_flip)
  tweets_us1_meta_mis <- flip_tweet_labels(tweets_us1_meta, p_flip)
  tweets_us2_meta_mis <- flip_tweet_labels(tweets_us2_meta, p_flip)
  tweets_us3_meta_mis <- flip_tweet_labels(tweets_us3_meta, p_flip)
  
  # 2) Rebuild exposure panels (user x tweet)
  data_uk_expo_mis  <- prep_exposure_full(
    events      = data_uk_full,
    id_var      = "prolific_id",
    tweets_meta = tweets_uk_meta_mis
  )
  data_us1_expo_mis <- prep_exposure_full(
    events      = data_us1_full,
    id_var      = "respondent_id",
    tweets_meta = tweets_us1_meta_mis
  )
  data_us2_expo_mis <- prep_exposure_full(
    events      = data_us2_full,
    id_var      = "prolific_id",
    tweets_meta = tweets_us2_meta_mis
  )
  data_us3_expo_mis <- prep_exposure_full(
    events      = data_us3_full,
    id_var      = "prolific_id",
    tweets_meta = tweets_us3_meta_mis
  )
  
  # 3) Re-fit joint FE-GLMs
  joint_uk_mis  <- fit_joint_fe_study(data_uk_expo_mis,  id_var = "prolific_id",   study_label = "Study 1 (UK)")
  joint_us1_mis <- fit_joint_fe_study(data_us1_expo_mis, id_var = "respondent_id", study_label = "Study 2 (US)")
  joint_us2_mis <- fit_joint_fe_study(data_us2_expo_mis, id_var = "prolific_id",   study_label = "Study 3 (US)")
  joint_us3_mis <- fit_joint_fe_study(data_us3_expo_mis, id_var = "prolific_id",   study_label = "Study 4 (US)")
  
  joint_summary_mis <- bind_rows(
    joint_uk_mis$summary,
    joint_us1_mis$summary,
    joint_us2_mis$summary,
    joint_us3_mis$summary
  )
  
  # 4) REML meta-analysis for the differences
  meta_mis <- joint_summary_mis %>%
    filter(
      type == "difference",
      outcome %in% c("Like - Read", "Share - Read"),
      !is.na(estimate),
      !is.na(std.error),
      std.error > 0
    ) %>%
    group_by(type, outcome) %>%
    group_modify(~{
      dat    <- .x
      fit_re <- rma.uni(
        yi  = dat$estimate,
        sei = dat$std.error,
        method = "REML"
      )
      tibble(
        estimate  = as.numeric(fit_re$b),
        std.error = fit_re$se,
        conf.low  = fit_re$ci.lb,
        conf.high = fit_re$ci.ub
      )
    }) %>%
    ungroup() %>%
    mutate(p_flip = p_flip)
  
  meta_mis
}

# ------------------------------------------------------------------
# 8.3 Run random misclassification simulations across a grid of p_flip
# ------------------------------------------------------------------

p_grid <- c(0, 0.10, 0.20, 0.30, 0.40, 0.50, 0.60, 0.70, 0.80)
n_sim  <- 30   # increase if you can afford the compute

sens_raw <- map_dfr(p_grid, function(p) {
  map_dfr(1:n_sim, function(rep) {
    message("p_flip = ", p, " | rep = ", rep)
    run_one_misclass_sim(p_flip = p) %>%
      mutate(sim_rep = rep)
  })
})

# ------------------------------------------------------------------
# 8.4 Summarise random misclassification: pooled Δ vs p_flip
# ------------------------------------------------------------------

sens_summary <- sens_raw %>%
  group_by(p_flip, outcome) %>%
  summarise(
    mean_estimate      = mean(estimate),
    mean_conf_low      = mean(conf.low),
    mean_conf_high     = mean(conf.high),
    prop_est_positive  = mean(estimate > 0),
    prop_ci_above_zero = mean(conf.low > 0),
    .groups = "drop"
  )

print(sens_summary)

# ------------------------------------------------------------------
# 8.5 Worst-case adversarial misclassification
#      Flip labels for tweets that contribute most to congruence
# ------------------------------------------------------------------

# 8.5.1 Per-tweet slopes & congruence scores

get_slope_ideo <- function(df, event_col) {
  y <- df[[event_col]]
  if (length(unique(y)) < 2L || sd(df$ideo_numeric, na.rm = TRUE) == 0) {
    return(NA_real_)
  }
  m <- try(lm(y ~ ideo_numeric, data = df), silent = TRUE)
  if (inherits(m, "try-error")) {
    return(NA_real_)
  }
  out <- try(coef(m)[["ideo_numeric"]], silent = TRUE)
  if (inherits(out, "try-error") || is.na(out)) {
    return(NA_real_)
  }
  as.numeric(out)
}

# expo_df must have: tweet_id, binary_tweet, ideo_numeric, like, share
compute_tweet_scores <- function(expo_df) {
  expo_clean <- expo_df %>%
    filter(!is.na(binary_tweet), !is.na(ideo_numeric))
  
  # Like slopes
  like_scores <- expo_clean %>%
    group_by(tweet_id) %>%
    summarise(
      beta_like    = get_slope_ideo(cur_data(), "like"),
      binary_tweet = first(binary_tweet),
      .groups      = "drop"
    ) %>%
    mutate(
      score_like = beta_like * ifelse(binary_tweet == 1L, 1, -1)
    )
  
  # Share slopes
  share_scores <- expo_clean %>%
    group_by(tweet_id) %>%
    summarise(
      beta_share   = get_slope_ideo(cur_data(), "share"),
      binary_tweet = first(binary_tweet),
      .groups      = "drop"
    ) %>%
    mutate(
      score_share = beta_share * ifelse(binary_tweet == 1L, 1, -1)
    )
  
  # Join and build combined score
  full_scores <- like_scores %>%
    full_join(
      share_scores %>% select(tweet_id, beta_share, score_share, binary_tweet),
      by = "tweet_id"
    ) %>%
    mutate(
      binary_tweet = ifelse(is.na(binary_tweet.x), binary_tweet.y, binary_tweet.x),
      score_combined = coalesce(score_like, 0) + coalesce(score_share, 0)
    ) %>%
    select(
      tweet_id,
      binary_tweet,
      beta_like,  score_like,
      beta_share, score_share,
      score_combined
    )
  
  full_scores
}

# Precompute scores under baseline labels
scores_uk  <- compute_tweet_scores(data_uk_expo)
scores_us1 <- compute_tweet_scores(data_us1_expo)
scores_us2 <- compute_tweet_scores(data_us2_expo)
scores_us3 <- compute_tweet_scores(data_us3_expo)

# 8.5.2 Adversarial flip: flip tweets with largest congruence score

# mode:
#   "combined" = score_combined (default)
#   "like"     = score_like
#   "share"    = score_share
adversarial_flip_tweets <- function(tweets_meta,
                                    scores_df,
                                    q,               # fraction of valid tweets to flip
                                    mode = c("combined", "like", "share"),
                                    tweet_id_col = "tweet_id") {
  mode <- match.arg(mode)
  df   <- tweets_meta
  
  if (q <= 0) return(df)
  
  scores_for_join <- scores_df %>%
    select(tweet_id, starts_with("score_"))
  
  df_scores <- df %>%
    left_join(scores_for_join, by = setNames("tweet_id", tweet_id_col))
  
  score_col <- dplyr::case_when(
    mode == "combined" ~ "score_combined",
    mode == "like"     ~ "score_like",
    mode == "share"    ~ "score_share"
  )
  
  valid <- df_scores %>%
    filter(!is.na(binary_tweet),
           binary_tweet %in% c(0L, 1L),
           !is.na(.data[[score_col]]))
  
  n_valid <- nrow(valid)
  if (n_valid == 0L) return(df)
  
  n_flip <- round(q * n_valid)
  if (n_flip == 0L) return(df)
  
  flip_ids <- valid %>%
    arrange(desc(.data[[score_col]])) %>%
    slice_head(n = n_flip) %>%
    pull(.data[[tweet_id_col]])
  
  flip_idx <- which(df[[tweet_id_col]] %in% flip_ids &
                      !is.na(df$binary_tweet) &
                      df$binary_tweet %in% c(0L, 1L))
  
  if (length(flip_idx) > 0L) {
    df$binary_tweet[flip_idx] <- 1L - df$binary_tweet[flip_idx]
  }
  
  df
}

# 8.5.3 Safe wrapper around FE-GLM

fit_joint_fe_study_safe <- function(expo_df, id_var, study_label) {
  out <- try(
    fit_joint_fe_study(expo_df, id_var = id_var, study_label = study_label),
    silent = TRUE
  )
  if (inherits(out, "try-error")) {
    warning("fit_joint_fe_study failed for ", study_label, ": ", out)
    return(NULL)
  }
  out
}

# 8.5.4 One adversarial run for a given q and mode

run_one_adversarial <- function(q,
                                mode = c("combined", "like", "share")) {
  mode <- match.arg(mode)
  message("Running adversarial misclassification with q = ", q,
          " (", mode, ")")
  
  # 1) Flip labels adversarially in each study
  tweets_uk_meta_adv  <- adversarial_flip_tweets(tweets_uk_meta,  scores_uk,  q, mode = mode)
  tweets_us1_meta_adv <- adversarial_flip_tweets(tweets_us1_meta, scores_us1, q, mode = mode)
  tweets_us2_meta_adv <- adversarial_flip_tweets(tweets_us2_meta, scores_us2, q, mode = mode)
  tweets_us3_meta_adv <- adversarial_flip_tweets(tweets_us3_meta, scores_us3, q, mode = mode)
  
  # 2) Rebuild exposure panels with misclassified labels
  data_uk_expo_adv  <- prep_exposure_full(
    events      = data_uk_full,
    id_var      = "prolific_id",
    tweets_meta = tweets_uk_meta_adv
  )
  data_us1_expo_adv <- prep_exposure_full(
    events      = data_us1_full,
    id_var      = "respondent_id",
    tweets_meta = tweets_us1_meta_adv
  )
  data_us2_expo_adv <- prep_exposure_full(
    events      = data_us2_full,
    id_var      = "prolific_id",
    tweets_meta = tweets_us2_meta_adv
  )
  data_us3_expo_adv <- prep_exposure_full(
    events      = data_us3_full,
    id_var      = "prolific_id",
    tweets_meta = tweets_us3_meta_adv
  )
  
  # 3) Re-fit joint FE-GLMs (safe)
  joint_uk_adv  <- fit_joint_fe_study_safe(data_uk_expo_adv,  id_var = "prolific_id",   study_label = "Study 1 (UK)")
  joint_us1_adv <- fit_joint_fe_study_safe(data_us1_expo_adv, id_var = "respondent_id", study_label = "Study 2 (US)")
  joint_us2_adv <- fit_joint_fe_study_safe(data_us2_expo_adv, id_var = "prolific_id",   study_label = "Study 3 (US)")
  joint_us3_adv <- fit_joint_fe_study_safe(data_us3_expo_adv, id_var = "prolific_id",   study_label = "Study 4 (US)")
  
  joint_list <- list(joint_uk_adv, joint_us1_adv, joint_us2_adv, joint_us3_adv)
  if (all(vapply(joint_list, is.null, logical(1)))) {
    warning("All joint FE-GLMs failed for q = ", q, " (", mode, ")")
    return(
      tibble(
        q         = q,
        mode      = mode,
        outcome   = c("Like - Read", "Share - Read"),
        estimate  = NA_real_,
        std.error = NA_real_,
        z         = NA_real_,
        pval      = NA_real_
      )
    )
  }
  
  joint_summary_adv <- bind_rows(
    if (!is.null(joint_uk_adv))  joint_uk_adv$summary  else NULL,
    if (!is.null(joint_us1_adv)) joint_us1_adv$summary else NULL,
    if (!is.null(joint_us2_adv)) joint_us2_adv$summary else NULL,
    if (!is.null(joint_us3_adv)) joint_us3_adv$summary else NULL
  )
  
  # 4) REML meta-analysis for Δ(Like-Read) and Δ(Share-Read)
  meta_adv <- joint_summary_adv %>%
    filter(
      type == "difference",
      outcome %in% c("Like - Read", "Share - Read"),
      !is.na(estimate),
      !is.na(std.error),
      std.error > 0
    ) %>%
    group_by(outcome) %>%
    group_modify(~{
      dat <- .x
      fit_re <- try(
        rma.uni(
          yi  = dat$estimate,
          sei = dat$std.error,
          method = "REML"
        ),
        silent = TRUE
      )
      if (inherits(fit_re, "try-error")) {
        warning("REML meta failed for outcome = ", unique(dat$outcome),
                " at q = ", q, " (", mode, "): ", fit_re)
        return(
          tibble(
            estimate  = NA_real_,
            std.error = NA_real_,
            conf.low  = NA_real_,
            conf.high = NA_real_
          )
        )
      }
      tibble(
        estimate  = as.numeric(fit_re$b),
        std.error = fit_re$se,
        conf.low  = fit_re$ci.lb,
        conf.high = fit_re$ci.ub
      )
    }) %>%
    ungroup() %>%
    mutate(
      q    = q,
      mode = mode,
      z    = estimate / std.error,
      pval = 2 * pnorm(abs(z), lower.tail = FALSE)
    )
  
  meta_adv
}

# ------------------------------------------------------------------
# 8.6 Run adversarial curve over a grid of q
# ------------------------------------------------------------------

q_grid       <- seq(0, 0.6, by = 0.1)    # fraction of high-congruence tweets misclassified
modes_to_run <- c("combined")            # can add "like", "share" if desired

sens_adv_raw <- map_dfr(modes_to_run, function(md) {
  map_dfr(q_grid, function(q) run_one_adversarial(q = q, mode = md))
})

sens_adv_summary <- sens_adv_raw %>%
  group_by(mode, q, outcome) %>%
  summarise(
    estimate  = first(estimate),
    std.error = first(std.error),
    z         = first(z),
    pval      = first(pval),
    .groups   = "drop"
  )

print(sens_adv_summary)

# ------------------------------------------------------------------
# 8.7 Combined sensitivity plot: random vs adversarial misclassification
# ------------------------------------------------------------------

#############################################
# Combined sensitivity plot: Random vs Adversarial
#############################################

## 1. Prepare RANDOM misclassification data
# sens_summary has:
#   p_flip, outcome, mean_estimate, mean_conf_low, mean_conf_high

sens_random_for_plot <- sens_summary %>%
  transmute(
    scheme   = "Random misclassification",
    x        = p_flip,                 # x-axis
    outcome  = outcome,
    estimate = mean_estimate,
    conf.low = mean_conf_low,
    conf.high= mean_conf_high
  )

## 2. Prepare ADVERSARIAL misclassification data
# sens_adv_summary has:
#   q, outcome, estimate, std.error

sens_adv_for_plot <- sens_adv_summary %>%
  mutate(
    conf.low  = estimate - 1.96 * std.error,
    conf.high = estimate + 1.96 * std.error
  ) %>%
  transmute(
    scheme   = "Adversarial misclassification",
    x        = q,        # x-axis
    outcome  = outcome,
    estimate = estimate,
    conf.low = conf.low,
    conf.high= conf.high
  )

## 3. Combine and clean labels
sens_both_plot_df <- bind_rows(sens_random_for_plot, sens_adv_for_plot) %>%
  mutate(
    scheme = factor(
      scheme,
      levels = c("Random misclassification", "Adversarial misclassification")
    ),
    outcome = factor(
      outcome,
      levels = c("Like - Read", "Share - Read"),
      labels = c("Like minus Read", "Share minus Read")
    )
  )

## 4. Single, publication-style plot

# Nice muted greys for outcomes
outcome_cols <- c(
  "Like minus Read"  = "#333333",
  "Share minus Read" = "#7F7F7F"
)

combined_sens_plot <- ggplot(
  sens_both_plot_df,
  aes(x = x, y = estimate, colour = outcome, fill = outcome)
) +
  # Reference line at 0
  geom_hline(yintercept = 0, linetype = "dashed", linewidth = 0.4, colour = "grey60") +
  
  # Uncertainty ribbon
  geom_ribbon(
    aes(ymin = conf.low, ymax = conf.high),
    alpha = 0.15,
    colour = NA
  ) +
  
  # Lines and points
  geom_line(linewidth = 0.8) +
  geom_point(size = 2) +
  
  # One facet per scheme
  facet_wrap(~ scheme, nrow = 1) +
  
  # X-axis as % misclassified / adversarially flipped
  scale_x_continuous(
    breaks = unique(sens_both_plot_df$x),
    labels = percent_format(accuracy = 1)
  ) +
  
  # Minimal but sharp colour palette
  scale_colour_manual(values = outcome_cols, name = NULL) +
  scale_fill_manual(values = outcome_cols,   name = NULL) +
  
  labs(
    x = "Fraction of tweets with misclassified ideology labels",
    y = "Pooled Δ (log-odds per 1 SD)\nLike/Share vs Read more (REML)",
  ) +
  
  theme_minimal(base_size = 13) +
  theme(
    panel.grid.minor  = element_blank(),
    panel.grid.major.x= element_line(colour = "grey90", linewidth = 0.3),
    panel.grid.major.y= element_line(colour = "grey90", linewidth = 0.3),
    panel.border      = element_rect(colour = "grey80", fill = NA, linewidth = 0.4),
    strip.background  = element_rect(fill = "grey95", colour = NA),
    strip.text        = element_text(size = 11, face = "bold"),
    axis.title.y      = element_text(margin = margin(r = 6)),
    axis.title.x      = element_text(margin = margin(t = 6)),
    legend.position   = "bottom",
    legend.margin     = margin(t = 4, b = 2),
    plot.title        = element_text(face = "bold", size = 14),
    plot.subtitle     = element_text(size = 11, colour = "grey30")
  )

print(combined_sens_plot)

ggsave(
  filename = "plots/sensitivity_combined.png",
  plot     = combined_sens_plot,
  width    = 9,
  height   = 4.5,
  dpi      = 300
)
 
# NOTE: Shaded bands show 95% confidence intervals (random panel: 
# averaged across simulation replicates; adversarial panel: 
# from the meta-analysis under each worst-case relabelling).
