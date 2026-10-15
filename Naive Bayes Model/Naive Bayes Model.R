#----------------------------------------------------------------------------#
# NAIVE BAYES CLASSIFIER - MATCH LOGISTIC REGRESSION ROC PLOT STYLE
#----------------------------------------------------------------------------#

# install.packages(c("tidyverse", "caret", "e1071", "pROC"))

library(tidyverse)
library(caret)
library(e1071)
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
# STEP 2: DATA PREPARATION
#----------------------------------------------------------------------------#

nb_data <- final_ml_dataset %>%
  mutate(
    recommend_index = factor(
      recommend_index,
      levels = c("0", "1"),
      labels = c("Not_Recommend", "Recommend")
    ),
    across(where(is.character), as.factor)
  )

table(nb_data$recommend_index)
prop.table(table(nb_data$recommend_index))

#----------------------------------------------------------------------------#
# STEP 3: STRATIFIED TRAIN-TEST SPLIT
#----------------------------------------------------------------------------#

set.seed(123)

train_index <- createDataPartition(
  nb_data$recommend_index,
  p = 0.7,
  list = FALSE
)

nb_train <- nb_data[train_index, ]
nb_test <- nb_data[-train_index, ]

dim(nb_train)
dim(nb_test)

table(nb_train$recommend_index)
table(nb_test$recommend_index)

#----------------------------------------------------------------------------#
# STEP 4: DUMMY ENCODING
#----------------------------------------------------------------------------#

nb_train_x_raw <- nb_train %>%
  select(-recommend_index)

nb_test_x_raw <- nb_test %>%
  select(-recommend_index)

dummy_model <- dummyVars(
  ~ .,
  data = nb_train_x_raw,
  fullRank = TRUE
)

nb_train_x <- predict(dummy_model, nb_train_x_raw) %>%
  as.data.frame()

nb_test_x <- predict(dummy_model, nb_test_x_raw) %>%
  as.data.frame()

nb_train_y <- nb_train$recommend_index
nb_test_y <- nb_test$recommend_index

colnames(nb_train_x) <- make.names(colnames(nb_train_x), unique = TRUE)
colnames(nb_test_x) <- make.names(colnames(nb_test_x), unique = TRUE)

dim(nb_train_x)
dim(nb_test_x)

#----------------------------------------------------------------------------#
# STEP 5: REMOVE NEAR-ZERO VARIANCE FEATURES
#----------------------------------------------------------------------------#

nzv_cols <- nearZeroVar(nb_train_x)

length(nzv_cols)

if (length(nzv_cols) > 0) {
  nb_train_x <- nb_train_x[, -nzv_cols]
  nb_test_x <- nb_test_x[, -nzv_cols]
}

dim(nb_train_x)
dim(nb_test_x)

#----------------------------------------------------------------------------#
# STEP 6: TRAIN NAIVE BAYES MODEL
#----------------------------------------------------------------------------#

nb_model <- naiveBayes(
  x = nb_train_x,
  y = nb_train_y
)

print(nb_model)

#----------------------------------------------------------------------------#
# STEP 7: TEST SET PREDICTION
#----------------------------------------------------------------------------#

nb_pred <- predict(nb_model, newdata = nb_test_x)
nb_prob <- predict(nb_model, newdata = nb_test_x, type = "raw")

head(nb_pred)
head(nb_prob)

#----------------------------------------------------------------------------#
# STEP 8: CONFUSION MATRIX
# Same positive class as Logistic Regression
#----------------------------------------------------------------------------#

nb_cm <- confusionMatrix(
  data = nb_pred,
  reference = nb_test_y,
  positive = "Not_Recommend"
)

print(nb_cm)

accuracy <- nb_cm$overall["Accuracy"]
precision <- nb_cm$byClass["Precision"]
recall <- nb_cm$byClass["Recall"]
f1_score <- 2 * (precision * recall) / (precision + recall)

accuracy
precision
recall
f1_score

nb_cm_table <- as.data.frame(nb_cm$table)
write_csv(nb_cm_table, "NB_ConfusionMatrix_Table.csv")

#----------------------------------------------------------------------------#
# STEP 9: ROC CURVE - SAME STYLE AS LOGISTIC REGRESSION
# Uses probability of Recommend, same level order, same blue plot.
#----------------------------------------------------------------------------#

roc_nb <- roc(
  response = nb_test_y,
  predictor = nb_prob[, "Recommend"],
  levels = c("Not_Recommend", "Recommend"),
  direction = "<"
)

auc_value <- auc(roc_nb)

plot(
  roc_nb,
  col = "blue",
  main = paste0(
    "Naive Bayes ROC Curve (AUC = ",
    round(auc_value, 3),
    ")"
  )
)

auc_value

png("NB_ROC.png", width = 1000, height = 800, res = 150)

plot(
  roc_nb,
  col = "blue",
  main = paste0(
    "Naive Bayes ROC Curve (AUC = ",
    round(auc_value, 3),
    ")"
  )
)

dev.off()

#----------------------------------------------------------------------------#
# STEP 10: SAVE METRICS
#----------------------------------------------------------------------------#

nb_metrics <- data.frame(
  Model = "Naive Bayes",
  Accuracy = as.numeric(nb_cm$overall["Accuracy"]),
  Kappa = as.numeric(nb_cm$overall["Kappa"]),
  Balanced_Accuracy = as.numeric(nb_cm$byClass["Balanced Accuracy"]),
  Recall_NotRecommend = as.numeric(nb_cm$byClass["Sensitivity"]),
  Specificity_Recommend = as.numeric(nb_cm$byClass["Specificity"]),
  Precision_NotRecommend = as.numeric(nb_cm$byClass["Pos Pred Value"]),
  F1_NotRecommend = as.numeric(nb_cm$byClass["F1"]),
  AUC = as.numeric(auc_value),
  Removed_NZV_Features = length(nzv_cols)
)

print(nb_metrics)

write_csv(nb_metrics, "NB_Metrics.csv")

saveRDS(nb_model, "NB_Model.rds")

#----------------------------------------------------------------------------#
# END
#----------------------------------------------------------------------------#
