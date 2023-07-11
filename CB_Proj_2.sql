USE gdb023;
SELECT * FROM gdb023.dim_customer;
SELECT * FROM gdb023.dim_product;
SELECT * FROM gdb023.fact_gross_price;
SELECT * FROM gdb023.fact_manufacturing_cost;
SELECT * FROM gdb023.fact_pre_invoice_deductions;
SELECT * FROM gdb023.fact_sales_monthly;


#################################################

#Provide the list of markets in which customer "Atliq Exclusive" operates its
#business in the APAC region.

select distinct(market), customer, region
from dim_customer
where customer = "Atliq Exclusive" and region = "APAC";

################################################

#What is the percentage of unique product increase in 2021 vs. 2020? The
#final output contains these fields,
#unique_products_2020
#unique_products_2021
#percentage_chg

with UP1 as(
select count(distinct product_code) as unique_products_2020
from fact_sales_monthly 
where fiscal_year = 2020
),
UP2 as (
select count(distinct product_code) as unique_products_2021
from fact_sales_monthly 
where fiscal_year = 2021
)

select *,  (unique_products_2021 - unique_products_2020)/unique_products_2020 *100 as percentage_chg
from UP1 
join up2;

###################################################
#Provide a report with all the unique product counts for each segment and
#sort them in descending order of product counts. The final output contains 2 fields,
#segment
#product_count

select segment, count(distinct product) as unique_products
from dim_product
group by segment
order by unique_products desc;


######################################################
#Follow-up: Which segment had the most increase in unique products in
#2021 vs 2020? The final output contains these fields,
#segment
#product_count_2020
#product_count_2021
#difference


with up1 as (
select segment, count(distinct product) as unique_products_2020
from dim_product p join fact_sales_monthly s on
p.product_code = s.product_code
where fiscal_year = 2020
group by segment
),
up2 as (
select segment, count(distinct product) as unique_products_2021
from dim_product p join fact_sales_monthly s on
p.product_code = s.product_code
where fiscal_year = 2021
group by segment
)
select up1.*, up2.unique_products_2021,
unique_products_2021 - unique_products_2020 as difference_cnt,
round((unique_products_2021 - unique_products_2020)/unique_products_2020*100, 2) as difference_pct
from up1 
join up2 on up1.segment = up2.segment
order by difference_cnt desc;

#########################################################
#Get the products that have the highest and lowest manufacturing costs.
#The final output should contain these fields,
#product_code
#product
#manufacturing_cost

select p.product_code,
		p.product,
        m.manufacturing_cost
from dim_product p
join fact_manufacturing_cost m on
p.product_code = m.product_code
where manufacturing_cost in ( select max(manufacturing_cost) from fact_manufacturing_cost
	UNION
    select min(manufacturing_cost) from fact_manufacturing_cost)
order by manufacturing_cost desc;

###############################################
#Generate a report which contains the top 5 customers who received an
#average high pre_invoice_discount_pct for the fiscal year 2021 and in the
#Indian market. The final output contains these fields,
#customer_code
#customer
#average_discount_percentage

select d.customer_code, 
		c.customer,
    round(avg(d.pre_invoice_discount_pct),4) as average_discount_pct
from dim_customer c 
join fact_pre_invoice_deductions d on
c.customer_code = d.customer_code
where fiscal_year = 2021 and market = "India"
group by c.customer_code
order by average_discount_pct desc
limit 5

## alternate way ##
WITH TBL1 AS
(SELECT customer_code AS A, AVG(pre_invoice_discount_pct) AS B FROM fact_pre_invoice_deductions
WHERE fiscal_year = '2021'
GROUP BY customer_code),
     TBL2 AS
(SELECT customer_code AS C, customer AS D FROM dim_customer
WHERE market = 'India')

SELECT TBL2.C AS customer_code, TBL2.D AS customer, ROUND (TBL1.B, 4) AS average_discount_percentage
FROM TBL1 JOIN TBL2
ON TBL1.A = TBL2.C
ORDER BY average_discount_percentage DESC
LIMIT 5 

##################################################
/*Get the complete report of the Gross sales amount for the customer “Atliq
Exclusive” for each month. This analysis helps to get an idea of low and
high-performing months and take strategic decisions.
The final report contains these columns:
Month
Year
Gross sales Amount8*/

select	
	concat(monthname(s.date), ' (', Year(s.date), ')') as 'Month',
    s.fiscal_year,
    round(sum(g.gross_price* s.sold_quantity),2) as Gross_sales_amount
from fact_gross_price g 
join fact_sales_monthly s 
	using (product_code)
join dim_customer c 
using (customer_code)
#FROM fact_sales_monthly s JOIN dim_customer C ON s.customer_code = C.customer_code
#						   JOIN fact_gross_price G ON s.product_code = G.product_code
where c.customer = "Atliq Exclusive"
group by Month, s.fiscal_year
order by  s.fiscal_year

######################################################
/*In which quarter of 2020, got the maximum total_sold_quantity? The final
output contains these fields sorted by the total_sold_quantity,
Quarter
total_sold_quantity*/

#for calender year quarter

SELECT
    concat("Q", QUARTER(date)) AS 2020_quarter,
    sum(sold_quantity) as total_sold_quantity
FROM
    fact_sales_monthly
where Year(date) = 2020
group by 2020_quarter
order by total_sold_quantity  desc


#for fiscal_year quarter

SELECT 
CASE
    WHEN date BETWEEN '2019-09-01' AND '2019-11-30' then 1  
    WHEN date BETWEEN '2019-12-01' AND '2020-02-29' then 2
    WHEN date BETWEEN '2020-03-01' AND '2020-05-31' then 3
    WHEN date BETWEEN '2020-06-01' AND '2020-08-31' then 4
    END AS Quarters,
    SUM(sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly
WHERE fiscal_year = 2020
GROUP BY Quarters
ORDER BY total_sold_quantity DESC

################################################
/*Which channel helped to bring more gross sales in the fiscal year 2021
and the percentage of contribution? The final output contains these fields,
channel
gross_sales_mln
percentage*/

with cte1 as (
select
	c.channel,
    round(sum(g.gross_price * s.sold_quantity)/1000000,2) as gross_sales_mln
from fact_sales_monthly s
join dim_customer c using (customer_code)
join fact_gross_price g using (product_code)
where s.fiscal_year = 2021
group by c.channel
)
select 
*, concat(round((gross_sales_mln*100/total),2), " %") as percentage
from 
(
(select sum(gross_sales_mln) as total from cte1) a,
(SELECT * FROM cte1) b
)
order by percentage desc

########################################################
/*Get the Top 3 products in each division that have a high
total_sold_quantity in the fiscal_year 2021? The final output contains these
fields,
division
product_code
product
total_sold_quantity
rank_order*/

with cte1 as (
select
p.division, 
p.product_code,
p.product,
sum(sold_quantity)  as total_sold,
rank() OVER (PARTITION BY p.division ORDER BY SUM(sold_quantity) DESC) AS rnk
from fact_sales_monthly s
join dim_product p on
p.product_code = s.product_code
where fiscal_year = 2021 
group by p.division, p.product_code, p.product
)
select division,
	product_code,
    total_sold,
    product,
    rnk
from cte1 
where rnk <= 3






