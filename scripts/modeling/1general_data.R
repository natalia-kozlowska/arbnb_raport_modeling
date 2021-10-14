
#------------------------------------------------------------------------------
## DATA LOADING

airb <- read_csv("1.data/AB_NYC_2019.csv")
set.seed(1)
airb
table(duplicated(airb))  

#------------------------------------------------------------------------------
## GENEREL DATA SET INFO

glimpse(airb)
skim(airb)

#------------------------------------------------------------------------------
## NAN'S VALUES IN DATA SET

naniar::gg_miss_upset(airb)  
map(airb, ~mean(is.na(.)))

gmodels::CrossTable(airb$minimum_nights)



