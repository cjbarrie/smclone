library(dplyr)
library(ggplot2)

qualtricsdat <- read_csv("data/US/test/qualtrics.csv")
qualtricsdat <- qualtricsdat[-c(1:2), ]

# (optional) clean Q2_1 if it’s a character like "0 (left)" -> strip the label and make numeric
qualtricsdat <- qualtricsdat %>%
  dplyr::mutate(
    Q2_1_num = as.numeric(stringr::str_extract(Q2_1, "^[0-9]+"))
  )

# basic dodged bar‐chart of ideology by party
ggplot(qualtricsdat, aes(x = factor(Q2_1_num), fill = Q4)) +
  geom_bar(position = "dodge") +
  scale_x_discrete(
    name = "Ideology (0 = Left … 10 = Right)",
    breaks = 0:10
  ) +
  labs(
    y    = "Count",
    fill = "Party"
  ) +
  theme_minimal(base_size = 14) +
  facet_wrap(~ Q4)
