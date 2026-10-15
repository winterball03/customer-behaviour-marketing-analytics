#----------------------------------------------------------------------------#
# Libraries
#----------------------------------------------------------------------------#

library(readr)
library(dplyr)
library(tidytext)
library(ggplot2)
library(stringr)
library(wordcloud)
library(RColorBrewer)
library(textstem)
library(hunspell)
library(tidyr)

#----------------------------------------------------------------------------#
# Load RAW data
#----------------------------------------------------------------------------#

setwd("D:\\My Documents\\USM\\SEM 1\\CDS501 PRINCIPLES & PRACTICES OF DATA SCIENCE & ANALYTICS (PRINSIP & AMALAN SAINS DATA & ANALITIK)\\Assignment\\Assignment 1")
raw_df <- read_csv("clothing_reviews.csv")

str(raw_df)
summary(raw_df)
n_raw <- nrow(raw_df)
original_rows <- nrow(raw_df)
original_cols <- ncol(raw_df)

df_no_id <- raw_df %>% select(-index, -clothing_id)

#----------------------------------------------------------------------------#
# Duplicate handling
#----------------------------------------------------------------------------#

dup_before <- sum(duplicated(df_no_id))
df <- df_no_id %>% distinct()
dup_removed <- nrow(df_no_id) - nrow(df)

#----------------------------------------------------------------------------#
# Missing value handling
#----------------------------------------------------------------------------#

missing_before <- colSums(is.na(raw_df))
before_text <- nrow(df)

df <- df %>%
  filter(!(is.na(title) & is.na(review_text)))

after_text <- nrow(df)

before_cat <- nrow(df)

df <- df %>%
  filter(!is.na(division_name),
         !is.na(department_name),
         !is.na(class_name))

after_cat <- nrow(df)

#----------------------------------------------------------------------------#
# Type conversion
#----------------------------------------------------------------------------#

df$age <- as.numeric(df$age)
df$alike_feedback_count <- as.numeric(df$alike_feedback_count)
df$recommend_index <- as.factor(df$recommend_index)
df$division_name <- as.factor(df$division_name)
df$department_name <- as.factor(df$department_name)
df$class_name <- as.factor(df$class_name)

#----------------------------------------------------------------------------#
# Outlier detection + winsorization (Age)
#----------------------------------------------------------------------------#

# Age boxplot
ggplot(df, aes(y = age)) +
  geom_boxplot(
    outlier.colour = "red",
    outlier.shape = 16,
    outlier.size = 2) +
  ggtitle("Age Distribution")

Q1 <- quantile(df$age, 0.25, na.rm = TRUE)
Q3 <- quantile(df$age, 0.75, na.rm = TRUE)
IQR_val <- IQR(df$age, na.rm = TRUE)

lower <- Q1 - 1.5 * IQR_val
upper <- Q3 + 1.5 * IQR_val

outlier_before <- sum(df$age < lower | df$age > upper, na.rm = TRUE)

df$age <- ifelse(df$age < lower, lower,
                 ifelse(df$age > upper, upper, df$age))

ggplot(df, aes(x = alike_feedback_count)) +
  geom_density(fill = "blue", alpha = 0.3) +
  theme_minimal()+
  geom_rug(alpha = 0.3)

#----------------------------------------------------------------------------#
# Feature engineering
#----------------------------------------------------------------------------#

df_clean <- df %>%
  mutate(
    
    # unique ID for each review
    review_id = row_number(),
    
    # age grouping
    age_group = case_when(
      age <= 25 ~ "young",
      age <= 35 ~ "adult",
      age <= 50 ~ "middle",
      age <= 65 ~ "senior",
      TRUE ~ "elderly"
    ),
    
    # FIXED: feedback count grouping (important fix: -Inf included)
    feedback_count_group = cut(
      alike_feedback_count,
      breaks = c(-Inf, 25, 50, 75, 100, Inf),
      labels = c("1", "2", "3", "4", "5"),
      include.lowest = TRUE
    ),
    
    # text cleaning pipeline
    text = paste(title, review_text),
    text = str_to_lower(text),
    text = str_replace_all(text, "not\\s+([a-z]+)", "not_\\1"),
    text = str_replace_all(text, "[^a-z\\s]", " "),
    text = str_squish(text)
    
  ) %>%
  
  # remove NA created by out-of-range values
  filter(!is.na(feedback_count_group))

#----------------------------------------------------------------------------#
# Text processing
#----------------------------------------------------------------------------#

data(stop_words)

tidy_text <- df_clean %>%
  unnest_tokens(word, text) %>%
  anti_join(stop_words, by = "word") %>%
  filter(nchar(word) > 2) %>%
  mutate(word = lemmatize_words(word))

#----------------------------------------------------------------------------#
# Sentiment analysis
#----------------------------------------------------------------------------#

sentiments <- get_sentiments("bing") %>%
  distinct(word, .keep_all = TRUE)

tidy_sentiment <- tidy_text %>%
  group_by(review_id) %>%
  mutate(prev_word = lag(word)) %>%
  ungroup() %>%
  left_join(sentiments, by = "word") %>%
  mutate(
    score = case_when(
      prev_word == "not" & sentiment == "positive" ~ -1,
      prev_word == "not" & sentiment == "negative" ~ 1,
      sentiment == "positive" ~ 1,
      sentiment == "negative" ~ -1,
      TRUE ~ 0
    )
  )
review_sentiment <- tidy_sentiment %>%
  group_by(review_id) %>%
  summarise(sentiment_score = sum(score, na.rm = TRUE), .groups = "drop") %>%
  mutate(
    sentiment_label = case_when(
      sentiment_score > 0 ~ "positive",
      sentiment_score < 0 ~ "negative",
      TRUE ~ "neutral"
    )
  )

df_clean <- df_clean %>%
  left_join(review_sentiment, by = "review_id") %>%
  mutate(
    sentiment_score = ifelse(is.na(sentiment_score), 0, sentiment_score),
    sentiment_label = ifelse(is.na(sentiment_label), "neutral", sentiment_label)
  )

sentiment_summary <- df_clean %>%
  group_by(class_name, sentiment_label) %>%
  summarise(count = n(), .groups = "drop")

#----------------------------------------------------------------------------#
# Chi-square feature selection
#----------------------------------------------------------------------------#

dtm <- tidy_text %>%
  count(review_id, word)

word_freq <- dtm %>%
  group_by(word) %>%
  summarise(total = sum(n), .groups = "drop")

dtm <- dtm %>%
  filter(word %in% word_freq$word[word_freq$total >= 5])

dtm_binary <- dtm %>%
  mutate(present = 1) %>%
  pivot_wider(
    names_from = word,
    values_from = present,
    values_fn = list(present = max),   
    values_fill = 0
  ) %>%
  inner_join(
    df_clean %>% select(review_id, recommend_index),
    by = "review_id"
  )

words <- setdiff(names(dtm_binary), c("review_id", "recommend_index"))

chi_scores <- sapply(words, function(w) {
  tbl <- table(dtm_binary[[w]], dtm_binary$recommend_index)
  suppressWarnings(as.numeric(chisq.test(tbl)$statistic))
})

names(chi_scores) <- words

threshold <- quantile(chi_scores, 0.95, na.rm = TRUE)
top_words <- names(chi_scores[chi_scores >= threshold])

final_features <- dtm_binary %>%
  group_by(review_id) %>%
  summarise(across(all_of(top_words), max), .groups = "drop")

#----------------------------------------------------------------------------#
# CLEANING SUMMARY
#----------------------------------------------------------------------------#

cleaning_summary <- data.frame(
  Stage = c(
    "Raw Data",
    "After Removing ID",
    "Duplicate Detection",
    "After Removing Duplicates",
    "After Missing Text Removal",
    "After Categorical Cleaning",
    "Final Cleaned Data"
  ),
  Rows = c(
    original_rows,
    nrow(df_no_id),
    dup_before,
    nrow(df),
    after_text,
    after_cat,
    nrow(df_clean)
  )
)

missing_summary <- list(
  raw_missing = missing_before,
  cleaned_missing = colSums(is.na(df_clean))
)

outlier_summary <- data.frame(
  Feature = "Age",
  Outliers_Before = outlier_before,
  Lower_Bound = lower,
  Upper_Bound = upper
)

data_loss <- (original_rows - nrow(df_clean)) / original_rows * 100

final_dataset_shape <- dim(df_clean)

#----------------------------------------------------------------------------#
# Final dataset
#----------------------------------------------------------------------------#

final_dataset <- df_clean %>%
  inner_join(final_features, by = "review_id") %>%
  select(-any_of(c("title", "review_text","review_id")))

dim(final_dataset)
head(final_dataset)

#----------------------------------------------------------------------------#
# Question 1
#----------------------------------------------------------------------------#



# Age after winsorization
ggplot(final_dataset, aes(y = age)) +
  geom_boxplot() +
  ggtitle("Age After Winsorization")


ggplot(final_dataset, aes(x = feedback_count_group)) +
  geom_bar(fill = "blue", alpha = 0.7) +
  theme_minimal()+
  scale_y_log10()

ggplot(sentiment_summary,
       aes(x = count, y = class_name, fill = sentiment_label)) +
  geom_bar(stat = "identity") +
  scale_fill_manual(values = c(
    "positive" = "#66c2a5",
    "negative" = "#fc8d62",
    "neutral"  = "#8da0cb"
  )) +
  geom_text(
    data = sentiment_summary %>%
      group_by(class_name) %>%
      summarise(total = sum(count)),
    aes(x = total, y = class_name, label = total),
    inherit.aes = FALSE,
    hjust = -0.2,
    size = 3.5
  ) +
  labs(
    title = "Sentiment Count Across Product Categories",
    x = "Count",
    y = "Product Category",
    fill = "Sentiment"
  )


# Top 5 positive categories
top_positive <- sentiment_summary %>%
  filter(sentiment_label == "positive") %>%
  arrange(desc(count)) %>%
  slice_head(n = 5)

# Top 5 negative categories
top_negative <- sentiment_summary %>%
  filter(sentiment_label == "negative") %>%
  arrange(desc(count)) %>%
  slice_head(n = 5)

ggplot(top_positive,
       aes(x = reorder(class_name, count), y = count)) +
  geom_col(fill = "#66c2a5") +
  coord_flip() +
  labs(title = "Top 5 Positive Categories",
       x = "Category", y = "Count")

ggplot(top_negative,
       aes(x = reorder(class_name, count), y = count)) +
  geom_col(fill = "#fc8d62") +
  coord_flip() +
  labs(title = "Top 5 Negative Categories",
       x = "Category", y = "Count")

cleaning_summary
missing_summary
outlier_summary
data_loss
final_dataset_shape

#----------------------------------------------------------------------------#
# Question 2
#----------------------------------------------------------------------------#

low_reviews <- df_clean %>%
  filter(rating <= 2, recommend_index == 0)

library(tidytext)

tidy_low <- low_reviews %>%
  unnest_tokens(word, review_text)   # replace with your text variable

data(stop_words)

tidy_low <- tidy_low %>%
  anti_join(stop_words, by = "word")

word_freq <- tidy_low %>%
  count(word, sort = TRUE)

top_words <- word_freq %>%
  slice_head(n = 10)

ggplot(top_words,
       aes(x = reorder(word, n), y = n)) +
  geom_col(fill = "#fc8d62") +
  coord_flip() +
  labs(
    title = "Most Common Terms in Low-Rated, Non-Recommended Reviews",
    x = "Word",
    y = "Frequency"
  )

# 1. Create sentiment summary (count per category + sentiment)
sentiment_summary <- df_clean %>%
  group_by(class_name, sentiment_label) %>%
  summarise(count = n(), .groups = "drop")

# 2. Compute total count per category
totals <- sentiment_summary %>%
  group_by(class_name) %>%
  summarise(total = sum(count), .groups = "drop")

# 3. Join totals and reorder categories (MOST → LEAST)
sentiment_summary <- sentiment_summary %>%
  left_join(totals, by = "class_name") %>%
  mutate(class_name = reorder(class_name, -total))

# 4. Plot
ggplot(sentiment_summary,
       aes(x = count, y = class_name, fill = sentiment_label)) +
  geom_bar(stat = "identity") +
  
  geom_text(
    data = totals,
    aes(x = total, y = class_name, label = total),
    inherit.aes = FALSE,
    hjust = -0.2,
    size = 3.5
  ) +
  
  scale_fill_manual(values = c(
    "positive" = "#66c2a5",
    "negative" = "#fc8d62",
    "neutral"  = "#8da0cb"
  )) +
  
  scale_y_discrete(limits = rev) +  
  
  labs(
    title = "Sentiment Count Across Product Categories",
    x = "Count",
    y = "Product Category",
    fill = "Sentiment"
  ) +
  
  expand_limits(x = max(totals$total) * 1.1) +
  theme_minimal()

#----------------------------------------------------------------------------#
# Question 3
#----------------------------------------------------------------------------#

# 1. Age group and recommendation distribution data
q3_age_recommend <- df_clean %>%
  filter(!is.na(age_group), !is.na(recommend_index)) %>%
  mutate(
    age_group = factor(
      age_group,
      levels = c("young", "adult", "middle", "senior", "elderly")
    ),
    recommend_num = as.numeric(as.character(recommend_index)),
    recommend_label = ifelse(recommend_num == 1, "Recommend", "Not Recommend")
  )

# 2. Recommendation behavior frequency and percentage distribution
q3_distribution <- q3_age_recommend %>%
  group_by(age_group, recommend_label) %>%
  summarise(count = n(), .groups = "drop") %>%
  group_by(age_group) %>%
  mutate(
    total_reviews = sum(count),
    percentage = round((count / total_reviews) * 100, 2)
  )

print(q3_distribution)

# 3. Identify the age group with highest recommendation
q3_summary <- q3_age_recommend %>%
  group_by(age_group) %>%
  summarise(
    total_reviews = n(),
    recommend_count = sum(recommend_num == 1),
    not_recommend_count = sum(recommend_num == 0),
    recommendation_rate = round((recommend_count / total_reviews) * 100, 2),
    .groups = "drop"
  ) %>%
  arrange(desc(recommendation_rate))

print(q3_summary)

# 4. Stacked bar chart for recommendation distribution by age group
q3_plot <- ggplot(q3_distribution,
                  aes(x = age_group, y = percentage, fill = recommend_label)) +
  geom_col() +
  geom_text(
    aes(label = paste0(percentage, "%")),
    position = position_stack(vjust = 0.5),
    size = 3
  ) +
  labs(
    title = "Recommendation Behaviour Distribution Across Age Groups",
    x = "Customer Age Group",
    y = "Percentage of Reviews (%)",
    fill = "Recommendation Behaviour"
  ) +
  theme_minimal()

q3_plot

ggsave(
  filename = "Q3_recommendation_distribution_by_age.png",
  plot = q3_plot,
  width = 8,
  height = 5,
  dpi = 300
)

#----------------------------------------------------------------------------#
# Question 4
#----------------------------------------------------------------------------#

# 1. Hypothesis testing data
q4_data <- final_dataset %>%
  filter(!is.na(rating), !is.na(recommend_index)) %>%
  mutate(
    recommend_num = as.numeric(as.character(recommend_index)),
    recommend_label = ifelse(recommend_num == 1, "Recommend", "Not Recommend")
  )

# 2. Number of customers in each recommendation group
table(q4_data$recommend_label)

# 3. Descriptive statistics for rating by recommendation group
q4_summary <- q4_data %>%
  group_by(recommend_label) %>%
  summarise(
    count = n(),
    mean_rating = round(mean(rating), 2),
    sd_rating = round(sd(rating), 2),
    median_rating = median(rating),
    min_rating = min(rating),
    max_rating = max(rating),
    .groups = "drop"
  )

print(q4_summary)

# 4. Visualize rating distribution by using boxplot
q4_plot <- ggplot(q4_data, aes(x = recommend_label, y = rating, fill = recommend_label)) +
  geom_boxplot(alpha = 0.7) +
  labs(
    title = "Rating Distribution by Recommendation Behaviour",
    x = "Recommendation Behaviour",
    y = "Customer Rating"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

q4_plot

ggsave(
  filename = "Q4_rating_distribution_by_recommendation.png",
  plot = q4_plot,
  width = 7,
  height = 5,
  dpi = 300
)

# 5. Welch two-sample t-test
q4_ttest <- t.test(
  rating ~ recommend_label,
  data = q4_data,
  alternative = "less"
)

print(q4_ttest)
