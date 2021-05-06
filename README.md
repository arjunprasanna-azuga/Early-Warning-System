# Early-Warning-System
This repo contains details about the Early Warning System (Churn Prediction)

# Customer Data 

- get customer data from salesforceAccountSync on Pendo
- retain revenue customers
- data type conversions
- data treatment 
  - remove customers with no azuga customer id
  - retain on customers from USA and CANADA
  - remove customers with joining date as NULL (Customer Since)
  - remove customers that churned before Jan, 2019 (commence of our study period)
  - remove customers that joined us after Apr, 2021 (end of our study period)
  - remove customers with Account Status as Closed 
  - calculate customer age based on joining date
    * if the customer has churned, age is the difference between churn date and joining date
    * if the customer is still active, age is the difference between May 01 (study end date) and joining date
  Customers with negative age are the ones that have rejoined azuga. The reason for the negative age is the presence of old churn   date. In these cases, age is computed as the difference between joining date (new) and May 01 (study end date)
  - remove customers with age less than 30 days (we will not have sufficient data about them for our analysis)
  - Update Inactive Flag based on the Account Status
    * if the account is active, ensure that the Inactive Date is NULL
- data bucketing
  - categorize customers based on age
  - categorize customers based on units billed
  
# EDA

- Active and Churned Customer Counts - Find the Churn Percentage
- Customer Counts Over Month - Find the count of active customer base, customers acquired and customers lost on a MOM basis
- Check survival timelines based on the quarter of acqusition (Identify if there are any specific quarters where the churn rate    is completely different)


