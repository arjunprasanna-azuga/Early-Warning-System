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

# data treatment

# remove customers with no azuga id
dfRevenuCustomers <- dfRevenuCustomers[dfRevenuCustomers$`Azuga Customer ID`!="",]

table(dfRevenuCustomers$`Billing Country`)
# as we can see we have customers from Canada, India, Mexico and United States. 

# retain only USA and Canada customer
dfRevenuCustomers <- dfRevenuCustomers[dfRevenuCustomers$`Billing Country` %in% c("United States", "Canada"),]

# remove customers with customer since field as null
dfRevenuCustomers <- dfRevenuCustomers[!is.na(dfRevenuCustomers$`Customer Since`),]

# remove customers who joined after May 1, 2021
dfRevenuCustomers <- dfRevenuCustomers[dfRevenuCustomers$`Customer Since` < '2021-05-01',]

# remove customers that churned before Jan, 2019
dfRevenuCustomers <- dfRevenuCustomers[is.na(dfRevenuCustomers$`Inactive Date`) | dfRevenuCustomers$`Inactive Date` >= '2019-01-01',]

table(dfRevenuCustomers$`Account Status`)
# There is one account with the status as Closed. We will get rid of this account to ensure that the analysis is not diluted.

# remove customee wiht Account Status as Closed
dfRevenuCustomers <- dfRevenuCustomers[dfRevenuCustomers$`Account Status`!="Closed",]

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

# if Account.Status is Churned/Red, update inactive flag to 1
dfRevenuCustomers$Inactive <- ifelse((dfRevenuCustomers$`Account Status` == "Churned / Red"), 1, 0)

# if Account is not churned, remove Inactive Date
dfRevenuCustomers$`Inactive Date`[dfRevenuCustomers$Inactive == 0] <- NA

dfRevenuCustomers$`Inactive Date` <- ifelse(dfRevenuCustomers$Inactive == 1, lubridate::as_date(dfRevenuCustomers$`Inactive Date`), NA)

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

# calculate customer counts over time - active, acquired and lost
yearFrame <- as.data.frame(seq(ymd('2019-01-01'),ymd('2021-05-01'),by='months'))
colnames(yearFrame)[1] <- "YearMonth"
dataStats <- data.frame()

for (m in 1:nrow(yearFrame)){
  yearMonth <- yearFrame$YearMonth[m]
  nextYearMonth <- yearFrame$YearMonth[m+1]
  activeCustomerCount <- length(dfRevenuCustomers$`Azuga Customer ID`[dfRevenuCustomers$`Customer Since` < yearMonth & (is.na(dfRevenuCustomers$`Inactive Date`) | dfRevenuCustomers$`Inactive Date` >= yearMonth)])
  newCustomerCount <- length(dfRevenuCustomers$`Azuga Customer ID`[dfRevenuCustomers$`Customer Since` >= yearMonth &  dfRevenuCustomers$`Customer Since` < nextYearMonth])
  churnedCustomerCount <- length(dfRevenuCustomers$`Azuga Customer ID`[dfRevenuCustomers$`Inactive Date` >= yearMonth &  dfRevenuCustomers$`Inactive Date` < nextYearMonth & !is.na(dfRevenuCustomers$`Inactive Date`)])
  dataStats <- rbind(dataStats, cbind(as.character(yearMonth), as.character(nextYearMonth), as.integer(activeCustomerCount), as.integer(newCustomerCount), as.integer(churnedCustomerCount)))
}

rm(yearFrame)

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

# impact of Customer Age on churn
table(dfRevenuCustomers$customerAgeGroup, dfRevenuCustomers$Inactive)

# impact of customer size on churn
table(dfRevenuCustomers$customerSize, dfRevenuCustomers$Inactive)
