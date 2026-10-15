
# Customer Behaviour & Marketing Analytics

**Turning customer reviews into actionable insights through data analytics, machine learning, and R Shiny.**

[![R](https://img.shields.io/badge/R-276DC3?logo=r&logoColor=white)](https://www.r-project.org/)
[![Shiny](https://img.shields.io/badge/R_Shiny-75AADB?logo=posit&logoColor=white)](https://shiny.posit.co/)
![Machine Learning](https://img.shields.io/badge/Machine_Learning-Predictive_Analytics-purple)

### 🌐 [Explore the Live R Shiny Application](https://marketing-2-cds501.shinyapps.io/marketing-app/)

![R Shiny Dashboard](screenshots/Dashboard.png)

---

## 📌 About the Project

Developed for **CDS501 – Principles & Practices of Data Science & Analytics** at Universiti Sains Malaysia (USM), this project explores how customer reviews can help a clothing retailer improve product satisfaction and identify potential customer loyalty risks.

Using the **Clothing Reviews Dataset**, containing approximately 23,486 original reviews, we investigated three key areas:

- **Customer Behaviour:** Understanding satisfaction, preferences, and recommendation patterns.
- **Predictive Analytics:** Identifying customers who may be unlikely to recommend products.
- **Business Insights:** Translating analytical findings into practical marketing and product improvement recommendations.

The project was completed across three stages:

| Stage | Focus |
|---|---|
| Assignment 1 | Data Preparation, Exploratory Analysis & Statistical Testing |
| Assignment 2 | Feature Selection, Machine Learning & Model Evaluation |
| Assignment 3 | Data Storytelling & R Shiny Deployment |

---

## 📊 Key Findings

### 1. Product Satisfaction & Recommendation Patterns

![Recommendation Rates](screenshots/recommendation-rate-by-category.png)

**Jeans and Layering** recorded the strongest recommendation performance at approximately **87.9%**, while **Trend** had the lowest rate at approximately **74.6%**.

These findings highlight opportunities to prioritise high-performing product categories while investigating factors affecting customer satisfaction in weaker categories.

### 2. Understanding Negative Customer Feedback

![Negative Review Analysis](screenshots/negative-review-terms.png)

Text analysis identified recurring terms such as **dress, fabric, fit, size, and material** in low-rated and non-recommended reviews.

While dresses generated substantial positive feedback, they also contributed a high volume of negative reviews.

**Potential improvement:** Strengthen product quality monitoring, sizing accuracy, and product information to address recurring complaints.

### 3. Customer Demographics & Loyalty

![Age Group Analysis](screenshots/recommendation-by-age-group.png)

Recommendation behaviour differed across customer age groups:

- **Young customers:** Highest recommendation rate (84.81%)
- **Adult customers:** Lowest recommendation rate (79.26%)
- **Senior and elderly customers:** Both exceeded 84%

These differences can inform customer segmentation and targeted marketing initiatives.

A separate statistical test also found that customers who recommended products gave significantly higher ratings (**4.60**) than those who did not (**2.30**).

---

## 🤖 Predictive Analytics

### Predicting Customer Recommendations

To identify potential loyalty risks, we developed four classification models using customer demographics, product information, ratings, sentiment scores, and review-text features.

Feature selection involved **TF-IDF, Chi-square testing, and statistical significance analysis**, retaining 176 features for model development.

![Feature Importance](screenshots/feature-importance.png)

### Model Comparison

| Model | Accuracy | AUC |
|---|---:|---:|
| **Decision Tree** | **94.3%** | 0.967 |
| Logistic Regression | 93.7% | **0.981** |
| K-Nearest Neighbours | 86.6% | 0.948 |
| Naive Bayes | 83.0% | 0.923 |

The **Decision Tree** was selected for deployment because it achieved the strongest overall classification accuracy and a **93.7% recall for the Not Recommend class**.

![Decision Tree ROC Curve](screenshots/decision-tree-roc.png)

Its interpretable decision rules also make the model useful for understanding factors associated with customer dissatisfaction.

---

## 🌐 Interactive R Shiny Application

The final model was integrated into a web application with three main components:

| Feature | Function |
|---|---|
| **Dashboard** | Explore customer ratings, recommendation rates, and demographic distributions |
| **Database** | Browse and examine customer review records |
| **ML Prediction** | Predict recommendation outcomes through individual inputs or CSV uploads |

**[🚀 Launch the Application](https://marketing-2-cds501.shinyapps.io/marketing-app/)**

---

## 🛠️ Technologies & Methods

| Area | Technologies / Methods |
|---|---|
| Programming & Deployment | R, R Shiny |
| Data Analytics | Data Cleaning, EDA, Data Visualisation |
| Text Analytics | NLP, TF-IDF, Sentiment Analysis |
| Statistical Methods | Chi-square, Welch t-test |
| Machine Learning | Decision Tree, Logistic Regression, KNN, Naive Bayes |
| Model Evaluation | Confusion Matrix, Accuracy, Precision, Recall, F1-score, ROC-AUC |

---

## 📁 Project Files

| Folder | Contents |
|---|---|
| `assignment-1/` | Data preparation and exploratory analysis R scripts |
| `assignment-2/` | Feature selection, model training, and evaluation R scripts |
| `assignment-3/` | R Shiny application source and supporting files |
| `screenshots/` | Application previews and analytical visualisations |

To run the project locally, install **R and RStudio**, prepare the required packages and supporting datasets, and execute the relevant R scripts. The Shiny application may also require saved model files.

---

## 👥 Contributors

**CDS501 – Principles & Practices of Data Science & Analytics**  
Universiti Sains Malaysia (USM)

A collaborative academic project developed by:

- Muhammad Huzaifah bin Hairul Nizam
- Grace Tan Ying Hui
- Ooi Khel Yin

*The live R Shiny application is hosted through a group member's account.*

---

**Note:** This academic case study uses customer recommendation behaviour as an indicator of potential loyalty risk. The findings and predictions demonstrate analytical approaches rather than verified improvements in actual retail sales or customer retention.

