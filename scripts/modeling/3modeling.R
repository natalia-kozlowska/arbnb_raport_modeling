#-----------------------------------------------------------------------------
## LOANDING PACKAGES 

library("naniar")
library("dplyr")
library("tidyverse")
library("caret")
library("skimr")
library("lubridate")
library("descr")
library("precrec")
library("viridis")
library("corrplot")
library("recipes")
library("scales")
library("ggmap")

#-----------------------------------------------------------------------------
## LOANDING FILES

source("2variable_modifications.R")
#------------------------------------------------------------------------------
## CREATING NEW VARIAVLE

airb$neighbourhood_group2 <- fct_collapse(airb$neighbourhood_group,
                                          Others = c("Bronx","Brooklyn",
                                                     "Staten Island", 
                                                     "Queens"),
                                          Manhattan = c("Manhattan"))
#------------------------------------------------------------------------------
                          ## CLASSIFICATION PROBLEM 
#------------------------------------------------------------------------------
## CREATING TRAIN / TEST 

air1 <- createDataPartition(y = airb$neighbourhood_group2, 
                            p = 0.7, list = FALSE) 

train1 <- dplyr::slice(airb, air1) 
dim(train1) 

test1 <- dplyr::slice(airb, -air1)
dim(test1) 

fct_count(train1$neighbourhood_group2, prop = TRUE)
#-----------------------------------------------------------------------------
## CREATING RECIPE

rec1 <- recipe(neighbourhood_group2 ~  room_type + min_nights + reviews_num + 
              reviews_month + calculated_host_listings_count + year_add + 
              day_add + month_add + words_number_name + availability + price, 
              train1) %>% 
  
  step_log(min_nights, calculated_host_listings_count) %>% 
  step_log(availability, offset = 1) %>% 
  step_log(reviews_num, offset = 1) %>% 
  step_log(price, offset = 1) %>% 
  step_knnimpute(all_predictors()) %>% 
  step_normalize(all_numeric()) %>% 
  prep(train1) 

train1 <- bake(rec1, train1) 
test1 <- bake(rec1, test1)

colSums(is.na(train1))
colSums(is.na(test1))
#----------------------------------------------------------------------------
## MODELING - NEIGHBOURHOOD GROUP 
### Crossvalidation

controls_air1 <- trainControl(
  method = "repeatedcv", number = 10, repeats = 5, 
  verboseIter = TRUE,
  classProbs = TRUE 
) 
#----------------------------------------------------------------------------
## MODELING - NEIGHBOURHOOD GROUP 
### 1. LOGISTIC REGRESSION

(air_glm1 <- train(neighbourhood_group2 ~ ., train1, method = "glm", 
                  family = "binomial", metric = "Accuracy",
                  trControl = controls_air1)) 

summary(air_glm1$finalModel) 
car::vif(air_glm1$finalModel) 
confusionMatrix(air_glm1) 
varImp(air_glm1) 
#----------------------------------------------------------------------------
## MODELING - NEIGHBOURHOOD GROUP 
### 2. RPART

y1 <- select(train1, neighbourhood_group2) %>% pull() 
X1 <- select(train1, -neighbourhood_group2) %>% as.data.frame()
(air_rpart1 <- train(X1, y1, method = "rpart", 
                    trControl = controls_air1, metric = "Accuracy", 
                    tuneGrid = data.frame(cp = c(0.001)))) 

varImp(air_rpart1)

air_rpart1$finalModel %>% rpart::prune(cp = 0.001) %>% 
  rpart.plot::rpart.plot(cex = 0.5)
#----------------------------------------------------------------------------
## MODELING - NEIGHBOURHOOD GROUP 
### 3. KNN

(air_knn1 <- train(neighbourhood_group2 ~., train1, method = "knn", 
                  trControl = controls_air1, metric = "Accuracy",
                  tuneGrid = data.frame(k = c(20))))

y1 <- select(train1, neighbourhood_group2) %>% pull()
X_dummy1 <- train1 %>%
  select(-neighbourhood_group2) %>%
  fastDummies::dummy_cols() %>% 
  select_if(is.numeric) %>%
  as.data.frame()

(air_knn2 <- train(X_dummy1, y1, method = "knn",
                   trControl = controls_air1, metric = "Accuracy",
                   tuneGrid = data.frame(k = c(20))))

varImp(air_knn2)
#------------------------------------------------------------------------------
## MODELING - NEIGHBOURHOOD GROUP 
### 4. RANDOM FOREST 

(air_forest1 <- train(X1, y1, method = "rf", 
                     trControl = controls_air1,
                     metric = "Accuracy", tuneGrid = data.frame(mtry = c(4)))) 
air_forest1$results

#------------------------------------------------------------------------------
## MODELING - NEIGHBOURHOOD GROUP 
### 5. GBOOSTING

(air_gbm1 <- train(neighbourhood_group2 ~ ., train1, method = "gbm", 
                  verbose = FALSE,
                  trControl = controls_air1,
                  metric = "Accuracy"))

air_gbm1$results %>% slice_max(Accuracy, n = 5)
#------------------------------------------------------------------------------
## MODELING - NEIGHBOURHOOD GROUP 
### 6. XGBOOST

(air_xgb1 <- train(neighbourhood_group2 ~ ., train1, method = "xgbTree",
                  trControl = controls_air1, 
                  metric = "Accuracy",))

air_xgb1$results %>% slice_max(Accuracy, n = 5)
#-----------------------------------------------------------------------------
# 7. RESULTS TRAIN - NEIGHBOURHOOD GROUP 

results.train1 <- tibble( 
  glm.air1 = predict(air_glm1, train1, type = "prob")$Manhattan,
  knn.air1 = predict(air_knn1, train1, type = "prob")$Manhattan,
  rpart.air1 = predict(air_rpart1, train1, type = "prob")$Manhattan,
  rforest.air1 = predict(air_forest1, train1, type = "prob")$Manhattan,
  gbm.air1 = predict(air_gbm1, train1, type = "prob")$Manhattan,
  xgb.air1 = predict(air_xgb1, train1, type = "prob")$Manhattan,
  neighbourhood_group2 = train1$neighbourhood_group2
)

auc1 <- evalmod(
  scores = list(results.train1$glm.air1, results.train1$knn.air1, 
                results.train1$rpart.air1, results.train1$rforest.air1,
                results.train1$gbm.air1, results.train1$xgb.air1),
  labels = results.train1$neighbourhood_group2
)

autoplot(auc1)
auc1

ggplot(results.train1, aes(glm.air1, fill = neighbourhood_group2)) + geom_density(alpha = 0.5)
ggplot(results.train1, aes(knn.air1, fill = neighbourhood_group2)) + geom_density(alpha = 0.5)
ggplot(results.train1, aes(rpart.air1, fill = neighbourhood_group2)) + geom_density(alpha = 0.5)
ggplot(results.train1, aes(rforest.air1, fill = neighbourhood_group2)) + geom_density(alpha = 0.5)
ggplot(results.train1, aes(gbm.air1, fill = neighbourhood_group2)) + geom_density(alpha = 0.5)
ggplot(results.train1, aes(xgb.air1, fill = neighbourhood_group2)) + geom_density(alpha = 0.5)

results.train1 %>% 
  gather(key = "model", value = "prob", 1:6) %>%
  filter(neighbourhood_group2 == "Manhattan") %>% 
  ggplot(aes(prob, fill = model)) + geom_density(alpha = 0.5)
#-----------------------------------------------------------------------------
# 8.RESULTS TEST - NEIGHBOURHOOD GROUP 

results.test1 <- tibble(
  glm.air1 = predict(air_glm1, test1, type = "prob")$Manhattan,
  knn.air1 = predict(air_knn1, test1, type = "prob")$Manhattan,
  rpart.air1 = predict(air_rpart1, test1, type = "prob")$Manhattan,
  rforest.air1 = predict(air_forest1, test1, type = "prob")$Manhattan,
  gb.air1 = predict(air_gbm1, test1, type = "prob")$Manhattan,
  xgb.air1 = predict(air_xgb1, test1, type = "prob")$Manhattan,
  neighbourhood_group2 = test1$neighbourhood_group2
)

auc.test1 <- evalmod(
  scores = list(results.test1$glm.air1, results.test1$rpart.air1, 
                results.test1$knn.air1, results.test1$rforest.air1,
                results.test1$gb.air1, results.test1$xgb.air1),
  labels = results.test1$neighbourhood_group2
)

autoplot(auc.test1)
auc.test1

ggplot(results.test1, aes(glm.air1, fill = neighbourhood_group2)) + geom_density(alpha = 0.5)
ggplot(results.test1, aes(knn.air1, fill = neighbourhood_group2)) + geom_density(alpha = 0.5)
ggplot(results.test1, aes(rpart.air1, fill = neighbourhood_group2)) + geom_density(alpha = 0.5)
ggplot(results.test1, aes(rforest.air1, fill = neighbourhood_group2)) + geom_density(alpha = 0.5)
ggplot(results.test1, aes(gb.air1, fill = neighbourhood_group2)) + geom_density(alpha = 0.5)
ggplot(results.test1, aes(xgb.air1, fill = neighbourhood_group2)) + geom_density(alpha = 0.5)


results.test1 %>% 
  gather(key = "model", value = "prob", 1:6) %>% 
  filter(neighbourhood_group2 == "Manhattan") %>%
  ggplot(aes(prob, fill = model)) + geom_density(alpha = 0.5)


test_neighbourhood_group <- results.test1 %>% 
  select(-neighbourhood_group2) %>% 
  map_df(postResample, obs = results.test1$neighbourhood_group2) %>% 
  mutate(model = c("glm", "knn", "rpart", "rforest", "gbm", "xgb"), 
         .before = 1)

#------------------------------------------------------------------------------
                          ## REGRESSION  PROBLEM 
#------------------------------------------------------------------------------
## CREATING TRAIN / TEST 

air2 <- createDataPartition(y = airb$price, 
                           p = 0.7, list = FALSE) 

train2 <- dplyr::slice(airb, air2) 
dim(train2) 

test2 <- dplyr::slice(airb, -air2)
dim(test2) 

#-----------------------------------------------------------------------------
## CREATING RECIPE

rec2 <- recipe(price ~ neighbourhood_group + latitude + longitude +
               room_type + min_nights + reviews_num + reviews_month +
               calculated_host_listings_count + year_add + day_add + 
               month_add + n_neighbourhood + words_number_name + availability, 
               train2) %>% 
  
  step_log(min_nights, calculated_host_listings_count) %>% 
  step_log(availability, offset = 1) %>% 
  step_log(reviews_num, offset = 1) %>% 
  step_log(price, offset = 2) %>% 
  step_knnimpute(all_predictors()) %>% 
  step_normalize(all_numeric()) %>% 
  prep(train2) 

train2 <- bake(rec2, train2) 
test2 <- bake(rec2, test2)

colSums(is.na(train2))
colSums(is.na(test2))
#----------------------------------------------------------------------------
## MODELING - PRICE
### Cross validation

controls_air2 <- trainControl(
  method = "repeatedcv", number = 10, repeats = 5, 
  verboseIter = TRUE
) 
#----------------------------------------------------------------------------
## MODELING - PRICE
### 1. LOGISTIC REGRESSION

(air_lm2 <- train(price ~ ., train2, method = "lm", 
                 trControl = controls_air2)) 

summary(air_lm2$finalModel) 
car::vif(air_lm2$finalModel) 
varImp(air_lm2) 
#----------------------------------------------------------------------------
## MODELING - PRICE
### 2. RPART

y2 <- select(train2, price) %>% pull() 
X2<- select(train2, -price) %>% as.data.frame()
(air_rpart2 <- train(X2, y2, method = "rpart", 
                    trControl = controls_air2,
                    tuneGrid = data.frame(cp = c(0.001)))) 

varImp(air_rpart2)

air_rpart2$finalModel %>% rpart::prune(cp = 0.009) %>% 
  rpart.plot::rpart.plot(cex = 0.5)
#----------------------------------------------------------------------------
## MODELING - PRICE
### 3. KNN

(air_knn2 <- train(price ~., train2, method = "knn", 
                  trControl = controls_air2,
                  tuneGrid = data.frame(k = c(5))))

y2 <- select(train2, price) %>% pull()
X_dummy2 <- train2 %>%
  select(-price) %>%
  fastDummies::dummy_cols() %>% 
  select_if(is.numeric) %>%
  as.data.frame()

(air_knn2.1 <- train(X_dummy2, y2, method = "knn",
                   trControl = controls_air2,
                   tuneGrid = data.frame(k = c(5))))

varImp(air_knn2.1)
#------------------------------------------------------------------------------
## MODELING - PRICE
### 4. RANDOM FOREST 

(air_forest2 <- train(X2, y2, method = "rf", 
                     trControl = controls_air2,
                     tuneGrid = data.frame(mtry = c(8)))) 
air_forest2$results
#------------------------------------------------------------------------------
## MODELING - PRICE
### 5. GBOOSTING

(air_gbm2 <- train(price ~ ., train2, method = "gbm", 
                   verbose = FALSE, trControl = controls_air2))

air_gbm2$results %>% slice_max(Rsquared, n = 5)
#------------------------------------------------------------------------------
## MODELING - PRICE
### 6. XGBOOST

(air_xgb2 <- train(price  ~ ., train2, method = "xgbTree",
                  trControl = controls_air2))

air_xgb2$results %>% slice_max(Rsquared, n = 5)
#-----------------------------------------------------------------------------
# TRAIN - PRICE

results.train2 <- tibble( 
  lm.air2 = predict(air_lm2, train2),
  knn.air2 = predict(air_knn2, train2),
  rpart.air2 = predict(air_rpart2, train2),
  #rforest.air2 = predict(air_forest2, train2),
  gbn.air2 = predict(air_gbm2, train2),
  xgbn.air2 = predict(air_xgb2, train2),
  price = train2$price
)

results.train2 %>% select(-price) %>% 
  map(postResample, obs = results.train2$price)

results.train2 %>% 
  gather(key = "model", value = "pred", 1:5) %>% 
  ggplot(aes(pred, fill = model)) + geom_density(alpha = 0.5)
#-----------------------------------------------------------------------------
# TEST - PRICE

results.test2 <- tibble(
  lm.air_test = predict(air_lm2, test2),
  knn.air_test = predict(air_knn2, test2),
  rpart.air_test = predict(air_rpart2, test2),
  #rforest.air2 = predict(air_forest2, test, type = "prob")$expensive,
  gbn.air_test = predict(air_gbm2, test2),
  xgbn.air_test = predict(air_xgb2, test2),
  price = test2$price
)

results.test2 %>% 
  gather(key = "model", value = "pred", 1:5) %>% 
  ggplot(aes(pred, fill = model)) + geom_density(alpha = 0.5)

test_price <- results.test2 %>% select(-price) %>% 
  map_df(postResample, obs = results.test2$price) %>% 
  mutate(model = c("lm", "knn", "rpart", "gbm", "xgb"), .before = 1)

# write_rds(test_price, "results.test2.rds")
