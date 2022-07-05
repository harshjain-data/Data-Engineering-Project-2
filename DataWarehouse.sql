create table dimDate
(
    date_key integer NOT NULL PRIMARY KEY,
    date date NOT NULL,
    year smallint NOT NULL,
    quarter smallint NOT NULL,
    month smallint NOT NULL,
    day smallint NOT NULL,
    week smallint NOT NULL,
    is_weekend boolean
);

create table dimStore
(
    store_key serial PRIMARY KEY,
    store_id smallint NOT NULL,
    address varchar(50) NOT NULL,
    address2 varchar(50),
    district varchar(20) NOT NULL,
    city varchar(50) NOT NULL,
    country varchar(50) NOT NULL,
    postal_code varchar(10),
    manager_first_name varchar(50) NOT NULL,
    manager_last_name varchar(50) NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL
);

create table dimCustomer
(
    customer_key serial PRIMARY KEY,
    customer_id smallint NOT NULL,
    first_name varchar(50) NOT NULL,
    last_name varchar(50) NOT NULL,
    email varchar(50),
    address varchar(50) NOT NULL,
    address2 varchar(50),
    district varchar(20) NOT NULL,
    city varchar(50) NOT NULL,
    country varchar(50) NOT NULL,
    postal_code varchar(10),
    phone varchar(20),
    active smallint,
    create_date date NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL
);

create table dimMovie
(
    movie_key serial PRIMARY KEY,
    film_id smallint NOT NULL,
    title varchar(255) NOT NULL,
    description text,
    release_year year,
    language varchar(20) NOT NULL,
    category varchar(25),
    length smallint NOT NULL,
    rating varchar(5) NOT NULL,
    special_features varchar(60) NOT NULL,
    rental_duration smallint NOT NULL
);


INSERT INTO dimDate (date_key, date, year, quarter, month, day, week, is_weekend)
SELECT
        DISTINCT (TO_CHAR(payment_date::DATE,'yyMMDD')::integer) as date_key,
        date(payment_date) as date,
        EXTRACT(year from payment_date) as year,
        EXTRACT(quarter from payment_date) as quarter,
        EXTRACT(month from payment_date) as month,
        EXTRACT(day from payment_date) as day,
        EXTRACT(week from payment_date) as week,
        CASE WHEN EXTRACT(ISODOW from payment_date) IN (6,7) THEN true ELSE false END as week
FROM payment;

INSERT INTO dimCustomer (customer_key, customer_id, first_name, last_name, email, address, 
                         address2, district, city, country, postal_code, phone, active, 
                         create_date, start_date, end_date)
SELECT
       c.customer_id as customer_key,
       c.customer_id, 
       c.first_name, 
       c.last_name, 
       c.email, 
       a.address, 
       a.address2, 
       a.district, 
       ci.city, 
       co.country, 
       a.postal_code, 
       a.phone,
       c.active,
       c.create_date, 
       now() as start_date, 
       now() as end_date
FROM customer c
JOIN address a ON (c.address_id=a.address_id)
JOIN city ci ON (a.city_id=ci.city_id)
JOIN country co ON (ci.country_id=co.country_id);




INSERT INTO dimStore (store_key, store_id, address, address2, district, city, country, 
                      postal_code, manager_first_name, manager_last_name, start_date, end_date)
SELECT
       s.store_id as store_key,
       s.store_id,  
       a.address, 
       a.address2, 
       a.district, 
       c.city, 
       co.country, 
       a.postal_code, 
       st.first_name as manager_first_name, 
       st.last_name as manager_last_name, 
       now() as start_date, 
       now() as end_date
FROM store s
JOIN staff st ON (s.manager_staff_id=st.staff_id)
JOIN address a ON (s.address_id=a.address_id)
JOIN city c ON (a.city_id=c.city_id)
JOIN country co ON (c.country_id=co.country_id);



INSERT INTO dimMovie (movie_key, film_id, title, description, release_year, 
                      language, category, length, rating, 
                      special_features, rental_duration)
SELECT
       f.film_id as movie_key,
       f.film_id,  
       f.title, 
       f.description, 
       f.release_year, 
       l.name as language,   
       c.name as category,
       f.length,  
       f.rating, 
       f.special_features,
       f.rental_duration
FROM film f
JOIN language l ON (f.language_id=l.language_id)
JOIN film_category fc ON (f.film_id=fc.film_id)
JOIN category c ON (fc.category_id=c.category_id);



CREATE TABLE factSales
    (
        sales_key SERIAL PRIMARY KEY,
        date_key INTEGER REFERENCES dimDate(date_key),
        customer_key INTEGER REFERENCES dimCustomer(customer_key),
        movie_key INTEGER REFERENCES dimMovie(movie_key),
        store_key INTEGER REFERENCES dimStore(store_key),
        sales_amount numeric
    );


INSERT INTO factSales (date_key, customer_key, movie_key, store_key, sales_amount)
SELECT
       TO_CHAR(payment_date :: DATE, 'yymmdd')::integer AS date_key,
       p.customer_id as customer_key,
       i.film_id as movie_key,
       i.store_id as store_key, 
       p.amount as sales_amount
FROM payment p
JOIN rental r ON (p.rental_id=r.rental_id)
JOIN inventory i ON (r.inventory_id=i.inventory_id);

--Analysis

--3NF

SELECT f.title, EXTRACT(month FROM p.payment_date) as month, ci.city, sum(p.amount) as revenue 
FROM payment p
JOIN rental r ON (p.rental_id=r.rental_id)
JOIN inventory i ON (r.inventory_id=i.inventory_id)
JOIN film f ON (i.film_id=f.film_id)
JOIN customer c ON (p.customer_id = c.customer_id)
JOIN address a ON (c.address_id=a.address_id)
JOIN city ci ON (a.city_id=ci.city_id)
GROUP BY (f.title, month, ci.city)
ORDER BY f.title, month, ci.city, revenue desc;

-- star schema (Data Warehouse)

SELECT dimMovie.title, dimDate.month, dimCustomer.city, sum(sales_amount) as revenue
FROM factSales
JOIN dimMovie on (dimMovie.movie_key = factSales.movie_key)
JOIN dimDate on (dimDate.date_key = factSales.date_key)
JOIN dimCustomer on (dimCustomer.customer_key = factSales.customer_key)
GROUP BY (dimMovie.title, dimDate.month, dimCustomer.city)
ORDER BY dimMovie.title, dimDate.month, dimCustomer.city, revenue desc;