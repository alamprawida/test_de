-- CREATE TABLE IF NOT EXISTS warehouse (
--     itemid INT,
--     category VARCHAR(50),
--     date DATE,
--     price INT,
--     sold INT,
--     stock INT,
--     priority VARCHAR(20)
-- );



-- INSERT INTO warehouse (itemid, category, date, price, sold, stock, priority) VALUES
-- (23, NULL, '2021-08-01', 5000, 5, 95, 'High'),
-- (23, 'medior', '2021-08-02', 5000, 6, 94, NULL),
-- (23, 'medior', '2021-08-03', NULL, NULL, NULL, 'High'),
-- (55, 'lower', '2021-09-10', NULL, 12, 88, 'High'),
-- (55, 'lower', '2021-09-11', 1000, 22, 78, 'High'),
-- (55, NULL, '2021-09-12', 1000, NULL, NULL, 'High'),
-- (10, 'upper', '2021-08-15', NULL, 32, 68, 'Low'),
-- (10, 'upper', '2021-08-16', 3000, 32, 68, NULL);



WITH FilledData AS (
    SELECT 
        Itemid,
        COALESCE(
            category, 
            MAX(category) OVER(PARTITION BY Itemid),
            MIN(category) OVER(PARTITION BY Itemid)
        ) AS filled_category,
        date,
        COALESCE(
            price, 
            MAX(price) OVER(PARTITION BY Itemid),
            MIN(price) OVER(PARTITION BY Itemid)
        ) AS filled_price,
        COALESCE(
            sold,
            LAG(sold) OVER(PARTITION BY Itemid ORDER BY date)
        ) AS filled_sold,
        COALESCE(
            stock,
            LAG(stock) OVER(PARTITION BY Itemid ORDER BY date)
        ) AS filled_stock,
        COALESCE(
            priority, 
            MAX(priority) OVER(PARTITION BY Itemid),
            MIN(priority) OVER(PARTITION BY Itemid)
        ) AS filled_priority
    FROM warehouse
)
SELECT 
    Itemid,
    filled_category AS category,
    date,
    filled_price AS price,
    filled_sold AS sold,
    filled_stock AS stock,
    filled_priority AS priority
FROM FilledData
ORDER BY Itemid, date;