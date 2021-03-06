"
@Project: Early Warning System
@author: ATPL 1049
@date: May 06 2021
"

# load libaries
library(dplyr)
library(dbplyr)
library(DBI)
library(RMySQL)
library(data.table)
library(reshape2)
library(ggplot2)
library(lubridate)
library(survival)
library(reshape2)
library(Information)

# disable scientific notation
options(scipen = 999)

# source if-else logic
source("/Users/arjun/Documents/ATPL1049/Workspace/R/ifElse.R")

# custom functions
`%notin%` <- Negate(`%in%`)

# get customer data

# connect to adhoc schema on pentaho db
conn_adhoc <- DBI::dbConnect(RMySQL::MySQL(), user='pentaho_ro', password='73f1c86914j2P1X', 
                             dbname='adhoc', host='pentahodb.azuga.com')

# using connection connect to table salesforceAccountSync
salesforceAccountSync <- tbl(conn_adhoc, "salesforceAccountSync")

# fetch list of customers along with some metadata
dfAccounts <- salesforceAccountSync %>%
  select(`Account Name`,`Account Type`, `Billing Country`, `SIC Code`, `Industry`, `Account Status`,
         `Azuga Customer ID`, `Customer Since`, `Revenue Since`, `Account Managed`, `Inactive Date`, `Inactive`,
         `Industry_1`, `NAICS Code`, `NAICS Industry Name`, `No. of Revenue(closing) units`, `Number of Vehicles`, 
         `SIC Industry Name`, `Account Category`, `Total Active Units`, `Rate Plan type`, `Ave. subscription rate`, `ARPU`) %>%
  collect()

# remove reference to table, disconnect db and remove connection details
rm(salesforceAccountSync)
dbDisconnect(conn_adhoc)
rm(conn_adhoc)

############################################### ANALYSIS OF CHURN RATE OVER TIME ################################################

# subset revenue customers for our analysis
dfRevenuCustomersCopy <- dfAccounts %>%
  filter(`Account Type` == "Revenue")

# data type conversions
dfRevenuCustomersCopy$`Account Type` <- as.factor(dfRevenuCustomersCopy$`Account Type`)
dfRevenuCustomersCopy$`Account Status` <- as.factor(dfRevenuCustomersCopy$`Account Status`)
dfRevenuCustomersCopy$`Account Managed` <- as.factor(dfRevenuCustomersCopy$`Account Managed`)
dfRevenuCustomersCopy$Inactive <- as.factor(dfRevenuCustomersCopy$Inactive)
dfRevenuCustomersCopy$`Account Category` <- as.factor(dfRevenuCustomersCopy$`Account Category`)
dfRevenuCustomersCopy$`Customer Since` <- lubridate::as_date(dfRevenuCustomersCopy$`Customer Since`)
dfRevenuCustomersCopy$`Inactive Date` <- lubridate::as_date(dfRevenuCustomersCopy$`Inactive Date`)
dfRevenuCustomersCopy$`Revenue Since` <- lubridate::as_date(dfRevenuCustomersCopy$`Revenue Since`)
dfRevenuCustomersCopy$`Azuga Customer ID` <- as.integer(dfRevenuCustomersCopy$`Azuga Customer ID`)

# data treatment

# remove customers with no azuga id
dfRevenuCustomersCopy <- dfRevenuCustomersCopy[!is.na(dfRevenuCustomersCopy$`Azuga Customer ID`),]

table(dfRevenuCustomersCopy$`Billing Country`)
# as we can see we have customers from Canada, India, Mexico and United States. 

# retain only USA and Canada customer
dfRevenuCustomersCopy <- dfRevenuCustomersCopy[dfRevenuCustomersCopy$`Billing Country` %in% c("United States", "Canada"),]

# remove customers with customer since field as null
dfRevenuCustomersCopy <- dfRevenuCustomersCopy[!is.na(dfRevenuCustomersCopy$`Customer Since`),]

table(dfRevenuCustomersCopy$`Account Status`)
# There is one account with the status as Closed. We will get rid of this account to ensure that the analysis is not diluted.

# remove customer wiht Account Status as Closed
dfRevenuCustomersCopy <- dfRevenuCustomersCopy[dfRevenuCustomersCopy$`Account Status`!="Closed",]

# if Account.Status is Churned/Red, update inactive flag to 1
dfRevenuCustomersCopy$Inactive <- ifelse((dfRevenuCustomersCopy$`Account Status` == "Churned / Red"), 1, 0)

# if Account is not churned, remove Inactive Date
dfRevenuCustomersCopy$`Inactive Date`[dfRevenuCustomersCopy$Inactive == 0] <- NA

# remove customers that churned before Jan, 2019
dfRevenuCustomersCopy <- dfRevenuCustomersCopy[dfRevenuCustomersCopy$`Account Status` == "Active / Green" | 
                                                 dfRevenuCustomersCopy$`Inactive Date` >= '2016-01-01',]

table(dfRevenuCustomersCopy$`Account Status`)

# calculate customer counts over time - active, acquired and lost
yearFrame <- as.data.frame(seq(ymd('2016-01-01'),ymd('2021-04-01'),by='months'))
colnames(yearFrame)[1] <- "YearQrtr"
dataStats <- data.frame()

for (m in 1:nrow(yearFrame)){
  yearMonth <- yearFrame$YearQrtr[m]
  nextYearMonth <- yearFrame$YearQrtr[m+1]
  activeCustomerCount <- length(dfRevenuCustomersCopy$`Azuga Customer ID`[dfRevenuCustomersCopy$`Customer Since` <= yearMonth & (is.na(dfRevenuCustomersCopy$`Inactive Date`) | dfRevenuCustomersCopy$`Inactive Date` >= yearMonth)])
  newCustomerCount <- length(dfRevenuCustomersCopy$`Azuga Customer ID`[dfRevenuCustomersCopy$`Customer Since` >= yearMonth &  dfRevenuCustomersCopy$`Customer Since` < nextYearMonth])
  churnedCustomerCount <- length(dfRevenuCustomersCopy$`Azuga Customer ID`[dfRevenuCustomersCopy$`Inactive Date` >= yearMonth &  dfRevenuCustomersCopy$`Inactive Date` < nextYearMonth & !is.na(dfRevenuCustomersCopy$`Inactive Date`)])
  dataStats <- rbind(dataStats, cbind(as.character(yearMonth), as.character(nextYearMonth), as.integer(activeCustomerCount), as.integer(newCustomerCount), as.integer(churnedCustomerCount)))
}

rm(yearFrame)
rm(dataStats)

############################################### ANALYSIS OF CHURN RATE OVER TIME ################################################

############################################### CHURN ANALYSIS - SPECIFIC PERIOD ################################################

# subset revenue customers for our analysis
dfRevenuCustomers <- dfAccounts %>%
  filter(`Account Type` == "Revenue")

# data type conversions
dfRevenuCustomers$`Account Type` <- as.factor(dfRevenuCustomers$`Account Type`)
dfRevenuCustomers$`Account Status` <- as.factor(dfRevenuCustomers$`Account Status`)
dfRevenuCustomers$`Account Managed` <- as.factor(dfRevenuCustomers$`Account Managed`)
dfRevenuCustomers$Inactive <- as.factor(dfRevenuCustomers$Inactive)
dfRevenuCustomers$`Account Category` <- as.factor(dfRevenuCustomers$`Account Category`)
dfRevenuCustomers$`Customer Since` <- lubridate::as_date(dfRevenuCustomers$`Customer Since`)
dfRevenuCustomers$`Inactive Date` <- lubridate::as_date(dfRevenuCustomers$`Inactive Date`)
dfRevenuCustomers$`Revenue Since` <- lubridate::as_date(dfRevenuCustomers$`Revenue Since`)
dfRevenuCustomers$`Azuga Customer ID` <- as.integer(dfRevenuCustomers$`Azuga Customer ID`)

# data treatment

# remove customers with no azuga id
dfRevenuCustomers <- dfRevenuCustomers[!is.na(dfRevenuCustomers$`Azuga Customer ID`),]

table(dfRevenuCustomers$`Billing Country`)
# as we can see we have customers from Canada, India, Mexico and United States. 

# retain only USA and Canada customer
dfRevenuCustomers <- dfRevenuCustomers[dfRevenuCustomers$`Billing Country` %in% c("United States", "Canada"),]

# remove customers with customer since field as null
dfRevenuCustomers <- dfRevenuCustomers[!is.na(dfRevenuCustomers$`Customer Since`),]

table(dfRevenuCustomers$`Account Status`)
# There is one account with the status as Closed. We will get rid of this account to ensure that the analysis is not diluted.

# remove customer wiht Account Status as Closed
dfRevenuCustomers <- dfRevenuCustomers[dfRevenuCustomers$`Account Status`!="Closed",]

# if Account.Status is Churned/Red, update inactive flag to 1
dfRevenuCustomers$Inactive <- ifelse((dfRevenuCustomers$`Account Status` == "Churned / Red"), 1, 0)

# remove customers who joined after May 1, 2021
dfRevenuCustomers <- dfRevenuCustomers[dfRevenuCustomers$`Customer Since` < '2021-05-01',]

# remove customers that churned before Jan, 2019
dfRevenuCustomers <- dfRevenuCustomers[dfRevenuCustomers$`Account Status` == "Active / Green" | 
                                         dfRevenuCustomers$`Inactive Date` >= '2019-01-01',]

# calculate age of the customer based on joining date

# difference between churn date and joining date
dfRevenuCustomers$customerAge <- difftime(dfRevenuCustomers$`Inactive Date`, dfRevenuCustomers$`Customer Since`, units = 'days')

# if customer age is NA (because of the absence of inactive date), calculate age as the difference between joining date and May 01 (end of study period)
dfRevenuCustomers$customerAge <-   ifelse(is.na(dfRevenuCustomers$customerAge), 
                                   difftime(as.Date("2021-05-01"), dfRevenuCustomers$`Customer Since`, units = "days"),
                                   dfRevenuCustomers$customerAge)
# if customer age is negative (because this is a customer who has rejoined Azuga and our systems do not refresh the old churn date), compute age as the difference between joining date and May 01 (end of study period)
dfRevenuCustomers$customerAge <-   ifelse(dfRevenuCustomers$customerAge<0, 
                                   difftime(as.Date("2021-05-01"), dfRevenuCustomers$`Customer Since`, units = "days"),
                                   dfRevenuCustomers$customerAge)

# retain customers that have spent atleast 30 days with Azuga
# dfRevenuCustomers <- dfRevenuCustomers[dfRevenuCustomers$customerAge>=30,]

# if Account is not churned, remove Inactive Date
dfRevenuCustomers$`Inactive Date`[dfRevenuCustomers$Inactive == 0] <- NA

# data bucketing

# categorize customers based on age
dfRevenuCustomers$customerAgeGroup <- ie(
  i(dfRevenuCustomers$customerAge<=30, 'Less Than a Month'),
  i(dfRevenuCustomers$customerAge>30 & dfRevenuCustomers$customerAge <= 90, '1-3 Months'),
  i(dfRevenuCustomers$customerAge>90 & dfRevenuCustomers$customerAge <= 180, '3-6 Months'),
  i(dfRevenuCustomers$customerAge>180 & dfRevenuCustomers$customerAge <= 365, '6-12 Months'),
  i(dfRevenuCustomers$customerAge>365 & dfRevenuCustomers$customerAge <= 730, '1-2 Years'),
  i(dfRevenuCustomers$customerAge>730, 'More than 2 Years'),
  e('Unknown')
)

# categorize customers based on units billed
dfRevenuCustomers$customerSize <- ie(
  i(dfRevenuCustomers$`Total Active Units`<=10, 'Less than 11 Units'),
  i(dfRevenuCustomers$`Total Active Units`>10 & dfRevenuCustomers$`Total Active Units` <= 25, '11-25 Units'),
  i(dfRevenuCustomers$`Total Active Units`>25 & dfRevenuCustomers$`Total Active Units` <= 50, '26-50 Units'),
  i(dfRevenuCustomers$`Total Active Units`>50 & dfRevenuCustomers$`Total Active Units` <= 109, '51-109 Units'),
  i(dfRevenuCustomers$`Total Active Units`>109 & dfRevenuCustomers$`Total Active Units` <= 250, '110-250 Units'),
  i(dfRevenuCustomers$`Total Active Units`>250 & dfRevenuCustomers$`Total Active Units` <= 500, '251-500 Units'),
  e('More than 500 Units')
)

# exploratory data analysis

# check split of active and churned customers
table(dfRevenuCustomers$Inactive)
table(dfRevenuCustomers$`Account Status`)

# calculate customer counts over time - active, acquired and lost
yearFrame <- as.data.frame(seq(ymd('2019-01-01'),ymd('2021-05-01'),by='months'))
colnames(yearFrame)[1] <- "YearMonth"
dataStats <- data.frame()

for (m in 1:nrow(yearFrame)){
  yearMonth <- yearFrame$YearMonth[m]
  nextYearMonth <- yearFrame$YearMonth[m+1]
  activeCustomerCount <- length(dfRevenuCustomers$`Azuga Customer ID`[dfRevenuCustomers$`Customer Since` <= yearMonth & (is.na(dfRevenuCustomers$`Inactive Date`) | dfRevenuCustomers$`Inactive Date` >= yearMonth)])
  newCustomerCount <- length(dfRevenuCustomers$`Azuga Customer ID`[dfRevenuCustomers$`Customer Since` >= yearMonth &  dfRevenuCustomers$`Customer Since` < nextYearMonth])
  churnedCustomerCount <- length(dfRevenuCustomers$`Azuga Customer ID`[dfRevenuCustomers$`Inactive Date` >= yearMonth &  dfRevenuCustomers$`Inactive Date` < nextYearMonth & !is.na(dfRevenuCustomers$`Inactive Date`)])
  dataStats <- rbind(dataStats, cbind(as.character(yearMonth), as.character(nextYearMonth), as.integer(activeCustomerCount), as.integer(newCustomerCount), as.integer(churnedCustomerCount)))
}

rm(yearFrame)
rm(dataStats)
# Survival Analysis

# generate timeline for the survival plot
t <- seq(from=0, to=900, by=15)

# change the below dates for the different quarters
df <- dfRevenuCustomers[(dfRevenuCustomers$`Customer Since` >= '2020-10-01' & 
                           dfRevenuCustomers$`Customer Since` < '2021-01-01'),]

fit <- survfit(Surv(customerAge, Inactive) ~ 1, data = df)
summary(fit, times=t)

# survival
# survivalObject <- Surv(time = df$customerAge, event = df$Inactive)
# plot(survivalObject)
rm(df, fit)

# impact of customer age on churn
table(dfRevenuCustomers$customerAgeGroup, dfRevenuCustomers$Inactive)

# impact of customer size on churn
table(dfRevenuCustomers$customerSize, dfRevenuCustomers$Inactive)

# impact of account type  on churn
table(dfRevenuCustomers$`Account Managed`, dfRevenuCustomers$Inactive)
dfRevenuCustomers$`Account Managed` <- as.character(dfRevenuCustomers$`Account Managed`)
dfRevenuCustomers$`Account Managed`[is.na(dfRevenuCustomers$`Account Managed`)] <- "Blank"
table(dfRevenuCustomers$`Account Managed`, dfRevenuCustomers$Inactive)

# impact of plan type on churn
table(dfRevenuCustomers$`Rate Plan type`)

# one customer can have more than one plan types.. So, lets first split it into rows

# Split rows based on plan type
tempData <- strsplit(dfRevenuCustomers$`Rate Plan type`, split = ":")
tempData <- data.frame(V1 = rep(dfRevenuCustomers$`Azuga Customer ID`, sapply(tempData, length)), V2 = unlist(tempData))
tempData$V1 <- trimws(tempData$V1)
tempData$V2 <- trimws(tempData$V2)

tempData2 <- strsplit(tempData$V2, split = ";")
tempData2 <- data.frame(V1 = rep(tempData$V1, sapply(tempData2, length)), V2 = unlist(tempData2))
tempData2$V1 <- trimws(tempData2$V1)
tempData2$V2 <- trimws(tempData2$V2)

rm(tempData)
table(tempData2$V2)
length(unique(tempData2$V2))

# bucketing of plans
tempData2$planType <- ie(
  i(tempData2$V2 %like% 'Package 1', 'Package 1'),
  i(tempData2$V2 %like% 'Package 2', 'Package 2'),
  i(tempData2$V2 %like% 'Package 3', 'Package 3'),
  i(tempData2$V2 %like% 'Package 4', 'Package 4'),
  i(tempData2$V2 %like% 'Azuga G2 Bundled', 'Azuga G2 Bundled'),
  i(tempData2$V2 %like% 'Azuga G2 Flex', 'Azuga G2 Flex'),
  i(tempData2$V2 %like% 'Phlytrac', 'PHLY'),
  i(tempData2$V2 %like% 'PhlyTrack', 'PHLY'),
  i(tempData2$V2 %like% 'PHLY', 'PHLY'),
  i(tempData2$V2 %like% 'SafetyCam', 'SafetyCam'),
  i(tempData2$V2 %like% 'Dual', 'SafetyCam'),
  i(tempData2$V2 %like% 'Azuga Asset Tracker', 'Azuga Asset Tracker'),
  i(tempData2$V2 %like% 'Azuga BasicFleet Bundle', 'Azuga BasicFleet Bundle'),
  i(tempData2$V2 %like% 'BYOT', 'eLogs - BYOT'),
  i(tempData2$V2 %like% 'e-Logs', 'eLogs - NON-BYOT'),
  i(tempData2$V2 %like% 'Azuga Lite', 'Azuga Lite'),
  e('Others')
)

tempData2$val <- 1

tempData <-
  dcast(tempData2, V1 ~ planType, value.var  = 'val')

tempData$RatePlan <- ie(
  i(tempData$PHLY > 0 , 'Phly'),
  i(tempData$SafetyCam > 0 , 'SafetyCam'),
  i(tempData$`eLogs - BYOT` > 0 | tempData$`eLogs - NON-BYOT` > 0 , 'eLogs'),
  i(tempData$`Azuga Asset Tracker` > 0 , 'Azuga Asset Tracker'),
  i(tempData$`Azuga BasicFleet Bundle` > 0 | tempData$`Azuga G2 Bundled` >0 | tempData$`Azuga G2 Flex` >0  , 'Azuga Bundle'),
  i(tempData$`Azuga Lite` > 0 , 'Azuga Lite'),
  e('Others')
)

tempData$V1 <- as.integer(tempData$V1)
tempData <- 
  left_join(tempData, dfRevenuCustomers[,c(7,12)], by = c('V1' = 'Azuga Customer ID'))

table(tempData$RatePlan, tempData$Inactive)

table(tempData2$planType)
tempData2$V1 <- as.integer(tempData2$V1)
tempData2 <- tempData2[!is.na(tempData2$V1),]
tempData2 <-
  left_join(tempData2, dfRevenuCustomers[,c(7,12)], by = c('V1' = 'Azuga Customer ID'))

table(tempData2$planType, tempData2$Inactive)

# impact of industry on churn
dfRevenuCustomers$Industry2Digit <- substr(dfRevenuCustomers$`SIC Code`,1,2)
table(dfRevenuCustomers$Industry2Digit, dfRevenuCustomers$Inactive)

# WOE

dfRevenuCustomers$Industry2Digit <- as.factor(dfRevenuCustomers$Industry2Digit)
# revenueCustomers$Inactive <- as.integer(revenueCustomers$Inactive)

IV <- create_infotables(data=dfRevenuCustomers[,c(12,27)], y="Inactive", bins=10, parallel=FALSE)
IV_Value = data.frame(IV$Tables)
plot_infotables(IV, "Industry2Digit")

IV_Value$SIC_Category <- ie(
  i(IV_Value$Industry2Digit.WOE == 0, 'SIC_Category 1'),
  i(IV_Value$Industry2Digit.WOE < -0.5 , 'SIC_Category 2'),
  i(IV_Value$Industry2Digit.WOE <0 & IV_Value$Industry2Digit.WOE >= -0.5, 'SIC_Category 3'),
  i(IV_Value$Industry2Digit.WOE >0 & IV_Value$Industry2Digit.WOE <= 0.5, 'SIC_Category 4'),
  i(IV_Value$Industry2Digit.WOE >0.5 & IV_Value$Industry2Digit.WOE <= 1, 'SIC_Category 5'),
  i(IV_Value$Industry2Digit.WOE >1, 'SIC_Category 6'),
  e('Others')
)
rm(IV)

# join back with revenue customers
dfRevenuCustomers <- left_join(dfRevenuCustomers, IV_Value[,c(1,6)], by=c('Industry2Digit' = 'Industry2Digit.Industry2Digit'))
table(dfRevenuCustomers$SIC_Category, dfRevenuCustomers$Inactive)

# count of industries in each category and count of customers in each bracket
dfRevenuCustomers %>%
  group_by(SIC_Category) %>%
  dplyr::summarise(countOfIndustries=n_distinct(Industry2Digit),
                   countOfCustomers=n())

industryMappingFile <-  dfRevenuCustomers[,c(1, 4, 5, 7, 13, 14, 15, 18, 27, 28)]
write.csv(industryMappingFile, file = 'industryMapping.csv')

