#----------------------------------------------------------------------------#
# LOGISTIC REGRESSION MODEL - FINAL CLEAN VERSION (UNIFIED LABELS)
#----------------------------------------------------------------------------#

install.packages(c("tidyverse", "caret", "pROC"))

# Load libraries
library(tidyverse)
library(dplyr)
library(caret)
library(pROC)

#----------------------------------------------------------------------------#
# STEP 1: Check dataset
#----------------------------------------------------------------------------#
final_ml_dataset <- read_csv("final_ml_dataset.csv")

str(final_ml_dataset)
summary(final_ml_dataset)

#----------------------------------------------------------------------------#
# STEP 2: Convert target variable (IMPORTANT FIX)
# Convert 0/1 into meaningful labels
#----------------------------------------------------------------------------#

final_ml_dataset$recommend_index <- factor(
  final_ml_dataset$recommend_index,
  levels = c("0", "1"),
  labels = c("Not_Recommend", "Recommend")
)

table(final_ml_dataset$recommend_index)

#----------------------------------------------------------------------------#
# STEP 3: Stratified Train-Test Split
#----------------------------------------------------------------------------#

set.seed(123)

sample_index <- createDataPartition(
  final_ml_dataset$recommend_index,
  p = 0.7,
  list = FALSE
)

train_data <- final_ml_dataset[sample_index, ]
test_data  <- final_ml_dataset[-sample_index, ]

table(train_data$recommend_index)
table(test_data$recommend_index)

#----------------------------------------------------------------------------#
# STEP 4: Build Logistic Regression Model
#----------------------------------------------------------------------------#

logit_model <- glm(
  recommend_index ~ .,
  data = train_data,
  family = binomial
)

summary(logit_model)

#----------------------------------------------------------------------------#
# STEP 5: Predict Probabilities
#----------------------------------------------------------------------------#

pred_prob <- predict(logit_model, test_data, type = "response")

# Convert probability to class
pred_class <- ifelse(pred_prob > 0.5,
                     "Recommend",
                     "Not_Recommend")

pred_class <- factor(pred_class,
                     levels = c("Not_Recommend", "Recommend"))

test_data$recommend_index <- factor(
  test_data$recommend_index,
  levels = c("Not_Recommend", "Recommend")
)

#----------------------------------------------------------------------------#
# STEP 6: Confusion Matrix (FIXED POSITIVE CLASS)
#----------------------------------------------------------------------------#

conf_matrix <- confusionMatrix(
  data = pred_class,
  reference = test_data$recommend_index,
  positive = "Not_Recommend"
)

conf_matrix

# Extract metrics
accuracy  <- conf_matrix$overall["Accuracy"]
precision <- conf_matrix$byClass["Precision"]
recall    <- conf_matrix$byClass["Recall"]

f1_score <- 2 * (precision * recall) / (precision + recall)

accuracy
precision
recall
f1_score

#----------------------------------------------------------------------------#
# STEP 7: Feature Importance (Coefficients)
#----------------------------------------------------------------------------#

coef(logit_model)

#----------------------------------------------------------------------------#
# STEP 8: ROC CURVE (FIXED)
#----------------------------------------------------------------------------#

roc_logit <- roc(
  response = test_data$recommend_index,
  predictor = pred_prob,
  levels = c("Not_Recommend", "Recommend"),
  direction = "<"
)

auc_value <- auc(roc_logit)

plot(
  roc_logit,
  col = "blue",
  main = paste0("Logistic Regression ROC Curve (AUC = ",
                round(auc_value, 3), ")")
)

auc_value

#----------------------------------------------------------------------------#
# END
#----------------------------------------------------------------------------#
