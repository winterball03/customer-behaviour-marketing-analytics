#----------------------------------------------------------------------------#
# MODEL: K-NEAREST NEIGHBOUR (KNN)
# Target: recommend_index
#----------------------------------------------------------------------------#

install.packages(c("tidyverse", "caret", "pROC"))

library(tidyverse)
library(caret)
library(pROC)

#----------------------------------------------------------------------------#
# STEP 1: LOAD DATASET
#----------------------------------------------------------------------------#

final_ml_dataset <- read_csv("final_ml_dataset.csv")

dim(final_ml_dataset)
str(final_ml_dataset)
head(final_ml_dataset)

table(final_ml_dataset$recommend_index)
prop.table(table(final_ml_dataset$recommend_index))

#----------------------------------------------------------------------------#
# STEP 2: DATA PREPARATION FOR KNN
#----------------------------------------------------------------------------#

knn_data <- final_ml_dataset %>%
  mutate(
    recommend_index = factor(
      ifelse(recommend_index == 1, "Recommend", "Not_Recommend"),
      levels = c("Not_Recommend", "Recommend")
    ),
    across(where(is.character), as.factor),
    feedback_count_group = as.factor(feedback_count_group)
  )

table(knn_data$recommend_index)
prop.table(table(knn_data$recommend_index))

#----------------------------------------------------------------------------#
# STEP 3: TRAIN-TEST SPLIT
#----------------------------------------------------------------------------#

set.seed(123)

train_index <- createDataPartition(
  knn_data$recommend_index,
  p = 0.8,
  list = FALSE
)

knn_train_raw <- knn_data[train_index, ]
knn_test_raw  <- knn_data[-train_index, ]

dim(knn_train_raw)
dim(knn_test_raw)

#----------------------------------------------------------------------------#
# STEP 4: DUMMY ENCODING
#----------------------------------------------------------------------------#

knn_train_predictors <- knn_train_raw %>%
  select(-recommend_index)

knn_test_predictors <- knn_test_raw %>%
  select(-recommend_index)

dummy_model <- dummyVars(
  ~ .,
  data = knn_train_predictors,
  fullRank = TRUE
)

knn_train_x <- predict(dummy_model, newdata = knn_train_predictors) %>%
  as.data.frame()

knn_test_x <- predict(dummy_model, newdata = knn_test_predictors) %>%
  as.data.frame()

colnames(knn_train_x) <- make.names(colnames(knn_train_x), unique = TRUE)
colnames(knn_test_x) <- make.names(colnames(knn_test_x), unique = TRUE)

knn_train_y <- knn_train_raw$recommend_index
knn_test_y  <- knn_test_raw$recommend_index

dim(knn_train_x)
dim(knn_test_x)

#----------------------------------------------------------------------------#
# STEP 5: REMOVE NEAR-ZERO VARIANCE FEATURES
#----------------------------------------------------------------------------#

nzv_cols <- nearZeroVar(knn_train_x)

length(nzv_cols)

if (length(nzv_cols) > 0) {
  knn_train_x <- knn_train_x[, -nzv_cols]
  knn_test_x  <- knn_test_x[, -nzv_cols]
}

dim(knn_train_x)
dim(knn_test_x)

#----------------------------------------------------------------------------#
# STEP 6: KNN PARAMETER TUNING
#----------------------------------------------------------------------------#

knn_control <- trainControl(
  method = "cv",
  number = 10,
  classProbs = TRUE,
  summaryFunction = twoClassSummary,
  savePredictions = "final"
)

# Extend k because previous best k = 31 was at the boundary
knn_grid <- expand.grid(
  k = seq(3, 101, by = 2)
)

set.seed(123)

knn_model <- train(
  x = knn_train_x,
  y = knn_train_y,
  method = "knn",
  metric = "ROC",
  trControl = knn_control,
  tuneGrid = knn_grid,
  preProcess = c("range")
)

print(knn_model)
plot(knn_model)

knn_model$bestTune

#----------------------------------------------------------------------------#
# STEP 7: SAVE KNN TUNING PLOT
#----------------------------------------------------------------------------#

knn_tuning_plot <- ggplot(knn_model$results, aes(x = k, y = ROC)) +
  geom_line() +
  geom_point() +
  labs(
    title = "KNN Parameter Tuning Using 10-Fold Cross-Validation",
    x = "Number of Neighbours (k)",
    y = "ROC (Cross-Validation)"
  ) +
  theme_minimal()

ggsave(
  "KNN_TuningPlot.png",
  knn_tuning_plot,
  width = 7,
  height = 5,
  dpi = 300
)

#----------------------------------------------------------------------------#
# STEP 8: TEST SET PREDICTION
#----------------------------------------------------------------------------#

knn_pred <- predict(knn_model, newdata = knn_test_x)
knn_prob <- predict(knn_model, newdata = knn_test_x, type = "prob")

head(knn_pred)
head(knn_prob)

#----------------------------------------------------------------------------#
# STEP 9: CONFUSION MATRIX
# Positive class = Not_Recommend because this is the loyalty-risk group
#----------------------------------------------------------------------------#

knn_cm <- confusionMatrix(
  data = knn_pred,
  reference = knn_test_y,
  positive = "Not_Recommend"
)

print(knn_cm)

knn_cm_table <- as.data.frame(knn_cm$table)
write_csv(knn_cm_table, "KNN_ConfusionMatrix_Table.csv")

knn_cm_plot <- ggplot(knn_cm_table, aes(x = Reference, y = Prediction, fill = Freq)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(
    aes(
      label = Freq,
      colour = ifelse(Freq > max(Freq) / 2, "white", "black")
    ),
    size = 6
  ) +
  scale_colour_identity() +
  scale_fill_gradient(
    low = "#FEE8C8",   # light orange
    high = "#E6550D"   # dark orange
  ) +
  labs(
    title = "KNN Confusion Matrix",
    x = "Actual Class",
    y = "Predicted Class",
    fill = "Freq"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
    axis.title = element_text(size = 13),
    axis.text = element_text(size = 11)
  )

ggsave(
  "KNN_ConfusionMatrix.png",
  knn_cm_plot,
  width = 6,
  height = 5,
  dpi = 300
)

#----------------------------------------------------------------------------#
# STEP 10: ROC AND AUC
#----------------------------------------------------------------------------#

knn_roc <- roc(
  response = knn_test_y,
  predictor = knn_prob$Not_Recommend,
  levels = c("Recommend", "Not_Recommend")
)

knn_auc <- auc(knn_roc)
print(knn_auc)

png("KNN_ROC.png", width = 1000, height = 800, res = 150)

plot(
  knn_roc,
  main = paste("KNN ROC Curve, AUC =", round(knn_auc, 3))
)

dev.off()

#----------------------------------------------------------------------------#
# STEP 11: SAVE KNN PERFORMANCE METRICS
#----------------------------------------------------------------------------#

knn_metrics <- data.frame(
  Model = "K-Nearest Neighbour",
  Accuracy = as.numeric(knn_cm$overall["Accuracy"]),
  Kappa = as.numeric(knn_cm$overall["Kappa"]),
  Balanced_Accuracy = as.numeric(knn_cm$byClass["Balanced Accuracy"]),
  Recall_NotRecommend = as.numeric(knn_cm$byClass["Sensitivity"]),
  Specificity_Recommend = as.numeric(knn_cm$byClass["Specificity"]),
  Precision_NotRecommend = as.numeric(knn_cm$byClass["Pos Pred Value"]),
  F1_NotRecommend = as.numeric(knn_cm$byClass["F1"]),
  AUC = as.numeric(knn_auc),
  Best_k = knn_model$bestTune$k,
  Removed_NZV_Features = length(nzv_cols)
)

print(knn_metrics)

write_csv(knn_metrics, "KNN_Metrics.csv")

saveRDS(knn_model, "KNN_Model.rds")
