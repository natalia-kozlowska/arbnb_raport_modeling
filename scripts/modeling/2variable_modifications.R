
#-----------------------------------------------------------------------------
## LOANDING DATA

airb <- read_csv("1.data/AB_NYC_2019.csv")
set.seed(1)

#-----------------------------------------------------------------------------
## 1. VARIABLE MODIFICATION
### 1.1 CHANGE TYPE IN VALUES AND REMOVING UNNECESSARY VARIABLES

airb <- airb %>% 
  mutate(neighbourhood_group = as.factor(neighbourhood_group)) %>% 
  mutate(room_type = as.factor(room_type))

#-----------------------------------------------------------------------------
## 1. VARIABLE MODIFICATION
### 1.2 NEW COLUMN 

airb <- airb %>%
  mutate(year_add = year(last_review),
         day_add   = day(last_review),
         month_add = month(last_review))

#-----------------------------------------------------------------------------
## 1. VARIABLE MODIFICATION
### 1.3 NEW COLUMN 

airb <- airb %>%    
  add_count(neighbourhood) %>% 
  rename(n_neighbourhood = n)

#-----------------------------------------------------------------------------
## 1. VARIABLE MODIFICATION
### 1.4 NEW COLUMN  

airb <- airb %>% mutate(
  price_category = as.factor(case_when(
    price <= 69 ~ "cheap",
    price >= 70 & price <= 106 ~ "regular price",
    price >= 107 & price <= 175  ~ "expensive",
    price >= 176 & price <= 2000 ~ "the most expensive",
    price >= 2001 ~ "luxuary"
  )))

#-----------------------------------------------------------------------------
## 1. VARIABLE MODIFICATION
### 1.5 NEW COLUMN  

airb <- airb %>% 
  mutate(words_number_name = as.double(sapply(strsplit(name, " "), length))) 

#-----------------------------------------------------------------------------
## 1. VARIABLE MODIFICATION
### 1.6 CREATE NEW NAME FOR COLUMNS 

airb <- airb %>% 
  rename(
    availability = availability_365,
    min_nights = minimum_nights,
    reviews_num = number_of_reviews,
    reviews_month = reviews_per_month
  )