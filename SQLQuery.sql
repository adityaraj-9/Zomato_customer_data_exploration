create database zomato;
use zomato;

drop table if exists users
create table users(
user_id int primary key,
signup_date date
);

insert into users values
(1, '2014-09-02'),
(2, '2015-01-15'),
(3, '2014-04-11');


drop table if exists products
create table products(
product_id int primary key,
product_name varchar(25),
price int
);

insert into products values
(1, 'p1', 980),
(2, 'p2', 870),
(3, 'p3', 330);


drop table if exists goldusers_signup
create table goldusers_signup(
user_id int foreign key references users(user_id),
gold_signup_date date
);

insert into goldusers_signup values
(1, '2017-09-22'),
(3, '2017-04-21');


drop table if exists sales
create table sales(
user_id int foreign key references users(user_id),
created_at date,
product_id int foreign key references products(product_id)
);

insert into sales values
(1, '2017-04-19', 2),
(3, '2019-12-18', 1),
(2, '2020-07-20', 3),
(1, '2019-10-23', 2),
(1, '2018-03-19', 3),
(3, '2016-12-20', 2),
(1, '2016-11-09', 1),
(1, '2016-05-20', 3),
(2, '2017-09-24', 1),
(1, '2017-03-11', 2),
(1, '2016-03-11', 1),
(3, '2016-11-10', 1),
(3, '2017-12-07', 2),
(3, '2016-12-15', 2),
(2, '2017-11-08', 2),
(2, '2018-09-10', 3);


select * from users;
select * from products;
select * from goldusers_signup;
select * from sales;

--1. What is the total amount each customer spent on Zomato?

select s.user_id, sum(price) as amount_spent
from products as p
inner join sales as s
on p.product_id = s.product_id
group by s.user_id;



--2. How many days has each customer visited Zomato?

select user_id, count(distinct created_at) as days_visited
from sales
group by user_id;


--3. What was the first product purchased by each customer?

select s.user_id, p.product_name
from (select *, DENSE_RANK() over(partition by user_id order by created_at) as drank
from sales) as s
inner join products as p
on s.product_id = p.product_id and s.drank = 1;


--4. What is the most purchased item in the menu and how many times it was purchased by each customers?

select user_id, product_id, count(product_id) number_purchased
from sales
where product_id = (select top 1 product_id
					from sales
					group by product_id
					order by count(product_id) desc)
group by user_id, product_id;


--5. Which item was the most popular for each customer?

select user_id, product_id
from(
select *, DENSE_RANK() over (partition by user_id order by prod_count desc) as drank
from (select user_id, product_id, COUNT(product_id) as prod_count
from sales
group by user_id, product_id) as sub1) as sub2
where drank = 1;


--6. Which item was purchased first by the customer after they became a member?

select user_id, product_name
from(
select s.user_id, s.product_id, s.created_at, p.product_name, DENSE_RANK() over(partition by s.user_id order by s.created_at) drank
from goldusers_signup as g
inner join sales as s
on g.user_id = s.user_id and g.gold_signup_date < s.created_at
inner join products as p
on s.product_id = p.product_id) as sub
where drank = 1;


--7. Which item was purchased just before the customer became a member?

select user_id, product_name
from(
select s.user_id, s.product_id, s.created_at, p.product_name, DENSE_RANK() over(partition by s.user_id order by s.created_at desc) drank
from goldusers_signup as g
inner join sales as s
on g.user_id = s.user_id and g.gold_signup_date > s.created_at
inner join products as p
on s.product_id = p.product_id) as sub
where drank = 1;


--8. What is the total order and amount spent for each member before they became a member?

select s.user_id, count(s.product_id) order_count, sum(p.price) total_amount
from goldusers_signup as g
inner join sales as s
on g.user_id = s.user_id and g.gold_signup_date > s.created_at
inner join products as p
on s.product_id = p.product_id
group by s.user_id;


--9. A customer gets certain cashback in their zomato wallet for their purchase points(5rs = 2 Zomato points).
--   Each product have different purchasing points (p1 : 5rs = 1 zomato point, p2 : 10rs = 5 zomato point, p3 : 5rs = 1 zomato point)
--   a. Calculate the points collected by each customer and 
--   b. For which product most point have been given till now?

--a>
select user_id, concat('Rs.',sum(points) * 2.5) as total_chashback_earned
from (
select user_id, product_id, case when product_id = 1 then total_amount/5
					when product_id = 2 then total_amount/2
					else total_amount/5 end as points
from(
select s.user_id, s.product_id, sum(price) as total_amount
from sales as s
inner join products as p
on s.product_id = p.product_id
group by s.user_id, s.product_id) as sub1) as sub2
group by user_id;

--b>
select top 1 product_id, sum(points) total_points_given
from (
select user_id, product_id, case when product_id = 1 then total_amount/5
					when product_id = 2 then total_amount/2
					else total_amount/5 end as points
from(
select s.user_id, s.product_id, sum(price) as total_amount
from sales as s
inner join products as p
on s.product_id = p.product_id
group by s.user_id, s.product_id) as sub1) as sub2
group by product_id
order by sum(points) desc;


--10. In one year after the customer joins the gold program(including the join date) irrespective of what customer has purchased they earn 5 zomato
--    points for every Rs10 they spent(Rs10 = 5 zomato points). Who earned more points between customer 1 and 3 and how many points they earned?

select user_id, sum(points_earned) as total_points_earned
from(
select s.user_id, s.product_id, p.price/2 as points_earned
from sales as s
inner join goldusers_signup as g
on s.user_id = g.user_id and s.created_at between g.gold_signup_date and DATEADD(year, 1, gold_signup_date)
inner join products as p
on s.product_id = p.product_id) sub
group by user_id
order by sum(points_earned) desc;

--efficient query is possible than this one
/*select user_id, sum(points_earned) as total_points_earned
from(
select s.user_id, s.product_id, p.price/2 as points_earned
from sales as s
inner join (select user_id, gold_signup_date, DATEADD(year, 1, gold_signup_date) as date_limit
from goldusers_signup) as sub1
on s.user_id = sub1.user_id and s.created_at between sub1.gold_signup_date and sub1.date_limit
inner join products as p
on s.product_id = p.product_id) sub2
group by user_id
order by sum(points_earned) desc;*/

-- i did not considered 1 year constraint
/*select user_id, sum(points) as total_points_earned
from(
select s.user_id, s.product_id, p.price, p.price/2 as points
from sales as s
inner join goldusers_signup as g
on s.user_id = g.user_id and s.created_at >= g.gold_signup_date
inner join products as p
on s.product_id = p.product_id) as sub
group by user_id
order by sum(points) desc;*/


--11. Rank all the transaction of the customer based on purchase date for each customer

select *, rank() over(partition by user_id order by created_at) as rnk
from sales;


--12. Rank all the transactions for each member whenever they are a zomato gold member and for every non-gold member mark transaction as N/A.

select user_id, created_at, case when rnk = '0' then 'N/A' else rnk end as ranking
from(
select s.user_id, s.created_at, cast(case when g.gold_signup_date is Null then 0 else rank() 
over(partition by s.user_id order by s.created_at desc) end as varchar(5)) as rnk
from sales as s
left join goldusers_signup as g
on s.user_id = g.user_id and s.created_at >= g.gold_signup_date) as sub;

