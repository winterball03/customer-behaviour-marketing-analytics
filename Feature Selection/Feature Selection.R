#----------------------------------------------------------------------------#
# CDS501 Combined Feature Selection + Plots + Final Dataset
#----------------------------------------------------------------------------#

library(dplyr)
library(ggplot2)
library(reshape2)

#----------------------------------------------------------------------------#
# STEP 0: Ensure unique ID exists
#----------------------------------------------------------------------------#

final_dataset <- final_dataset %>%
  mutate(review_id = row_number())

#----------------------------------------------------------------------------#
# STEP 1: Select structured features
#----------------------------------------------------------------------------#

df_feature_sel <- final_dataset %>%
  select(
    review_id,
    age,
    division_name,
    department_name,
    class_name,
    alike_feedback_count,
    rating,
    recommend_index,
    age_group,
    feedback_count_group,
    sentiment_score,
    sentiment_label
  )

df_model <- df_feature_sel %>%
  mutate(
    recommend_num = as.numeric(as.character(recommend_index))
  )

#----------------------------------------------------------------------------#
# METHOD 1: Correlation analysis for numeric features
#----------------------------------------------------------------------------#

numeric_data <- df_model %>%
  select(where(is.numeric)) %>%
  select(-recommend_num, -review_id)

cor_matrix <- cor(
  numeric_data,
  use = "complete.obs"
)

print("Correlation Matrix:")
print(cor_matrix)

high_cor_pairs <- which(
  abs(cor_matrix) > 0.8 &
    abs(cor_matrix) < 1,
  arr.ind = TRUE
)

print("Highly Correlated Feature Pairs:")
print(high_cor_pairs)

#----------------------------------------------------------------------------#
# Correlation heatmap
#----------------------------------------------------------------------------#

cor_df <- melt(cor_matrix)

correlation_heatmap <- ggplot(
  cor_df,
  aes(
    Var1,
    Var2,
    fill = value
  )
) +
  geom_tile(color = "white") +
  geom_text(
    aes(label = round(value, 2)),
    size = 3
  ) +
  scale_fill_gradient2(
    low = "blue",
    mid = "white",
    high = "red",
    midpoint = 0
  ) +
  theme_minimal(base_size = 13) +
  labs(
    title = "Correlation Heatmap",
    x = "Features",
    y = "Features",
    fill = "Correlation"
  ) +
  theme(
    axis.text.x = element_text(
      angle = 45,
      hjust = 1
    )
  )

print(correlation_heatmap)

ggsave(
  "Correlation_Heatmap.png",
  correlation_heatmap,
  width = 8,
  height = 6,
  dpi = 300
)

#----------------------------------------------------------------------------#
# METHOD 2: Chi-square test for categorical features
#----------------------------------------------------------------------------#

cat_features <- c(
  "class_name",
  "department_name",
  "division_name",
  "age_group",
  "feedback_count_group",
  "sentiment_label"
)

chi_results_cat <- lapply(
  cat_features,
  function(col) {
    tbl <- table(
      df_model[[col]],
      df_model$recommend_index
    )
    
    test <- suppressWarnings(chisq.test(tbl))
    
    data.frame(
      feature = col,
      chi_square = as.numeric(test$statistic),
      p_value = test$p.value
    )
  }
)

chi_results_cat <- do.call(
  rbind,
  chi_results_cat
) %>%
  arrange(p_value)

print("Chi-Square Results:")
print(chi_results_cat)

selected_cat_features <- chi_results_cat %>%
  filter(p_value < 0.05) %>%
  pull(feature)

print("Selected Categorical Features:")
print(selected_cat_features)

#----------------------------------------------------------------------------#
# METHOD 3: T-test for numeric features
#----------------------------------------------------------------------------#

num_features <- c(
  "rating",
  "age",
  "sentiment_score",
  "alike_feedback_count"
)

ttest_results <- lapply(
  num_features,
  function(col) {
    test <- t.test(
      df_model[[col]] ~ df_model$recommend_index
    )
    
    data.frame(
      feature = col,
      t_statistic = as.numeric(test$statistic),
      p_value = test$p.value,
      mean_recommend = mean(
        df_model[[col]][df_model$recommend_index == 1],
        na.rm = TRUE
      ),
      mean_not_recommend = mean(
        df_model[[col]][df_model$recommend_index == 0],
        na.rm = TRUE
      )
    )
  }
)

ttest_results <- do.call(
  rbind,
  ttest_results
) %>%
  arrange(p_value)

print("T-Test Results:")
print(ttest_results)

selected_numeric_features <- ttest_results %>%
  filter(p_value < 0.05) %>%
  pull(feature)

print("Selected Numeric Features:")
print(selected_numeric_features)

#----------------------------------------------------------------------------#
# Final selected feature list
#----------------------------------------------------------------------------#

final_selected_features <- list(
  categorical = selected_cat_features,
  numeric = selected_numeric_features
)

print("Final Selected Features:")
print(final_selected_features)

#----------------------------------------------------------------------------#
# Feature importance data
#----------------------------------------------------------------------------#

chi_plot <- chi_results_cat %>%
  mutate(
    importance = -log10(p_value),
    method = "Chi-Square"
  ) %>%
  select(
    feature,
    importance,
    method
  )

ttest_plot <- ttest_results %>%
  mutate(
    importance = -log10(p_value),
    method = "T-Test"
  ) %>%
  select(
    feature,
    importance,
    method
  )

feature_importance <- bind_rows(
  chi_plot,
  ttest_plot
)

threshold <- -log10(0.05)

#----------------------------------------------------------------------------#
# Feature importance plot
#----------------------------------------------------------------------------#

feature_importance_plot <- ggplot(
  feature_importance,
  aes(
    x = reorder(feature, importance),
    y = importance,
    fill = method
  )
) +
  geom_col(alpha = 0.9) +
  coord_flip() +
  geom_hline(
    yintercept = threshold,
    linetype = "dashed",
    color = "red",
    linewidth = 1
  ) +
  theme_minimal(base_size = 13) +
  labs(
    title = "Feature Importance (Chi-Square vs T-Test)",
    subtitle = "Red line = p < 0.05 threshold",
    x = "Features",
    y = "-log10(p-value)",
    fill = "Test Type"
  ) +
  scale_fill_manual(
    values = c(
      "Chi-Square" = "steelblue",
      "T-Test" = "darkorange"
    )
  )

print(feature_importance_plot)

ggsave(
  "Feature_Importance_ChiSquare_TTest.png",
  feature_importance_plot,
  width = 10,
  height = 6,
  dpi = 300
)

#----------------------------------------------------------------------------#
# Text feature chi-square threshold plot
#----------------------------------------------------------------------------#
# This section requires chi_scores from the earlier text feature selection step.

if (exists("chi_scores")) {
  text_threshold <- quantile(chi_scores, 0.95, na.rm = TRUE)
  
  chi_text_df <- data.frame(
    word = names(chi_scores),
    chi_square = as.numeric(chi_scores)
  ) %>%
    arrange(desc(chi_square)) %>%
    mutate(
      rank = row_number(),
      selected = ifelse(
        chi_square >= text_threshold,
        "Selected",
        "Not Selected"
      )
    )
  
  text_threshold_plot <- ggplot(
    chi_text_df,
    aes(
      x = rank,
      y = chi_square,
      color = selected
    )
  ) +
    geom_point(alpha = 0.8, size = 2) +
    geom_hline(
      yintercept = text_threshold,
      linetype = "dashed",
      linewidth = 1
    ) +
    annotate(
      "text",
      x = max(chi_text_df$rank) * 0.8,
      y = text_threshold,
      label = paste(
        "95th Percentile Threshold =",
        round(text_threshold, 2)
      ),
      vjust = -1
    ) +
    labs(
      title = "Chi-Square Text Feature Selection Threshold",
      subtitle = "Features above the 95th percentile were selected",
      x = "Feature Rank",
      y = "Chi-Square Statistic",
      color = "Feature Status"
    ) +
    theme_minimal(base_size = 13)
  
  print(text_threshold_plot)
  
  ggsave(
    "ChiSquare_Text_Feature_Threshold.png",
    text_threshold_plot,
    width = 10,
    height = 6,
    dpi = 300
  )
  
  write.csv(
    chi_text_df,
    "ChiSquare_Text_Feature_Results.csv",
    row.names = FALSE
  )
} else {
  message(
    "chi_scores was not found. Text threshold plot was skipped. ",
    "Run the text feature selection step before this script to create it."
  )
}

#----------------------------------------------------------------------------#
# Build final structured dataset using selected structured features
#----------------------------------------------------------------------------#

structured_final <- df_model %>%
  select(
    review_id,
    recommend_index,
    all_of(selected_numeric_features),
    all_of(selected_cat_features)
  )

#----------------------------------------------------------------------------#
# Merge selected structured features with selected text features
#----------------------------------------------------------------------------#
# final_features should already come from the earlier text feature selection step.
# If final_features does not have review_id, this creates one using row order.

if (!"review_id" %in% names(final_features)) {
  final_features <- final_features %>%
    mutate(review_id = row_number())
}

final_ml_dataset <- structured_final %>%
  inner_join(
    final_features,
    by = "review_id"
  ) %>%
  select(-review_id)

#----------------------------------------------------------------------------#
# Final output
#----------------------------------------------------------------------------#

print(dim(final_ml_dataset))
print(head(final_ml_dataset))

write.csv(
  final_ml_dataset,
  "final_ml_dataset.csv",
  row.names = FALSE
)

write.csv(
  chi_results_cat,
  "ChiSquare_Categorical_Results.csv",
  row.names = FALSE
)

write.csv(
  ttest_results,
  "TTest_Numeric_Results.csv",
  row.names = FALSE
)

write.csv(
  feature_importance,
  "Feature_Importance_Results.csv",
  row.names = FALSE
)
