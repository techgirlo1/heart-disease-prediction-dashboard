#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)
library(ggplot2)
library(plotly)
library(randomForest)
library(tidyr)

logistic_model <- readRDS("logistic_model.rds")
rf_model <- readRDS("rf_model.rds")
model_comparison <- readRDS("model_comparison.rds")

importance_test <- drop1(logistic_model, test = "Chisq")
logistic_importance <- na.omit(data.frame(
  Variable = rownames(importance_test), Importance = importance_test$LRT
))
rf_imp <- importance(rf_model, type = 1)
rf_importance <- data.frame(Variable = rownames(rf_imp), Importance = rf_imp[, 1])
model_choices <- c("Logistic Regression" = "logistic", "Random Forest" = "rf")
model_name <- function(x) names(model_choices)[match(x, model_choices)]

# Full clinical names for the importance chart
clinical_names <- c(
  "age" = "Age",
  "sex" = "Sex",
  "cp" = "Chest Pain Type",
  "trestbps" = "Resting Blood Pressure",
  "chol" = "Cholesterol",
  "fbs" = "Fasting Blood Sugar",
  "restecg" = "Resting ECG",
  "thalach" = "Maximum Heart Rate",
  "exang" = "Exercise-Induced Angina",
  "oldpeak" = "ST Depression (Oldpeak)",
  "slope" = "ST Segment Slope",
  "ca" = "Number of Major Vessels",
  "thal" = "Thallium Heart Scan Result"
)

# Load patient dataset
heart_data <- read.csv("heart_clean.csv")

# Convert outcome to a factor
heart_data$heart_disease <- factor(
  heart_data$heart_disease,
  levels = c("No_Disease", "Disease")
)

# Use the exact factor levels from training.
categories <- logistic_model$xlevels
category_choices <- function(variable, labels) {
  codes <- categories[[variable]]
  readable <- names(labels)[match(codes, unname(labels))]
  readable[is.na(readable)] <- paste("Code", codes[is.na(readable)])
  setNames(codes, readable)
}

predict_disease <- function(patient, model_choice) {
  for (variable in names(categories)) {
    patient[[variable]] <- factor(patient[[variable]], levels = categories[[variable]])
  }
  validate(need(!anyNA(patient), "Please provide valid values for every clinical input."))
  numeric_columns <- vapply(patient, is.numeric, logical(1))
  validate(need(all(is.finite(as.matrix(patient[, numeric_columns, drop = FALSE]))),
                "Please enter finite numerical values."))
  if (model_choice == "logistic") {
    p <- predict(logistic_model, newdata = patient, type = "response")
    if (levels(logistic_model$model$heart_disease)[2] == "No_Disease") p <- 1 - p
  } else {
    p <- predict(rf_model, newdata = patient, type = "prob")[, "Disease"]
  }
  as.numeric(p)
}

ui <- fluidPage(
  tags$head(
    tags$link(rel = "stylesheet", href = "style.css")
  ),
  titlePanel("Interactive Heart Disease Prediction Dashboard"),
  tabsetPanel(
    id = "dashboard_tab",
    
    tabPanel(
      "Heart Disease Prediction",
      sidebarLayout(
        sidebarPanel(
          h4("Enter Patient Information"),
          selectInput("prediction_model", "Classification Model", model_choices, selected = "rf"),
          
          numericInput("age", "Age (years)", 55, min = 1),
          selectInput("sex", "Sex",
                      category_choices("sex", c("Female" = "0", "Male" = "1"))),
          
          selectInput("cp", "Chest Pain Type",
                      category_choices("cp", c("Typical angina" = "1",
                                               "Atypical angina" = "2",
                                               "Non-anginal pain" = "3",
                                               "Asymptomatic" = "4"))),
          
          numericInput("trestbps", "Resting Blood Pressure (mmHg)", 130),
          numericInput("chol", "Cholesterol (mg/dL)", 240),
          
          selectInput("fbs", "Fasting Blood Sugar > 120 mg/dL",
                      category_choices("fbs", c("No" = "0", "Yes" = "1"))),
          
          selectInput("restecg", "Resting ECG Result",
                      category_choices("restecg", c("Normal" = "0",
                                                    "ST-T abnormality" = "1",
                                                    "Left ventricular hypertrophy" = "2"))),
          
          numericInput("thalach", "Maximum Heart Rate", 150),
          
          selectInput("exang", "Exercise-Induced Angina",
                      category_choices("exang", c("No" = "0", "Yes" = "1"))),
          
          numericInput("oldpeak", "ST Depression (Oldpeak)", 1.0),
          
          selectInput("slope", "ST Segment Slope",
                      category_choices("slope", c("Upsloping" = "1",
                                                  "Flat" = "2",
                                                  "Downsloping" = "3"))),
          
          selectInput("ca", "Number of Major Vessels",
                      category_choices("ca", c("0" = "0", "1" = "1", "2" = "2", "3" = "3"))),
          
          selectInput("thal", "Thallium Heart Scan Result",
                      category_choices("thal", c("Normal" = "3",
                                                 "Fixed defect" = "6",
                                                 "Reversible defect" = "7"))),
          
          actionButton("predict", "Predict Heart Disease")
        ),
        mainPanel(
          h3("Prediction Result"),
          textOutput("result"),
          plotOutput("probability_plot"),
          
        )
      )
    ),
    
    # TAB 2: DATA EXPLORATION
    tabPanel(
      "Data Exploration",
      
      h3("Explore Clinical Factors"),
      
      p("Compare observed clinical measurements among patients with and without heart disease. Missing measurements are omitted from the relevant chart."),
      
      # Keep your existing X-axis selector here
      selectInput(
        "x_variable",
        "Select X-axis Variable",
        choices = c(
          "Age" = "age",
          "Cholesterol" = "chol",
          "Resting Blood Pressure" = "trestbps",
          "Maximum Heart Rate" = "thalach",
          "ST Depression (Oldpeak)" = "oldpeak"
        ),
        selected = "age"
      ),
      
      # Keep your existing Y-axis selector here
      selectInput(
        "y_variable",
        "Select Y-axis Variable",
        choices = c(
          "Age" = "age",
          "Cholesterol" = "chol",
          "Resting Blood Pressure" = "trestbps",
          "Maximum Heart Rate" = "thalach",
          "ST Depression (Oldpeak)" = "oldpeak"
        ),
        selected = "chol"
      ),
      
      plotlyOutput("clinical_scatter"),
      
      # Categorical visualization
      hr(),
      
      h3("Explore Categorical Clinical Factors"),
      
      selectInput(
        "category_variable",
        "Select Clinical Factor",
        choices = c(
          "Sex" = "sex",
          "Chest Pain Type" = "cp",
          "Fasting Blood Sugar" = "fbs",
          "Resting ECG" = "restecg",
          "Exercise-Induced Angina" = "exang",
          "ST Segment Slope" = "slope",
          "Number of Major Vessels" = "ca",
          "Thallium Heart Scan Result" = "thal"
        ),
        selected = "cp"
      ),
      
      radioButtons(
        "category_view",
        "Choose how to compare patients:",
        choices = c(
          "Patient Counts" = "count",
          "Percentage Within Each Category" = "percentage"
        ),
        selected = "percentage",
        inline = TRUE
      ),
      
      plotlyOutput("category_plot", height = "450px")),
    
    # TAB 3: MODEL PERFORMANCE
    tabPanel(
      "Model Performance",
      
      h3("Classification Model Performance"),
      p("Both models were evaluated on the same 185 testing patients after KNN imputation."),
      tableOutput("metrics_table"),
      plotOutput("comparison_plot", height = "400px"),
      selectInput("confusion_model", "Confusion Matrix Model", model_choices, selected = "rf"),
      hr(),
      
      h3("Confusion Matrix"),
      
      plotOutput(
        "confusion_plot",
        width = "100%",
        height = "450px"
      ),
      
      p("The confusion matrix shows correct and incorrect predictions.")
    ),
    
    tabPanel(
      "Predictor Importance",
      
      h3("Clinical Predictor Importance"),
      
      p("Explore which clinical factors contribute most to each model."),
      selectInput("importance_model", "Classification Model", model_choices, selected = "rf"),
      
      plotlyOutput(
        "importance_plot",
        height = "550px"
      ),
      
      p("Logistic regression uses likelihood-ratio chi-square; Random Forest uses permutation importance. Scores are not directly comparable and do not establish causation.")
    ),
    
    tabPanel(
      "What-If Analysis",
      
      h3("What-If Prediction Analysis"),
      
      p("Explore how the model's predicted probability changes when one clinical measurement varies while the other measurements remain constant."),
      p("To change the patient profile, use the inputs on the Heart Disease Prediction tab, then return here."),
      
      selectInput("whatif_model", "Classification Model", model_choices, selected = "rf"),
      selectInput(
        "whatif_variable",
        "Select Clinical Measurement",
        choices = c(
          "Age" = "age",
          "Cholesterol" = "chol",
          "Resting Blood Pressure" = "trestbps",
          "Maximum Heart Rate" = "thalach",
          "ST Depression (Oldpeak)" = "oldpeak"
        ),
        selected = "chol"
      ),
      
      plotlyOutput("whatif_plot", height = "450px"),
      
      textOutput("whatif_interpretation"),
      
      p("Educational model simulation only. Changes in predicted probability do not establish medical cause and effect.")
    )
    
  )
)

server <- function(input, output, session) {
  
  patient_data <- reactive({
    patient <- data.frame(
      age = input$age,
      sex = input$sex,
      cp = input$cp,
      trestbps = input$trestbps,
      chol = input$chol,
      fbs = input$fbs,
      restecg = input$restecg,
      thalach = input$thalach,
      exang = input$exang,
      oldpeak = input$oldpeak,
      slope = input$slope,
      ca = input$ca,
      thal = input$thal
    )
    
    patient
  })
  prediction <- eventReactive(input$predict, {
    list(p = predict_disease(patient_data(), input$prediction_model),
         model = model_name(input$prediction_model))
  })
  
  output$result <- renderText({
    p <- prediction()$p
    
    paste0(
      prediction()$model, ": estimated probability of heart disease: ",
      round(p * 100, 1), "%"
    )
  })
  
  # Prediction probability chart
  output$probability_plot <- renderPlot({
    
    p <- prediction()$p
    
    plot_data <- data.frame(
      Outcome = c("No Disease", "Heart Disease"),
      Probability = c(1 - p, p)
    )
    
    ggplot(
      plot_data,
      aes(x = Outcome, y = Probability, fill = Outcome)
    ) +
      geom_col(width = 0.5) +
      geom_text(
        aes(label = paste0(round(Probability * 100, 1), "%")),
        vjust = -0.5
      ) +
      scale_y_continuous(
        limits = c(0, 1.08),
        breaks = seq(0, 1, .25),
        labels = scales::percent
      ) +
      labs(
        title = "Predicted Outcome Probabilities",
        x = NULL,
        y = "Probability"
      ) +
      theme_minimal() +
      theme(legend.position = "none")
    
  })
  
  # Interactive clinical scatterplot
  output$clinical_scatter <- renderPlotly({
    
    p <- ggplot(
      heart_data,
      aes(
        x = .data[[input$x_variable]],
        y = .data[[input$y_variable]],
        color = heart_disease
      )
    ) +
      geom_point(alpha = 0.65, size = 2) +
      scale_color_manual(
        values = c(
          "No_Disease" = "#0d9488",
          "Disease" = "#e76f51"
        )
      ) +
      labs(
        title = "Clinical Factors and Heart Disease",
        x = input$x_variable,
        y = input$y_variable,
        color = "Heart Disease Status"
      ) +
      theme_minimal(base_size = 13)
    
    ggplotly(p)
    
  })
  
  output$metrics_table <- renderTable({
    model_comparison
  }, rownames = FALSE, digits = 2)
  
  output$comparison_plot <- renderPlot({
    d <- pivot_longer(model_comparison, c(Logistic_Regression, Random_Forest),
                      names_to = "Model", values_to = "Score")
    d$Model <- gsub("_", " ", d$Model)
    d$Metric <- factor(d$Metric, levels = model_comparison$Metric)
    ggplot(d, aes(Metric, Score, fill = Model)) +
      geom_col(position = position_dodge(.8), width = .7) +
      geom_text(aes(label = paste0(Score, "%")), position = position_dodge(.8), vjust = -.4, size = 3.5) +
      scale_fill_manual(values = c("Logistic Regression" = "#4472C4", "Random Forest" = "#ED7D31")) +
      scale_y_continuous(limits = c(0, 100)) +
      labs(title = "Model Performance Comparison", x = NULL, y = "Performance (%)") +
      theme_minimal(base_size = 13) + theme(legend.position = "bottom")
  })
  
  output$confusion_plot <- renderPlot({
    confusion_data <- data.frame(
      Actual = c(
        "No Disease", "No Disease",
        "Disease", "Disease"
      ),
      Predicted = c(
        "No Disease", "Disease",
        "No Disease", "Disease"
      ),
      Count = if (input$confusion_model == "logistic") c(61, 22, 19, 83) else c(62, 21, 12, 90)
    )
    
    ggplot(
      confusion_data,
      aes(x = Predicted, y = Actual, fill = Count)
    ) +
      geom_tile(color = "white", linewidth = 2) +
      geom_text(
        aes(label = Count),
        size = 7,
        fontface = "bold"
      ) +
      scale_fill_gradient(
        low = "#d9f2ef",
        high = "#0d9488"
      ) +
      labs(
        title = paste(model_name(input$confusion_model), "Confusion Matrix"),
        x = "Predicted Outcome",
        y = "Actual Outcome"
      ) +
      theme_minimal(base_size = 13) +
      theme(
        panel.grid = element_blank()
      )
    
  })
  
  output$category_plot <- renderPlotly({
    
    plot_data <- heart_data
    
    variable <- input$category_variable
    
    # Meaningful category labels
    category_labels <- list(
      sex = c(
        "0" = "Female",
        "1" = "Male"
      ),
      cp = c(
        "1" = "Typical Angina",
        "2" = "Atypical Angina",
        "3" = "Non-anginal Pain",
        "4" = "Asymptomatic"
      ),
      fbs = c(
        "0" = "Normal (≤120)",
        "1" = "High (>120)"
      ),
      restecg = c(
        "0" = "Normal",
        "1" = "ST-T Abnormality",
        "2" = "Left Ventricular Hypertrophy"
      ),
      exang = c(
        "0" = "No",
        "1" = "Yes"
      ),
      slope = c(
        "1" = "Upsloping",
        "2" = "Flat",
        "3" = "Downsloping"
      ),
      ca = c(
        "0" = "0 Vessels",
        "1" = "1 Vessel",
        "2" = "2 Vessels",
        "3" = "3 Vessels"
      ),
      thal = c(
        "3" = "Normal",
        "6" = "Fixed Defect",
        "7" = "Reversible Defect"
      )
    )
    
    # Convert numeric codes to readable labels
    codes <- as.character(plot_data[[variable]])
    plot_data$Category <- unname(category_labels[[variable]][codes])
    unknown <- is.na(plot_data$Category) & !is.na(codes)
    plot_data$Category[unknown] <- paste("Code", codes[unknown])
    
    # Remove missing values
    plot_data <- plot_data[
      !is.na(plot_data$Category) &
        !is.na(plot_data$heart_disease),
    ]
    
    # Create chart based on selected view
    if (input$category_view == "percentage") {
      
      p <- ggplot(
        plot_data,
        aes(
          x = Category,
          fill = heart_disease
        )
      ) +
        geom_bar(position = "fill") +
        scale_y_continuous(
          labels = scales::percent
        ) +
        labs(
          title = "Heart Disease Percentage by Clinical Category",
          x = NULL,
          y = "Percentage of Patients",
          fill = "Heart Disease Status"
        )
      
    } else {
      
      p <- ggplot(
        plot_data,
        aes(
          x = Category,
          fill = heart_disease
        )
      ) +
        geom_bar(position = "dodge") +
        labs(
          title = "Heart Disease Counts by Clinical Category",
          x = NULL,
          y = "Number of Patients",
          fill = "Heart Disease Status"
        )
    }
    
    p <- p +
      scale_fill_manual(
        values = c(
          "No_Disease" = "#0d9488",
          "Disease" = "#e76f51"
        ),
        labels = c("No Heart Disease", "Heart Disease")
      ) +
      theme_minimal(base_size = 13) +
      theme(
        axis.text.x = element_text(angle = 25, hjust = 1)
      )
    
    ggplotly(p)
    
  })
  
  output$importance_plot <- renderPlotly({
    importance_data <- if (input$importance_model == "logistic") logistic_importance else rf_importance
    importance_data$Clinical_Name <- unname(clinical_names[importance_data$Variable])
    importance_data$Clinical_Name[is.na(importance_data$Clinical_Name)] <- importance_data$Variable[is.na(importance_data$Clinical_Name)]
    
    
    p <- ggplot(
      importance_data,
      aes(
        x = Importance,
        y = reorder(Clinical_Name, Importance),
        text = paste0(
          "Clinical Factor: ", Clinical_Name,
          "<br>Importance Score: ",
          round(Importance, 2)
        )
      )
    ) +
      geom_col(
        fill = "#0d9488",
        width = 0.7
      ) +
      labs(
        title = "Clinical Predictor Importance",
        subtitle = model_name(input$importance_model),
        x = if (input$importance_model == "logistic") "Likelihood Ratio Chi-Square" else "Mean Decrease in Accuracy",
        y = "Clinical Predictor"
      ) +
      theme_minimal(base_size = 13) +
      theme(
        axis.text.y = element_text(size = 11),
        plot.title = element_text(face = "bold")
      )
    
    ggplotly(p, tooltip = "text")
    
  })
  
  # What-If Analysis
  whatif_data <- reactive({
    
    patient <- patient_data()
    
    variable <- input$whatif_variable
    
    # Use observed values to define the comparison range
    observed <- heart_data[[variable]]
    observed <- observed[is.finite(observed)]
    
    validate(
      need(length(observed) > 1, "No valid values available.")
    )
    
    values <- seq(
      min(observed),
      max(observed),
      length.out = 100
    )
    
    # Age is measured in whole years
    if (variable == "age") {
      values <- unique(round(values))
    }
    
    # Create hypothetical patient profiles
    scenarios <- patient[
      rep(1, length(values)),
      ,
      drop = FALSE
    ]
    
    scenarios[[variable]] <- values
    
    probabilities <- predict_disease(scenarios, input$whatif_model)
    current_probability <- predict_disease(patient, input$whatif_model)
    
    list(
      curve = data.frame(
        Value = values,
        Probability = probabilities
      ),
      current_value = as.numeric(patient[[variable]][1]),
      current_probability = current_probability
    )
  })
  
  
  output$whatif_plot <- renderPlotly({
    
    results <- whatif_data()
    
    current_point <- data.frame(
      Value = results$current_value,
      Probability = results$current_probability
    )
    
    p <- ggplot(
      results$curve,
      aes(x = Value, y = Probability)
    ) +
      
      geom_line(
        color = "#0d9488",
        linewidth = 1.2
      ) +
      
      geom_point(
        data = current_point,
        aes(x = Value, y = Probability),
        inherit.aes = FALSE,
        color = "#e76f51",
        size = 4
      ) +
      
      scale_y_continuous(
        labels = scales::percent,
        limits = c(0, 1)
      ) +
      
      labs(
        title = "How Clinical Measurements Affect Model Predictions",
        subtitle = paste(model_name(input$whatif_model), "| Red point = Current patient prediction"),
        x = input$whatif_variable,
        y = "Predicted Probability of Heart Disease"
      ) +
      
      theme_minimal(base_size = 13)
    
    ggplotly(p)
  })
  
  
  output$whatif_interpretation <- renderText({
    
    results <- whatif_data()
    
    low_probability <- results$curve$Probability[1]
    high_probability <- tail(results$curve$Probability, 1)
    
    direction <- if (high_probability > low_probability) {
      "increases"
    } else if (high_probability < low_probability) {
      "decreases"
    } else {
      "remains unchanged"
    }
    
    paste0(
      "Current predicted probability: ",
      round(results$current_probability * 100, 1),
      "%. Comparing the lowest and highest displayed values of ",
      input$whatif_variable,
      ", ",
      "the model's predicted probability ",
      direction,
      ", while all other clinical measurements remain constant."
    )
    
  })
}

shinyApp(ui, server)