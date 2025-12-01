/*------------------------------------Data upload---------------------------------*/
create table main_table 
(id varchar(20), 
state varchar(20), 
pname varchar(100), 
country varchar(20),
location_id varchar(20),
creator_id varchar(20),
category_id varchar(20),
created_at_date date,
deadline_date date,
updated_date date,
state_changed_at_date date,
successful_at_date date,
launched_at_date date,
goal double,
pledged double,
currency varchar(20),
currency_symbol varchar(20),
usd_pledged double,
static_usd_rate double,
backers_count bigint);

select count(id) from main_table;
select * from main_table;

create table location_table 
(id	varchar(200),
displayable_name varchar(200),	
typ varchar(200),
nam varchar(200),
state varchar(200),
place_name varchar(200));

select * from location_table;
select count(id) from location_table;

create table category_table 
(id	varchar(200),
nam varchar(200),
parent_id varchar(200),
position varchar(200));

select * from category_table;
select count(id) from category_table;

create table creator_table 
(id	varchar(200),
nam varchar(200));

select * from creator_table;
select count(id) from creator_table;

/*----------------------------Data Upload------------------------------------------------------------------*/

/*------------------------------ All KPIs-------------------------------------------------------------------*/

Select * from main_table;
select * from category_table;
select * from location_table;
set sql_safe_updates =0;


/*

2. Build a Calendar Table using the Date Column Created Date ( Which has Dates from Minimum Dates and Maximum Dates)
  Add all the below Columns in the Calendar Table using the Formulas.
   A.Year
   B.Monthno
   C.Monthfullname
   D.Quarter(Q1,Q2,Q3,Q4)
   E. YearMonth ( YYYY-MMM)
   F. Weekdayno
   G.Weekdayname
   H.FinancialMOnth ( April = FM1, May= FM2  &. March = FM12)
   I. Financial Quarter ( Quarters based on Financial Month FQ-1 . FQ-2..)
*/

SET @@cte_max_recursion_depth = 10000000;


WITH RECURSIVE DateRange AS (
  SELECT MIN(created_at_date) AS dt, MAX(created_at_date) AS end_date
  FROM main_table

  UNION ALL

  SELECT DATE_ADD(dt, INTERVAL 1 DAY), end_date
  FROM DateRange
  WHERE dt <= end_date
)
SELECT dt AS Date,
year(dt) as year, month(dt) as month_no, 
monthname(dt) as month_name, quarter(dt) as quarter,
date_format(dt, '%Y-%b') as YearMonth,
dayofweek(dt) as weekday_no,
dayname(dt) AS weekday_name,
case 
when (month(dt) - 3) > 0 then concat("FM",month(dt)-3)
else concat("FM",month(dt))
end as Financial_month,
case 
when (quarter(dt) - 1) > 0 then concat("FQ-",quarter(dt)-1)
else concat("FM-",quarter(dt))
end as Financial_quarter
FROM DateRange;




# Q4. Convert the Goal amount into USD using the Static USD Rate.

Alter table main_table add column goal_USD double after usd_pledged;
update main_table set goal_USD = goal*static_usd_rate;
Alter table main_table drop column goal_USD;

select *, round((goal*static_usd_rate),2) as goal_USD from main_table;


# 5a. Projects Overview KPI : Total Number of Projects based on outcome

select state, count(id) as no_of_projects from main_table group by state order by no_of_projects desc; 

# 5b. Projects Overview KPI : Total Number of Projects based on Locations

select country, count(id) as no_of_projects from main_table group by country order by no_of_projects desc; 

# 5c. Projects Overview KPI : Total Number of Projects based on Category

select c.nam as category_name,
count(m.id) as no_of_projects
from main_table m join category_table c on m.category_id=c.id 
group by c.nam order by no_of_projects desc;

# 5d. Projects Overview KPI : Total Number of Projects created by Year

select year(created_at_date) as year,count(id) as no_of_projects from main_table group by year(created_at_date);

# 5d. Projects Overview KPI : Total Number of Projects created by Quarter

select concat('Q',quarter(created_at_date)) as Quarter_no,count(id) as No_of_projects from main_table count
group by Quarter_no order by Quarter_no;

# 5d. Projects Overview KPI : Total Number of Projects created by month

select monthname(created_at_date) as month_name,count(id) as no_of_projects from main_table 
group by monthname(created_at_date),month(created_at_date) order by month(created_at_date);

# 6a. Amount Raised for successful projects:

select concat("$ ",round(sum(usd_pledged)/1000000,2)," Million") as Total_amount_for_successful_projects 
from main_table where state = "successful";

# 6b. number of backers for successful projects:

select concat(round(sum(backers_count)/1000000,2)," Million") as Total_backers_for_successful_projects 
from main_table where state = "successful";

# 6c. Avg number of days for successful projects:

with cte as 
(select datediff(successful_at_date,created_at_date) as date_diff, id from main_table where state = "successful") 
select concat(ceiling(avg(date_diff))," Days") as Avg_days_for_successful_projects from cte;

# 7a . Top Successful Projects : Based on Number of Backers

select pname as Project_name, concat(round((backers_count/1000),2)," K") as No_of_Backers
from main_table where state = "successful" order by backers_count desc limit 5;

# 7b . Top Successful Projects : Based on Amount Raised

select pname as Project_name, concat("$ ",round((usd_pledged/1000000),2), " Million") as Amount_raised 
from main_table where state = "successful" order by usd_pledged desc limit 5;

# 8a. Percentage of Successful Projects overall

select 
concat(round(((select count(id) from main_table where state = "successful")/(select count(id) from main_table)*100),2)," %") 
as Percent_of_successful_projects;

# 8b. Percentage of Successful Projects  by Category

SELECT
    c.nam as category, 
    SUM(CASE WHEN m.state = 'successful' THEN 1 ELSE 0 END) as Successful_Projects,
    COUNT(m.id) as total_projects,
   concat(ROUND(
        100.0 * SUM(CASE WHEN m.state = 'successful' THEN 1 ELSE 0 END) / COUNT(m.id),
        2
    ),"%") AS success_percentage
FROM main_table m join category_table c on m.category_id = c.id
GROUP BY c.nam
ORDER BY (SUM(CASE WHEN m.state = 'successful' THEN 1 ELSE 0 END) / COUNT(m.id)) Desc;

# 8c. Percentage of Successful Projects by Year

select year(created_at_date) as year, count(id) as total_projects, 
		sum(case when state ="successful" then 1 else 0 end) as successful_projects,
		concat(Round((sum(case when state ="successful" then 1 else 0 end)/count(id))*100,2), "%") as successful_percent
from main_table group by year order by year desc;

# Percentage of Successful Projects by Quarter

select concat("Q", Quarter(created_at_date)) as Quarter, count(id) as total_projects, 
		sum(case when state ="successful" then 1 else 0 end) as successful_projects,
		concat(Round((sum(case when state ="successful" then 1 else 0 end)/count(id))*100,2), "%") as successful_percent
from main_table group by Quarter order by Quarter;


# Percentage of Successful Projects by Month


select monthname(created_at_date) as Month_name, count(id) as total_projects, 
		sum(case when state ="successful" then 1 else 0 end) as successful_projects,
		concat(Round((sum(case when state ="successful" then 1 else 0 end)/count(id))*100,2), "%") as successful_percent
from main_table group by Month_name, month(created_at_date)
order by month(created_at_date);



# 8c. Percentage of Successful projects by Goal Range ( decide the range as per your need )


with cte as 
(select *, goal*static_usd_rate as goal_USD from main_table)
select count(id) as Total_projects, 
		sum(case when state ="successful" then 1 else 0 end) as Successful_projects,
		concat(Round((sum(case when state ="successful" then 1 else 0 end)/count(id))*100,2), "%") as Successful_percent
from cte where goal_USD < 100000;


#OR


WITH cte AS (
    SELECT *, goal * static_usd_rate AS goal_USD
    FROM main_table
)
SELECT 
    CASE 
        WHEN goal_USD < 1000 THEN '< 1k USD'
        WHEN goal_USD BETWEEN 1000 AND 10000 THEN '1k–10k USD'
        WHEN goal_USD BETWEEN 10000 AND 100000 THEN '10k–100k USD'
        WHEN goal_USD BETWEEN 100000 AND 1000000 THEN '100k–1 Million USD'
        WHEN goal_USD BETWEEN 1000000 AND 10000000 THEN '1 Million–10 Million USD'
        ELSE 'Above 10 Million'
    END AS Goal_Range,
    concat(ROUND(
        (SUM(CASE WHEN state = 'successful' THEN 1 ELSE 0 END) * 100.0) / COUNT(id),
        2
    ),"%") AS Successful_percent
FROM cte
GROUP BY Goal_Range
order by ROUND(
        (SUM(CASE WHEN state = 'successful' THEN 1 ELSE 0 END) * 100.0) / COUNT(id),
        2
              ) Desc;

/*-------------------------------------All KPIs---------------------------------------------*/