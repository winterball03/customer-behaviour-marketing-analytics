#----------------------------------------------------------------------------#
# MODEL: DECISION TREE
# Target: recommend_index
#----------------------------------------------------------------------------#

install.packages(c("tidyverse", "caret", "rpart", "rpart.plot", "pROC"))

library(tidyverse)
library(caret)
library(rpart)
library(rpart.plot)
library(pROC)

#----------------------------------------------------------------------------#
# STEP 1: LOAD DATASET
#----------------------------------------------------------------------------#

final_ml_dataset <- read_csv("final_ml_dataset.csv")

dim(final_ml_dataset)
str(final_ml_dataset)
head(final_ml_dataset)

# Check target distribution
table(final_ml_dataset$recommend_index)
prop.table(table(final_ml_dataset$recommend_index))

#----------------------------------------------------------------------------#
# STEP 2: DATA PREPARATION FOR MODELLING
#----------------------------------------------------------------------------#

dt_data <- final_ml_dataset %>%
  mutate(
    recommend_index = factor(
      ifelse(recommend_index == 1, "Recommend", "Not_Recommend"),
      levels = c("Not_Recommend", "Recommend")
    )
  ) %>%
  mutate(
    across(where(is.character), as.factor)
  )

# Check again after conversion
str(dt_data$recommend_index)
table(dt_data$recommend_index)
prop.table(table(dt_data$recommend_index))

#----------------------------------------------------------------------------#
# STEP 3: TRAIN-TEST SPLIT
#----------------------------------------------------------------------------#

set.seed(123)

train_index <- createDataPartition(
  dt_data$recommend_index,
  p = 0.8,
  list = FALSE
)

train_data <- dt_data[train_index, ]
test_data  <- dt_data[-train_index, ]

dim(train_data)
dim(test_data)

#----------------------------------------------------------------------------#
# STEP 4: DECISION TREE PARAMETER TUNING
#----------------------------------------------------------------------------#

dt_control <- trainControl(
  method = "cv",
  number = 10,
  classProbs = TRUE,
  summaryFunction = twoClassSummary,
  savePredictions = "final"
)

# cp = complexity parameter
# Smaller cp allows a larger tree, larger cp creates a simpler tree
dt_grid <- expand.grid(
  cp = seq(0.001, 0.05, by = 0.001)
)

set.seed(123)

dt_model <- train(
  recommend_index ~ .,
  data = train_data,
  method = "rpart",
  metric = "ROC",
  trControl = dt_control,
  tuneGrid = dt_grid
)

print(dt_model)
plot(dt_model)

# Best tuning parameter
dt_model$bestTune

#----------------------------------------------------------------------------#
# STEP 5: PLOT FINAL DECISION TREE
#----------------------------------------------------------------------------#

png("DecisionTree_TreePlot.png", width = 1400, height = 900, res = 150)

rpart.plot(
  dt_model$finalModel,
  type = 2,
  extra = 104,
  fallen.leaves = TRUE,
  main = "Decision Tree for Predicting Customer Recommendation"
)

dev.off()

#----------------------------------------------------------------------------#
# STEP 6: VARIABLE IMPORTANCE
#----------------------------------------------------------------------------#

dt_importance <- varImp(dt_model)$importance %>%
  rownames_to_column("Feature") %>%
  arrange(desc(Overall))

print(head(dt_importance, 20))

write_csv(dt_importance, "DecisionTree_VariableImportance.csv")

top_dt_importance <- dt_importance %>%
  slice_max(order_by = Overall, n = 15)

importance_plot <- ggplot(
  top_dt_importance,
  aes(x = reorder(Feature, Overall), y = Overall)
) +
  geom_col() +
  coord_flip() +
  labs(
    title = "Top 15 Important Features in Decision Tree",
    x = "Feature",
    y = "Importance"
  ) +
  theme_minimal()

ggsave(
  "DecisionTree_VariableImportance.png",
  importance_plot,
  width = 8,
  height = 5,
  dpi = 300
)

#----------------------------------------------------------------------------#
# STEP 7: TEST SET PREDICTION
#----------------------------------------------------------------------------#

dt_pred <- predict(dt_model, newdata = test_data)
dt_prob <- predict(dt_model, newdata = test_data, type = "prob")

head(dt_pred)
head(dt_prob)

#----------------------------------------------------------------------------#
# STEP 8: CONFUSION MATRIX
# Positive class = Not_Recommend (loyalty-risk group)
#----------------------------------------------------------------------------#

dt_cm <- confusionMatrix(
  data = dt_pred,
  reference = test_data$recommend_index,
  positive = "Not_Recommend"
)

print(dt_cm)

# Save confusion matrix table
dt_cm_table <- as.data.frame(dt_cm$table)
write_csv(dt_cm_table, "DecisionTree_ConfusionMatrix_Table.csv")

cm_plot <- ggplot(dt_cm_table, aes(x = Reference, y = Prediction, fill = Freq)) +
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
    title = "Decision Tree Confusion Matrix",
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
  "DecisionTree_ConfusionMatrix.png",
  cm_plot,
  width = 6,
  height = 5,
  dpi = 300
)



#----------------------------------------------------------------------------#
# STEP 9: ROC AND AUC
#----------------------------------------------------------------------------#

dt_roc <- roc(
  response = test_data$recommend_index,
  predictor = dt_prob$Not_Recommend,
  levels = c("Recommend", "Not_Recommend")
)

dt_auc <- auc(dt_roc)
print(dt_auc)

png("DecisionTree_ROC.png", width = 1000, height = 800, res = 150)

plot(
  dt_roc,
  main = paste("Decision Tree ROC Curve, AUC =", round(dt_auc, 3))
)

dev.off()

#----------------------------------------------------------------------------#
# STEP 10: SAVE MODEL PERFORMANCE METRICS
#----------------------------------------------------------------------------#

dt_metrics <- data.frame(
  Model = "Decision Tree",
  Accuracy = as.numeric(dt_cm$overall["Accuracy"]),
  Kappa = as.numeric(dt_cm$overall["Kappa"]),
  Balanced_Accuracy = as.numeric(dt_cm$byClass["Balanced Accuracy"]),
  Recall_NotRecommend = as.numeric(dt_cm$byClass["Sensitivity"]),
  Specificity_Recommend = as.numeric(dt_cm$byClass["Specificity"]),
  Precision_NotRecommend = as.numeric(dt_cm$byClass["Pos Pred Value"]),
  F1_NotRecommend = as.numeric(dt_cm$byClass["F1"]),
  AUC = as.numeric(dt_auc),
  Best_cp = dt_model$bestTune$cp
)

print(dt_metrics)

write_csv(dt_metrics, "DecisionTree_Metrics.csv")

# Save model object
saveRDS(dt_model, "DecisionTree_Model.rds")