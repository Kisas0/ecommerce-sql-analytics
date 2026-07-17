-- 1. Месячные ключевые метрики и изменение выручки к прошлому месяцу.
WITH monthly_sales AS (
    SELECT
        date_trunc('month', o.ordered_at)::date AS month,
        COUNT(DISTINCT o.order_id) AS completed_orders,
        COUNT(DISTINCT o.customer_id) AS buyers,
        ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2) AS gross_revenue
    FROM orders o
    JOIN order_items oi USING (order_id)
    WHERE o.status = 'completed'
    GROUP BY 1
)
SELECT
    month, completed_orders, buyers, gross_revenue,
    ROUND(gross_revenue / completed_orders, 2) AS avg_order_value,
    ROUND(100.0 * (gross_revenue / LAG(gross_revenue) OVER (ORDER BY month) - 1), 1) AS revenue_mom_pct
FROM monthly_sales
ORDER BY month;

-- 2. Чистая выручка и валовая маржа по категориям с учётом возвратов.
WITH item_sales AS (
    SELECT
        p.category,
        oi.order_item_id,
        oi.quantity * oi.unit_price * (1 - oi.discount_pct) AS gross_revenue,
        oi.quantity * p.unit_cost AS cost
    FROM order_items oi
    JOIN orders o USING (order_id)
    JOIN products p USING (product_id)
    WHERE o.status = 'completed'
), item_returns AS (
    SELECT order_item_id, SUM(refunded_amount) AS refunded_amount
    FROM returns
    GROUP BY 1
)
SELECT
    category,
    ROUND(SUM(gross_revenue), 2) AS gross_revenue,
    ROUND(SUM(COALESCE(refunded_amount, 0)), 2) AS refunds,
    ROUND(SUM(gross_revenue - COALESCE(refunded_amount, 0)), 2) AS net_revenue,
    ROUND(SUM(gross_revenue - COALESCE(refunded_amount, 0) - cost), 2) AS gross_profit,
    ROUND(100.0 * SUM(gross_revenue - COALESCE(refunded_amount, 0) - cost)
        / NULLIF(SUM(gross_revenue - COALESCE(refunded_amount, 0)), 0), 1) AS margin_pct
FROM item_sales
LEFT JOIN item_returns USING (order_item_id)
GROUP BY 1
ORDER BY net_revenue DESC;

-- 3. Retention: доля клиентов, вернувшихся по месяцам после первой покупки.
WITH first_purchase AS (
    SELECT customer_id, date_trunc('month', MIN(ordered_at))::date AS cohort_month
    FROM orders
    WHERE status = 'completed'
    GROUP BY 1
), activity AS (
    SELECT DISTINCT
        fp.cohort_month,
        o.customer_id,
        (EXTRACT(YEAR FROM age(date_trunc('month', o.ordered_at), fp.cohort_month)) * 12
         + EXTRACT(MONTH FROM age(date_trunc('month', o.ordered_at), fp.cohort_month)))::int AS month_number
    FROM first_purchase fp
    JOIN orders o ON o.customer_id = fp.customer_id AND o.status = 'completed'
), cohort_size AS (
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS customers
    FROM activity
    WHERE month_number = 0
    GROUP BY 1
)
SELECT
    a.cohort_month, a.month_number,
    COUNT(DISTINCT a.customer_id) AS active_customers,
    cs.customers AS cohort_customers,
    ROUND(100.0 * COUNT(DISTINCT a.customer_id) / cs.customers, 1) AS retention_pct
FROM activity a
JOIN cohort_size cs USING (cohort_month)
WHERE a.month_number BETWEEN 0 AND 6
GROUP BY 1, 2, 4
ORDER BY 1, 2;

-- 4. RFM-сегментация на основе завершённых заказов.
WITH customer_rfm AS (
    SELECT
        customer_id,
        (CURRENT_DATE - MAX(ordered_at::date)) AS recency_days,
        COUNT(DISTINCT order_id) AS frequency,
        SUM(item_revenue) AS monetary
    FROM (
        SELECT o.customer_id, o.order_id, o.ordered_at,
               SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) AS item_revenue
        FROM orders o
        JOIN order_items oi USING (order_id)
        WHERE o.status = 'completed'
        GROUP BY 1, 2, 3
    ) order_totals
    GROUP BY 1
), scored AS (
    SELECT *,
        6 - NTILE(5) OVER (ORDER BY recency_days) AS r_score,
        NTILE(5) OVER (ORDER BY frequency) AS f_score,
        NTILE(5) OVER (ORDER BY monetary) AS m_score
    FROM customer_rfm
)
SELECT
    CASE
        WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal customers'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'New customers'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At risk'
        ELSE 'Needs attention'
    END AS segment,
    COUNT(*) AS customers,
    ROUND(AVG(monetary), 2) AS avg_customer_revenue,
    ROUND(AVG(recency_days), 0) AS avg_recency_days
FROM scored
GROUP BY 1
ORDER BY customers DESC;

-- 5. Топ товаров с максимальной долей возвратов (минимум 30 проданных единиц).
WITH sales AS (
    SELECT p.product_name, SUM(oi.quantity) AS sold_units,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) AS sold_amount
    FROM order_items oi
    JOIN orders o USING (order_id)
    JOIN products p USING (product_id)
    WHERE o.status = 'completed'
    GROUP BY 1
), returned AS (
    SELECT p.product_name, COUNT(*) AS returned_lines, SUM(r.refunded_amount) AS refunded_amount
    FROM returns r
    JOIN order_items oi USING (order_item_id)
    JOIN products p USING (product_id)
    GROUP BY 1
)
SELECT s.product_name, s.sold_units, COALESCE(r.returned_lines, 0) AS returned_lines,
       ROUND(100.0 * COALESCE(r.returned_lines, 0) / s.sold_units, 2) AS return_rate_pct,
       ROUND(COALESCE(r.refunded_amount, 0), 2) AS refunded_amount
FROM sales s
LEFT JOIN returned r USING (product_name)
WHERE s.sold_units >= 30
ORDER BY return_rate_pct DESC, refunded_amount DESC
LIMIT 10;

-- 6. Конверсия в оплату и отмены по каналу привлечения.
SELECT
    c.acquisition_channel,
    COUNT(*) AS created_orders,
    COUNT(*) FILTER (WHERE o.status = 'completed') AS completed_orders,
    ROUND(100.0 * COUNT(*) FILTER (WHERE o.status = 'completed') / COUNT(*), 1) AS completion_rate_pct,
    ROUND(AVG(p.amount) FILTER (WHERE o.status = 'completed'), 2) AS avg_paid_amount
FROM orders o
JOIN customers c USING (customer_id)
LEFT JOIN payments p USING (order_id)
GROUP BY 1
ORDER BY completion_rate_pct DESC;

-- 7. Покупатели, которые перестали заказывать: 90+ дней без покупки.
SELECT
    c.customer_id, c.city, c.acquisition_channel,
    MAX(o.ordered_at)::date AS last_order_date,
    CURRENT_DATE - MAX(o.ordered_at::date) AS days_since_last_order,
    COUNT(*) AS completed_orders
FROM customers c
JOIN orders o USING (customer_id)
WHERE o.status = 'completed'
GROUP BY 1, 2, 3
HAVING CURRENT_DATE - MAX(o.ordered_at::date) >= 90
ORDER BY completed_orders DESC, days_since_last_order DESC
LIMIT 50;

-- 8. Вклад новых и повторных покупателей в месячную выручку.
WITH first_orders AS (
    SELECT customer_id, MIN(ordered_at)::date AS first_order_date
    FROM orders
    WHERE status = 'completed'
    GROUP BY 1
)
SELECT
    date_trunc('month', o.ordered_at)::date AS month,
    CASE WHEN date_trunc('month', fo.first_order_date) = date_trunc('month', o.ordered_at)
         THEN 'new' ELSE 'returning' END AS buyer_type,
    COUNT(DISTINCT o.customer_id) AS buyers,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2) AS revenue
FROM orders o
JOIN first_orders fo USING (customer_id)
JOIN order_items oi USING (order_id)
WHERE o.status = 'completed'
GROUP BY 1, 2
ORDER BY 1, 2;
