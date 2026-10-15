#----------------------------------------------------------------------------#
# LIBRARIES
#----------------------------------------------------------------------------#
library(shiny)
library(dplyr)
library(stringr)
library(tidytext)
library(textstem)
library(tibble)
library(ggplot2)

#----------------------------------------------------------------------------#
# LOAD MODEL + FEATURES
#----------------------------------------------------------------------------#
model <- readRDS("DecisionTree_Model.rds")
top_words <- readRDS("top_words.rds")

data("stop_words")

sentiments <- get_sentiments("bing") %>%
  distinct(word, .keep_all = TRUE)

#----------------------------------------------------------------------------#
# UI (MULTI PAGE)
#----------------------------------------------------------------------------#
ui <- navbarPage(
  
  "Customer Recommendation System",
  
  #------------------------------#
  # PAGE 1 - HOME
  #------------------------------#
  tabPanel("Home",
           fluidPage(
             h2("Customer Recommendation System"),
             p("This system predicts whether a customer will recommend a product using Decision Tree + NLP + Sentiment Analysis."),
             hr(),
             h4("Features used:"),
             tags$ul(
               tags$li("Age"),
               tags$li("Division, Department, Class"),
               tags$li("Rating"),
               tags$li("Feedback Count"),
               tags$li("Text Review (NLP + Sentiment)")
             )
           )
  ),
  
  #------------------------------#
  # PAGE 2 - PREDICTION
  #------------------------------#
  tabPanel("Prediction",
           sidebarLayout(
             
             sidebarPanel(
               
               numericInput("age", "Age", 30),
               
               selectInput("division",
                           "Division Name",
                           c("General", "General Petite", "Intimates")),
               
               selectInput("department",
                           "Department Name",
                           c("Bottoms", "Tops", "Intimate", "Jackets", "Dresses", "Trend")),
               
               selectInput("class",
                           "Class Name",
                           c(
                             "Jeans", "Blouses", "Skirts", "Pants", "Swim",
                             "Sweaters", "Knits", "Fine gauge",
                             "Jackets", "Dresses", "Shorts",
                             "Lounge", "Outerwear", "Intimates",
                             "Legwear", "Sleep", "Trend", "Layering"
                           )),
               
               sliderInput("rating",
                           "Rating",
                           1, 5, 3),
               
               numericInput("feedback",
                            "Alike Feedback Count",
                            10),
               
               textInput("title", "Review Title"),
               
               textAreaInput("review", "Review Text", rows = 5),
               
               actionButton("predict", "Predict", class = "btn-primary")
             ),
             
             mainPanel(
               
               h3("Prediction"),
               textOutput("result"),
               
               h4("Probability"),
               verbatimTextOutput("prob"),
               
               h4("Sentiment Score"),
               textOutput("sentiment")
             )
           )
  ),
  
  #------------------------------#
  # PAGE 3 - ANALYTICS
  #------------------------------#
  tabPanel("Analytics",
           fluidPage(
             
             h3("Dataset Insights"),
             
             plotOutput("sentimentPlot"),
             plotOutput("ratingPlot")
             
           )
  )
)

#----------------------------------------------------------------------------#
# SERVER
#----------------------------------------------------------------------------#
server <- function(input, output) {
  
  observeEvent(input$predict, {
    
    #------------------------------#
    # AGE GROUP
    #------------------------------#
    age_group <- case_when(
      input$age <= 25 ~ "young",
      input$age <= 35 ~ "adult",
      input$age <= 50 ~ "middle",
      input$age <= 65 ~ "senior",
      TRUE ~ "elderly"
    )
    
    #------------------------------#
    # feedback_count_group (FIXED numeric)
    #------------------------------#
    feedback_count_group <- as.numeric(input$feedback)
    
    #------------------------------#
    # TEXT CLEANING
    #------------------------------#
    text <- paste(input$title, input$review)
    
    text <- tolower(text)
    text <- str_replace_all(text, "not\\s+([a-z]+)", "not_\\1")
    text <- str_replace_all(text, "[^a-z\\s]", " ")
    text <- str_squish(text)
    
    tidy_text <- tibble(text = text) %>%
      unnest_tokens(word, text) %>%
      anti_join(stop_words, by = "word") %>%
      filter(nchar(word) > 2) %>%
      mutate(word = lemmatize_words(word))
    
    word_list <- unique(tidy_text$word)
    
    #------------------------------#
    # SENTIMENT SCORE
    #------------------------------#
    tidy_sentiment <- tidy_text %>%
      mutate(prev_word = lag(word)) %>%
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
    
    sentiment_score <- sum(tidy_sentiment$score, na.rm = TRUE)
    
    #------------------------------#
    # NLP FEATURES
    #------------------------------#
    nlp_features <- as.data.frame(matrix(0, nrow = 1, ncol = length(top_words)))
    colnames(nlp_features) <- top_words
    
    for (w in top_words) {
      if (w %in% word_list) {
        nlp_features[[w]] <- 1
      }
    }
    
    #------------------------------#
    # FINAL INPUT
    #------------------------------#
    new_data <- data.frame(
      age = input$age,
      division_name = input$division,
      department_name = input$department,
      class_name = input$class,
      rating = input$rating,
      alike_feedback_count = input$feedback,
      sentiment_score = sentiment_score,
      age_group = age_group,
      feedback_count_group = feedback_count_group
    )
    
    final_input <- cbind(new_data, nlp_features)
    
    #------------------------------#
    # PREDICTION
    #------------------------------#
    pred <- predict(model, final_input, type = "raw")
    prob <- predict(model, final_input, type = "prob")
    
    output$result <- renderText({
      paste("Prediction:", pred)
    })
    
    output$prob <- renderPrint({
      round(prob, 3)
    })
    
    output$sentiment <- renderText({
      paste("Sentiment Score:", sentiment_score)
    })
  })
  
  #------------------------------#
  # ANALYTICS PAGE (SAMPLE PLOTS)
  #------------------------------#
  
  output$sentimentPlot <- renderPlot({
    barplot(c(Positive = 120, Negative = 80, Neutral = 50),
            main = "Sentiment Distribution")
  })
  
  output$ratingPlot <- renderPlot({
    hist(c(1,2,3,4,5,5,4,3,2,5),
         main = "Rating Distribution",
         col = "lightblue")
  })
  
  #------------------------------#
  # MODEL REPORT
  #------------------------------#
  
  output$modelInfo <- renderPrint({
    "Decision Tree Model (Caret)
Accuracy ~ 0.80 - 0.85 (based on training results)
Features: Structured + NLP + Sentiment"
  })
}

#----------------------------------------------------------------------------#
# RUN APP
#----------------------------------------------------------------------------#
shinyApp(ui = ui, server = server)