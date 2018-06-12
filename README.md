Training a Model
----------------

Lets train a fancy XGBoost on the iris dataset, which is a massive
overkill but it's a good example.

    data(iris)
    library(jug)
    library(caret)
    library(dplyr)
    library(xgboost)
    library(jsonlite)
    df <- iris

Preprocessing of the data
-------------------------

We will center and scale the iris data first and save the method that
allows us to do this. This is because the centering and scaling is
dependent on the data used to train the model.

    preprocessing <- df %>% 
      select(-Species) %>%
      preProcess(method = c('center', 'scale'))

    dfCenterScaled <- predict(preprocessing, df)

    head(dfCenterScaled)

    ##   Sepal.Length Sepal.Width Petal.Length Petal.Width Species
    ## 1   -0.8976739  1.01560199    -1.335752   -1.311052  setosa
    ## 2   -1.1392005 -0.13153881    -1.335752   -1.311052  setosa
    ## 3   -1.3807271  0.32731751    -1.392399   -1.311052  setosa
    ## 4   -1.5014904  0.09788935    -1.279104   -1.311052  setosa
    ## 5   -1.0184372  1.24503015    -1.335752   -1.311052  setosa
    ## 6   -0.5353840  1.93331463    -1.165809   -1.048667  setosa

Looks good, let's save it for later.

    saveRDS(preprocessing, file = 'preprocessing.RDS')

Training a model
----------------

Let's train an XGBoost model with 5 fold cross validation 10 times

First let's set the fitting control parameters for the cross validation

    fitControl <- trainControl(
      method = "repeatedcv",
      number = 10,
      repeats = 2)

And now let's train...

    set.seed(825)
    model <- train(Species ~ ., 
                     data = dfCenterScaled, 
                     method = "xgbTree", 
                     trControl = fitControl,
                     verbose = FALSE)
    model

Cool, let's save that model for later in the plumbeR app.

    saveRDS(model, file = 'model.RDS')

Creating the API
----------------

The following has been saved as **app.R**

We will be using Jug here in order to create the API as I like the
syntax. I hear it has been discontinued though which is sad. You could
also use plumber for this but I was drawn to Jug because of syntax and
CORS support.

The aim is to read the serialised model and preprocessing steps, then
use them to make a prediction.

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

### Testing the api

We will test the API predictions on a sample of data from the iris
dataset.

To get this going, run the following

    cd <PROJECT NAME>
    Rscript app.R

You should get the response

    Serving the jug at http://0.0.0.0:8080

So let's test out the testing method in Bash

    curl http://0.0.0.0:8080/

    ##   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
    ##                                  Dload  Upload   Total   Spent    Left  Speed
    ## 
      0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
    100    24  100    24    0     0    845      0 --:--:-- --:--:-- --:--:--   857
    ## ["Why Hello there chap"]

Now the prediction method. Let's use a sample of 10 rows of the iris
dataset (without Species)

    set.seed(100)
    json_test <- df[sample(1:nrow(iris), 10), ] %>%
      select(-Species) %>%
      toJSON()
    json_test

    ## [{"Sepal.Length":5.1,"Sepal.Width":3.8,"Petal.Length":1.6,"Petal.Width":0.2},{"Sepal.Length":4.4,"Sepal.Width":3,"Petal.Length":1.3,"Petal.Width":0.2},{"Sepal.Length":5.5,"Sepal.Width":2.4,"Petal.Length":3.7,"Petal.Width":1},{"Sepal.Length":4.4,"Sepal.Width":2.9,"Petal.Length":1.4,"Petal.Width":0.2},{"Sepal.Length":6.2,"Sepal.Width":2.2,"Petal.Length":4.5,"Petal.Width":1.5},{"Sepal.Length":5.9,"Sepal.Width":3.2,"Petal.Length":4.8,"Petal.Width":1.8},{"Sepal.Length":6.5,"Sepal.Width":3,"Petal.Length":5.5,"Petal.Width":1.8},{"Sepal.Length":6.9,"Sepal.Width":3.1,"Petal.Length":4.9,"Petal.Width":1.5},{"Sepal.Length":6.7,"Sepal.Width":3,"Petal.Length":5,"Petal.Width":1.7},{"Sepal.Length":4.8,"Sepal.Width":3.4,"Petal.Length":1.9,"Petal.Width":0.2}]

Now let's POST this to the API in bash

    curl -X POST -d 'json=[{"Sepal.Length":5.1,"Sepal.Width":3.8,"Petal.Length":1.6,"Petal.Width":0.2},{"Sepal.Length":4.4,"Sepal.Width":3,"Petal.Length":1.3,"Petal.Width":0.2},{"Sepal.Length":5.5,"Sepal.Width":2.4,"Petal.Length":3.7,"Petal.Width":1},{"Sepal.Length":4.4,"Sepal.Width":2.9,"Petal.Length":1.4,"Petal.Width":0.2},{"Sepal.Length":6.2,"Sepal.Width":2.2,"Petal.Length":4.5,"Petal.Width":1.5},{"Sepal.Length":5.9,"Sepal.Width":3.2,"Petal.Length":4.8,"Petal.Width":1.8},{"Sepal.Length":6.5,"Sepal.Width":3,"Petal.Length":5.5,"Petal.Width":1.8},{"Sepal.Length":6.9,"Sepal.Width":3.1,"Petal.Length":4.9,"Petal.Width":1.5},{"Sepal.Length":6.7,"Sepal.Width":3,"Petal.Length":5,"Petal.Width":1.7},{"Sepal.Length":4.8,"Sepal.Width":3.4,"Petal.Length":1.9,"Petal.Width":0.2}]' http://localhost:8080/prediction

    ##   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
    ##                                  Dload  Upload   Total   Spent    Left  Speed
    ## 
      0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
    100   756    0     0  100   756      0   3640 --:--:-- --:--:-- --:--:--  3634
    100  2080  100  1324  100   756   3645   2081 --:--:-- --:--:-- --:--:--  3637
    ## [
    ##   {
    ##     "Sepal.Length": 5.1,
    ##     "Sepal.Width": 3.8,
    ##     "Petal.Length": 1.6,
    ##     "Petal.Width": 0.2,
    ##     "Species": "setosa"
    ##   },
    ##   {
    ##     "Sepal.Length": 4.4,
    ##     "Sepal.Width": 3,
    ##     "Petal.Length": 1.3,
    ##     "Petal.Width": 0.2,
    ##     "Species": "setosa"
    ##   },
    ##   {
    ##     "Sepal.Length": 5.5,
    ##     "Sepal.Width": 2.4,
    ##     "Petal.Length": 3.7,
    ##     "Petal.Width": 1,
    ##     "Species": "versicolor"
    ##   },
    ##   {
    ##     "Sepal.Length": 4.4,
    ##     "Sepal.Width": 2.9,
    ##     "Petal.Length": 1.4,
    ##     "Petal.Width": 0.2,
    ##     "Species": "setosa"
    ##   },
    ##   {
    ##     "Sepal.Length": 6.2,
    ##     "Sepal.Width": 2.2,
    ##     "Petal.Length": 4.5,
    ##     "Petal.Width": 1.5,
    ##     "Species": "versicolor"
    ##   },
    ##   {
    ##     "Sepal.Length": 5.9,
    ##     "Sepal.Width": 3.2,
    ##     "Petal.Length": 4.8,
    ##     "Petal.Width": 1.8,
    ##     "Species": "versicolor"
    ##   },
    ##   {
    ##     "Sepal.Length": 6.5,
    ##     "Sepal.Width": 3,
    ##     "Petal.Length": 5.5,
    ##     "Petal.Width": 1.8,
    ##     "Species": "virginica"
    ##   },
    ##   {
    ##     "Sepal.Length": 6.9,
    ##     "Sepal.Width": 3.1,
    ##     "Petal.Length": 4.9,
    ##     "Petal.Width": 1.5,
    ##     "Species": "versicolor"
    ##   },
    ##   {
    ##     "Sepal.Length": 6.7,
    ##     "Sepal.Width": 3,
    ##     "Petal.Length": 5,
    ##     "Petal.Width": 1.7,
    ##     "Species": "virginica"
    ##   },
    ##   {
    ##     "Sepal.Length": 4.8,
    ##     "Sepal.Width": 3.4,
    ##     "Petal.Length": 1.9,
    ##     "Petal.Width": 0.2,
    ##     "Species": "setosa"
    ##   }
    ## ]

woohoo, that all works... now for building the Docker image

Building the Docker Image
-------------------------

We will need a requirements file, a Dockerfile specifying the commands
to build the container and the Jug app (as well as the serialised model
and preprocessing steps).

First let's build a requirements file specifying what we need

**requirements.R**

    install.packages(c('jug',
                       'jsonlite', 
                       'dplyr',
                       'caret', 
                       'xgboost'),
                    repos="http://cran.us.r-project.org")

Now let's make the Dockerfile specifying the instructions. Pay attention
to the comments.

**Dockerfile**

    FROM rocker/r-base # Base R image, Rocker contains many images for R.
    MAINTAINER Alistair Rogers

    WORKDIR /app/


    # Required in order to get Jug to work in Debian Linux. Docker containers are Debian Linux and jug requires the use of libcurl. This must be installed before Jug is.
    RUN apt-get update && apt-get install libcurl4-openssl-dev

    COPY app.R requirements.R /app/
    COPY model.RDS preprocessing.RDS /app/

    RUN Rscript /app/requirements.R

    EXPOSE 8080

    ENTRYPOINT Rscript ./app.R

Now run the following (in Bash) in order to build your Docker image. I
will not show the output here because there are 5 R packages to install
and the output is **EXTREMELY** verbose!

Trust me that it works.

    docker build . -t xgboost_iris

So after this has been built, you can test if it works with the
following command Make sure to specify a port outside of the port that
the app has running inside of the container. e.g. If it's exposed on
port 8080 in the jug app, use the port range 808X:8080 where X does not
equal 0, for example.

    docker run -p 8083:8080 -it xgboost_iris

You should receive something that looks like this (this message is from
inside of the container):

    Serving the jug at http://0.0.0.0:8080

So let's test it. (remember, port 8083!)

    curl -X POST -d 'json=[{"Sepal.Length":5.1,"Sepal.Width":3.8,"Petal.Length":1.6,"Petal.Width":0.2},{"Sepal.Length":4.4,"Sepal.Width":3,"Petal.Length":1.3,"Petal.Width":0.2},{"Sepal.Length":5.5,"Sepal.Width":2.4,"Petal.Length":3.7,"Petal.Width":1},{"Sepal.Length":4.4,"Sepal.Width":2.9,"Petal.Length":1.4,"Petal.Width":0.2},{"Sepal.Length":6.2,"Sepal.Width":2.2,"Petal.Length":4.5,"Petal.Width":1.5},{"Sepal.Length":5.9,"Sepal.Width":3.2,"Petal.Length":4.8,"Petal.Width":1.8},{"Sepal.Length":6.5,"Sepal.Width":3,"Petal.Length":5.5,"Petal.Width":1.8},{"Sepal.Length":6.9,"Sepal.Width":3.1,"Petal.Length":4.9,"Petal.Width":1.5},{"Sepal.Length":6.7,"Sepal.Width":3,"Petal.Length":5,"Petal.Width":1.7},{"Sepal.Length":4.8,"Sepal.Width":3.4,"Petal.Length":1.9,"Petal.Width":0.2}]' http://localhost:8083/prediction

    ##   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
    ##                                  Dload  Upload   Total   Spent    Left  Speed
    ## 
      0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
    100  2080  100  1324  100   756   3624   2069 --:--:-- --:--:-- --:--:--  3627
    ## [
    ##   {
    ##     "Sepal.Length": 5.1,
    ##     "Sepal.Width": 3.8,
    ##     "Petal.Length": 1.6,
    ##     "Petal.Width": 0.2,
    ##     "Species": "setosa"
    ##   },
    ##   {
    ##     "Sepal.Length": 4.4,
    ##     "Sepal.Width": 3,
    ##     "Petal.Length": 1.3,
    ##     "Petal.Width": 0.2,
    ##     "Species": "setosa"
    ##   },
    ##   {
    ##     "Sepal.Length": 5.5,
    ##     "Sepal.Width": 2.4,
    ##     "Petal.Length": 3.7,
    ##     "Petal.Width": 1,
    ##     "Species": "versicolor"
    ##   },
    ##   {
    ##     "Sepal.Length": 4.4,
    ##     "Sepal.Width": 2.9,
    ##     "Petal.Length": 1.4,
    ##     "Petal.Width": 0.2,
    ##     "Species": "setosa"
    ##   },
    ##   {
    ##     "Sepal.Length": 6.2,
    ##     "Sepal.Width": 2.2,
    ##     "Petal.Length": 4.5,
    ##     "Petal.Width": 1.5,
    ##     "Species": "versicolor"
    ##   },
    ##   {
    ##     "Sepal.Length": 5.9,
    ##     "Sepal.Width": 3.2,
    ##     "Petal.Length": 4.8,
    ##     "Petal.Width": 1.8,
    ##     "Species": "versicolor"
    ##   },
    ##   {
    ##     "Sepal.Length": 6.5,
    ##     "Sepal.Width": 3,
    ##     "Petal.Length": 5.5,
    ##     "Petal.Width": 1.8,
    ##     "Species": "virginica"
    ##   },
    ##   {
    ##     "Sepal.Length": 6.9,
    ##     "Sepal.Width": 3.1,
    ##     "Petal.Length": 4.9,
    ##     "Petal.Width": 1.5,
    ##     "Species": "versicolor"
    ##   },
    ##   {
    ##     "Sepal.Length": 6.7,
    ##     "Sepal.Width": 3,
    ##     "Petal.Length": 5,
    ##     "Petal.Width": 1.7,
    ##     "Species": "virginica"
    ##   },
    ##   {
    ##     "Sepal.Length": 4.8,
    ##     "Sepal.Width": 3.4,
    ##     "Petal.Length": 1.9,
    ##     "Petal.Width": 0.2,
    ##     "Species": "setosa"
    ##   }
    ## ]

AMAZING!

Now we can save the docker image for use later on (maybe in a cloud
service)

    docker save xgboost_iris > xgboost_iris.tar

WOOHOO
