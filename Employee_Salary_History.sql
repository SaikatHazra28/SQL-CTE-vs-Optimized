-- Create employees table
CREATE TABLE employees (
    employee_id INT PRIMARY KEY,
    name VARCHAR(10) NOT NULL,
    join_date DATE NOT NULL,
    department VARCHAR(10) NOT NULL
);

-- Insert sample data
INSERT INTO employees (employee_id, name, join_date, department)
VALUES
    (1, 'Alice', '2018-06-15', 'IT'),
    (2, 'Bob', '2019-02-10', 'Finance'),
    (3, 'Charlie', '2017-09-20', 'HR'),
    (4, 'David', '2020-01-05', 'IT'),
    (5, 'Eve', '2016-07-30', 'Finance'),
    (6, 'Sumit', '2016-06-30', 'Finance');
 
-- Create salary_history table
CREATE TABLE salary_history (
    employee_id INT,
    change_date DATE NOT NULL,
    salary DECIMAL(10,2) NOT NULL,
    promotion VARCHAR(3)
);

-- Insert sample data
INSERT INTO salary_history (employee_id, change_date, salary, promotion)
VALUES
    (1, '2018-06-15', 50000, 'No'),
    (1, '2019-08-20', 55000, 'No'),
    (1, '2021-02-10', 70000, 'Yes'),
    (2, '2019-02-10', 48000, 'No'),
    (2, '2020-05-15', 52000, 'Yes'),
    (2, '2023-01-25', 68000, 'Yes'),
    (3, '2017-09-20', 60000, 'No'),
    (3, '2019-12-10', 65000, 'No'),
    (3, '2022-06-30', 72000, 'Yes'),
    (4, '2020-01-05', 45000, 'No'),
    (4, '2021-07-18', 49000, 'No'),
    (5, '2016-07-30', 55000, 'No'),
    (5, '2018-11-22', 62000, 'Yes'),
    (5, '2021-09-10', 75000, 'Yes'),
    (6, '2016-06-30', 55000, 'No'),
    (6, '2017-11-22', 50000, 'No'),
    (6, '2018-11-22', 40000, 'No'),
    (6, '2021-09-10', 75000, 'Yes');

select * from employees
select * from salary_history

select * from employees e
left join salary_history s
on e.employee_id=s.employee_id

/*
1.Find the letest salary for each employee.
2.Calculate the total numbers of promotions each employee has received.
3.Determine the maximum salary hike percentage between any two consecutive salary changes for each employee.
4.Identify employees whose salary has never decrerased over time.
5.Find the average time(in months) between salary changes for each employee.
6.Rank employees by their salary growth rate(from first to lasat recorded salary),breaking ties by earliest join date.
*/

--First Solve
with cte as
(select *,
       Rank() over (Partition by employee_id order by change_date desc) as rn_desc,
	   Rank() over (Partition by employee_id order by change_date asc) as rn_asc
from salary_history
),latest_salary_cte as (
select employee_id,salary as letest_salary
from cte
where rn_desc = 1
),
promotion_cte as(
select 
     employee_id,
	 count(*) as no_of_promotions 
from cte 
where promotion ='Yes'
group by employee_id
),
previous_salary_cte as(
select *,
 lead(salary,1) over(partition by employee_id order by change_date desc) as prev_salary,
 lead(change_date,1) over(partition by employee_id order by change_date desc) as prev_Change_Date
from cte
),Salary_Growth_cte as(
select employee_id,
       Max(cast((salary-prev_salary)*100.0/prev_salary as decimal(4,2)))as Salary_Growth
from previous_salary_cte
group by employee_id
),
salary_decreased_cte as(
select 
    distinct
	employee_id,
	'N' as never_decreased
from previous_salary_cte
where salary < prev_salary
),
avg_months_cte as (
select 
     employee_id,
	 avg(DATEDIFF(month,prev_Change_Date,change_date)) as avg_months_between_changes
from previous_salary_cte
group by employee_id
),salary_ratio_cte as (
select employee_id,
       Max(case when rn_desc = 1 then salary end)/ Max(case when rn_asc= 1 then salary end) as salary_growth_ratio
	  ,min(change_date) as join_Date
from cte
group by employee_id
)
,salary_growth_rank  as (
select *,
   rank() over(order by salary_growth_ratio desc,join_Date asc) as RankByGrowth
from salary_ratio_cte
)
select 
         e.employee_id,
		 e.name,
		 s.letest_salary,
		 isnull(p.no_of_promotions,0) as No_of_Promotions,
		 isnull(sd.never_decreased,'Y') as never_decreased,
		 am.avg_months_between_changes,
		 rbg.RankByGrowth
from employees e
left join latest_salary_cte s on e.employee_id=s.employee_id
left join promotion_cte p on e.employee_id = p.employee_id
left join Salary_Growth_cte msg on e.employee_id=msg.employee_id
left join salary_decreased_cte sd on e.employee_id = sd.employee_id
left join avg_months_cte am on e.employee_id = am.employee_id
left join salary_growth_rank rbg on e.employee_id = rbg.employee_id

--Second Solve
with cte as
(select *,
       Rank() over (Partition by employee_id order by change_date desc) as rn_desc,
	   Rank() over (Partition by employee_id order by change_date asc) as rn_asc,
	   lead(salary,1) over(partition by employee_id order by change_date desc) as prev_salary,
       lead(change_date,1) over(partition by employee_id order by change_date desc) as prev_Change_Date
from salary_history
)
,salary_ratio_cte as (
select employee_id,
       Max(case when rn_desc = 1 then salary end)/ Max(case when rn_asc= 1 then salary end) as salary_growth_ratio
	  ,min(change_date) as join_Date
from cte
group by employee_id
)
,salary_growth_rank  as (
select *,
   rank() over(order by salary_growth_ratio desc,join_Date asc) as RankByGrowth
from salary_ratio_cte
)
select cte.employee_id,
	 max(case when rn_desc=1 then salary end) as letest_salary,
	 sum(case when promotion ='Yes' then 1 else 0 end) as No_of_Promotion,
	 Max(cast((salary-prev_salary)*100.0/prev_salary as decimal(4,2)))as Max_Salary_Growth,
	 case when max(case when salary < prev_salary then 1 else 0 end)=0 then 'Y' else 'N' end as Never_Decreased,
	 avg(DATEDIFF(month,prev_Change_Date,change_date)) as avg_months_between_changes,
	 rank() over(order by sr.salary_growth_ratio desc,sr.join_Date asc) as RankByGrowth
from cte 
left join salary_ratio_cte sr on cte.employee_id=sr.employee_id
group by cte.employee_id,sr.salary_growth_ratio,sr.join_Date
order by cte.employee_id