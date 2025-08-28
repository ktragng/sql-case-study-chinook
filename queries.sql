-- Q1: Top 10 customers by revenue (lifetime)
SELECT
  c.CustomerId,
  c.FirstName || ' ' || c.LastName AS CustomerName,
  c.Country,
  ROUND(SUM(i.Total), 2) AS TotalRevenue
FROM Customers c
JOIN Invoices i ON i.CustomerId = c.CustomerId
GROUP BY c.CustomerId
ORDER BY TotalRevenue DESC
LIMIT 10;

-- Q2: Revenue by artist (sum of line revenue)
SELECT
  ar.ArtistId,
  ar.Name AS Artist,
  ROUND(SUM(il.UnitPrice * il.Quantity), 2) AS Revenue
FROM InvoiceLines il
JOIN Tracks t   ON t.TrackId = il.TrackId
JOIN Albums al  ON al.AlbumId = t.AlbumId
JOIN Artists ar ON ar.ArtistId = al.ArtistId
GROUP BY ar.ArtistId
ORDER BY Revenue DESC
LIMIT 10;

-- Q3: Revenue by region (billing country)
SELECT
  i.BillingCountry AS Country,
  ROUND(SUM(i.Total), 2) AS Revenue
FROM Invoices i
GROUP BY i.BillingCountry
ORDER BY Revenue DESC;

-- Q4a: Monthly revenue trend (YYYY-MM)
SELECT
  strftime('%Y-%m', i.InvoiceDate) AS YearMonth,
  ROUND(SUM(i.Total), 2) AS Revenue
FROM Invoices i
GROUP BY YearMonth
ORDER BY YearMonth;

-- Q4b: Quarterly revenue trend (YYYY-Qn)
SELECT
  strftime('%Y', i.InvoiceDate) AS Year,
  ((CAST(strftime('%m', i.InvoiceDate) AS INTEGER) + 2) / 3) AS Quarter, -- 1..4
  ROUND(SUM(i.Total), 2) AS Revenue
FROM Invoices i
GROUP BY Year, Quarter
ORDER BY Year, Quarter;

-- Q5: Average order size per lifetime-spend segment
WITH lifetime AS (
  SELECT c.CustomerId, SUM(i.Total) AS LifetimeSpend
  FROM Customers c
  JOIN Invoices i ON i.CustomerId = c.CustomerId
  GROUP BY c.CustomerId
),
seg AS (
  SELECT
    CustomerId,
    LifetimeSpend,
    CASE
      WHEN LifetimeSpend >= 100 THEN 'High'
      WHEN LifetimeSpend >= 50  THEN 'Medium'
      ELSE 'Low'
    END AS Segment
  FROM lifetime
)
SELECT
  s.Segment,
  ROUND(AVG(i.Total), 2) AS AvgOrderValue,
  COUNT(DISTINCT i.InvoiceId) AS Orders
FROM seg s
JOIN Invoices i ON i.CustomerId = s.CustomerId
GROUP BY s.Segment
ORDER BY CASE s.Segment WHEN 'High' THEN 1 WHEN 'Medium' THEN 2 ELSE 3 END;

-- Q6: Customers with declining YoY revenue
WITH by_year AS (
  SELECT
    i.CustomerId,
    strftime('%Y', i.InvoiceDate) AS Year,
    SUM(i.Total) AS Revenue
  FROM Invoices i
  GROUP BY i.CustomerId, Year
),
with_prev AS (
  SELECT
    CustomerId,
    Year,
    Revenue,
    LAG(Revenue) OVER (
      PARTITION BY CustomerId
      ORDER BY Year
    ) AS PrevRevenue
  FROM by_year
),
latest_row AS (
  -- take each customer's latest year row
  SELECT wp.*
  FROM with_prev wp
  JOIN (
    SELECT CustomerId, MAX(Year) AS MaxYear
    FROM with_prev
    GROUP BY CustomerId
  ) m ON m.CustomerId = wp.CustomerId AND m.MaxYear = wp.Year
)
SELECT
  c.CustomerId,
  c.FirstName || ' ' || c.LastName AS CustomerName,
  latest_row.Year AS LatestYear,
  ROUND(latest_row.Revenue, 2) AS LatestRevenue,
  ROUND(latest_row.PrevRevenue, 2) AS PrevYearRevenue
FROM latest_row
JOIN Customers c ON c.CustomerId = latest_row.CustomerId
WHERE latest_row.PrevRevenue IS NOT NULL
  AND latest_row.Revenue < latest_row.PrevRevenue
ORDER BY (latest_row.PrevRevenue - latest_row.Revenue) DESC;


-- Q7: Revenue by Genre (proxy for profitability)
SELECT
  g.GenreId,
  g.Name AS Genre,
  ROUND(SUM(il.UnitPrice * il.Quantity), 2) AS Revenue
FROM InvoiceLines il
JOIN Tracks t  ON t.TrackId = il.TrackId
JOIN Genres g  ON g.GenreId = t.GenreId
GROUP BY g.GenreId
ORDER BY Revenue DESC;
