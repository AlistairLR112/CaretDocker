#' Jug Application for exposing model as an API
#' 
#' @author Alistair Rogers
#' 
#' ======= IMPORTING LIBRARIES ===========================================
#'  
suppressMessages(library(jsonlite, quietly = T))
suppressMessages(library(dplyr, quietly = T))
suppressMessages(library(jug, quietly = T))

#' ======= LOADING SERIALISED MODEL AND PREPROCESSING ====================
#' 
model <- readRDS('model.RDS')
preprocessing <- readRDS('preprocessing.RDS')

#' ============= PREDICTION METHOD =======================================
#' @param json: JSON string of Sepal.Length, Sepal.Width, Petal.Length, 
#' Petal.Width
#' @concepts Read in JSON string of predictors (described above) and apply 
#' preprocessing and predict Species.
#' @return result: JSONised dataframe of predictor columns with their species prediction
prediction <- function(json) {

  if (validate(json)){
    
    df <- fromJSON(json) %>%
      as.data.frame()
    
    result <- df %>%
      predict(preprocessing, newdata = .) %>% # Apply Preprocessing - Centering and Scaling
      predict(model, newdata = .) %>% # Apply XGBoost Model
      data.frame(Species = .) %>% # Turn predictions into Dataframe
      cbind(df, .) %>% # Concatenate
      toJSON(pretty = T)
    
  } else {
    result <- list(error = 400, message = 'Not Valid JSON')
  }
  
  return(result)
  
}

#' ========== TEST METHOD ==============================================

test_func <- function() {
  message <- 'Why Hello there chap'
  message %>% toJSON()
}

#' ========== MAIN METHOD - API ENDPOINT ===============================

main <- function() {
  jug() %>%
    post("/prediction", decorate(prediction)) %>% # Prediction Method
    get("/", decorate(test_func)) %>% # Test Method
    simple_error_handler_json() %>%
    serve_it(host = '0.0.0.0', port = 8080) # Docker container will not work unless it's on this host.
}

main()