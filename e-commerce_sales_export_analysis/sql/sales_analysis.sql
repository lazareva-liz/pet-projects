-- 1. Основные метрики за весь период
SELECT 
    COUNT(*) as total_orders,
    SUM(order_value_eur) as total_revenue,
    SUM(profit) as total_profit,
    ROUND(AVG(profit_margin)::NUMERIC, 2) as avg_margin,
    ROUND(AVG(order_value_eur)::NUMERIC, 2) as avg_order_value,
    ROUND((SUM(order_value_eur) / COUNT(DISTINCT customer_name))::NUMERIC, 2) as revenue_per_customer
FROM proj.sales;


-- 2. Метрики по годам (тренды)
SELECT 
    "year" ,
    COUNT(*) as orders_count,
    SUM(order_value_eur) as revenue,
    SUM(profit) as profit,
    ROUND(AVG(profit_margin)::NUMERIC, 2) as avg_margin,
    -- Процент увеличения прибыли год к году
    ROUND(((SUM(profit) - LAG(SUM(profit)) OVER (ORDER BY year)) / LAG(SUM(profit)) OVER (ORDER BY year))::NUMERIC * 100, 2) as profit_growth_pct
FROM proj.sales
GROUP BY "year" 
ORDER BY "year";

-- ГИПОТЕЗА 1: Португалия лидирует из-за нескольких крупных клиентов. 20% клиентов дают 80% выручки по стране?
-- Считаем метрики для клиентов из Португалии
WITH portugal_stats AS (
    SELECT 
        customer_name,
        SUM(order_value_eur) as total_spent,
        SUM(SUM(order_value_eur)) OVER () as country_total
    FROM proj.sales 
    WHERE country = 'Portugal'
    GROUP BY customer_name
)
SELECT 
	COUNT(*) as clients_count,
    -- Топ 20% клиентов по покупкам
    SUM(CASE WHEN total_spent >= (SELECT PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY total_spent) FROM portugal_stats)
          THEN 1 ELSE 0 END) as top_20_pct_clients,
    -- Доля выручки с топ 20% клиентов
    ROUND((SUM(CASE WHEN total_spent >= (SELECT PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY total_spent) FROM portugal_stats) 
          THEN total_spent ELSE 0 END) * 100.0 / MAX(country_total))::NUMERIC, 2) as revenue_share
FROM portugal_stats;


-- Детальный анализ распределения клиентов Португалии
WITH portugal_stats AS (
    SELECT 
        customer_name,
        SUM(order_value_eur) as total_spent,
        SUM(SUM(order_value_eur)) OVER () as country_total,
        COUNT(*) OVER () as total_clients
    FROM proj.sales 
    WHERE country = 'Portugal'
    GROUP BY customer_name
    ORDER BY total_spent DESC
),
cumulative_analysis AS (
    SELECT 
        customer_name,
        total_spent,
        country_total,
        total_clients,
        -- Накопительная сумма
        SUM(total_spent) OVER (ORDER BY total_spent DESC) as cumulative_revenue,
        -- Накопительный процент
        ROW_NUMBER() OVER (ORDER BY total_spent DESC) * 100.0 / total_clients as client_percentile
    FROM portugal_stats
)
SELECT 
    -- Сколько % клиентов дают 80% выручки?
    MIN(client_percentile) FILTER (WHERE cumulative_revenue >= country_total * 0.8) as clients_for_80_pct_revenue,
    -- Топ-10% клиентов дают сколько % выручки?
    ROUND((MAX(cumulative_revenue) FILTER (WHERE client_percentile <= 10) * 100.0 / MAX(country_total))::NUMERIC, 2) as top_10_pct_share,
    -- Средний чек по сегментам
    ROUND(AVG(total_spent) FILTER (WHERE client_percentile <= 20)::NUMERIC, 2) as avg_spent_top_20,
    ROUND(AVG(total_spent) FILTER (WHERE client_percentile > 20)::NUMERIC, 2) as avg_spent_bottom_80,
    -- Соотношение
    ROUND((AVG(total_spent) FILTER (WHERE client_percentile <= 20) / 
    AVG(total_spent) FILTER (WHERE client_percentile > 20))::NUMERIC, 2) as top_vs_bottom_ratio
FROM cumulative_analysis;

-- Сравнение распределения в Португалии с другими странами
WITH country_stats AS (
    SELECT 
        country,
        customer_name,
        SUM(order_value_eur) as client_revenue,
        COUNT(*) OVER (PARTITION BY country) as clients_in_country
    FROM proj.sales
    GROUP BY country, customer_name
),
top_clients_share AS (
    SELECT 
        country,
        clients_in_country,
        -- Доля топ-20% клиентов в выручке страны
        SUM(CASE WHEN client_rank <= CEIL(clients_in_country * 0.2) 
                 THEN client_revenue ELSE 0 END) * 100.0 / 
        SUM(client_revenue) as top_20_pct_share
    FROM (
        SELECT 
            *,
            ROW_NUMBER() OVER (PARTITION BY country ORDER BY client_revenue DESC) as client_rank
        FROM country_stats
    ) ranked
    GROUP BY country, clients_in_country
)
SELECT 
    country,
    clients_in_country,
    ROUND(top_20_pct_share::NUMERIC, 2) as top_20_percent_share_pct,
    CASE 
        WHEN top_20_pct_share > 70 THEN 'HIGH concentration (risky)'
        WHEN top_20_pct_share BETWEEN 50 AND 70 THEN 'MEDIUM concentration'
        WHEN top_20_pct_share < 50 THEN 'LOW concentration (healthy)'
    END as concentration_risk
FROM top_clients_share
WHERE clients_in_country >= 10  -- Только страны с достаточным количеством клиентов
ORDER BY top_20_pct_share DESC;

-- ГИПОТЕЗА 2: PC-канал доминирует, потому что там выше средний чек
SELECT 
    device_type,
    ROUND(AVG(order_value_eur)::NUMERIC, 2) as avg_order_value,
    ROUND(AVG(profit_margin)::NUMERIC, 2) as avg_margin,
    COUNT(*) as orders_count
FROM proj.sales
GROUP BY device_type
ORDER BY avg_order_value DESC;

-- Анализ по странам: на PC покупают в дорогих странах?
SELECT 
    device_type,
    country,
    COUNT(*) as orders_count,
    ROUND(AVG(order_value_eur):: NUMERIC, 2) as avg_order_value_country,
    -- Сравнение с общим средним по стране
    ROUND((AVG(order_value_eur) / AVG(AVG(order_value_eur)) OVER (PARTITION BY country))::NUMERIC , 2) as vs_total_country_avg
FROM proj.sales
GROUP BY device_type, country
HAVING COUNT(*) >= 5  -- Только значимые комбинации
ORDER BY avg_order_value_country DESC;

-- На PC покупают дорогие категории?
SELECT 
    device_type,
    category,
    ROUND(AVG(order_value_eur)::NUMERIC, 2) as avg_order_value,
    COUNT(*) as orders_count,
    SUM(order_value_eur) as total_revenue,
    -- Доля категории в устройстве
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY device_type), 2) as category_share_percent
FROM proj.sales
GROUP BY device_type, category
ORDER BY  avg_order_value DESC;


-- Гипотеза 3: Категория Clothing самая прибыльная, благодаря высокой частоте покупок, в то время как Smartphones показывает 
-- максимальную маржинальность при меньших объемах прибыли
WITH category_stats AS (
    SELECT 
        category,
        COUNT(*) as orders_count,        
        COUNT(DISTINCT customer_name) as unique_customers,
        SUM(order_value_EUR) as total_revenue,
        SUM(profit) as total_profit,
        ROUND(AVG(profit_margin)::NUMERIC, 2) as avg_margin,
        -- Частота покупок на клиента
        ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT customer_name), 2) as frequency_per_customer
    FROM proj.sales
    GROUP BY category
)
SELECT 
    category,
    total_profit,
    orders_count,
    avg_margin,
    frequency_per_customer,
    -- Рейтинг категорий по количеству заказов и маржинальности
    ROW_NUMBER() OVER (ORDER BY orders_count DESC) as orders_rank,
    ROW_NUMBER() OVER (ORDER BY avg_margin DESC) as margin_rank
FROM category_stats
ORDER BY total_profit DESC;


-- Сравнение 2019 vs 2020 
WITH monthly_stats AS (
    SELECT 
        year,
        month,
        COUNT(*) as total_orders,
        AVG(order_value_eur) as avg_value,
        SUM(order_value_eur) as monthly_revenue,
        COUNT(DISTINCT customer_name) as active_customers,
        -- Анализ по странам
        COUNT(DISTINCT country) as countries_active
    FROM proj.sales
    GROUP BY year, month
)
SELECT 
    m1.month,
    -- Насколько увеличилось количество клиентов в 2020 по сравнению с 2019(количество и %)
    m2.active_customers - m1.active_customers as cust_growth,
    ROUND((m2.active_customers - m1.active_customers) * 100.0 / m1.active_customers, 1) as cust_growth_pct,
    m2.monthly_revenue - m1.monthly_revenue as revenue_growth,
    ROUND(((m2.monthly_revenue - m1.monthly_revenue) * 100.0 / m1.monthly_revenue)::NUMERIC, 1) as revenue_growth_pct,
    m1.countries_active AS countries_19,
    m2.countries_active AS countries_20
FROM monthly_stats m1
LEFT JOIN monthly_stats m2 ON m1.month = m2.month AND m2.year = 2020
WHERE m1.year = 2019
ORDER BY month;


-- Анализ сезонности (высокая прибыль в июне в оба года)
SELECT 
	"month" ,
    category,
    -- 2019
    ROUND(SUM(CASE WHEN "year" = 2019 THEN profit END)::NUMERIC, 2) AS profit_2019,
    -- 2020
    ROUND(SUM(CASE WHEN "year" = 2020 THEN profit END)::NUMERIC, 2) AS profit_2020,
    -- Маржинальность 2019
    ROUND(AVG(CASE WHEN "year" = 2019 THEN profit_margin END)::NUMERIC, 2) AS margin_2019,
    -- Маржинальность 2020
    ROUND(AVG(CASE WHEN "year" = 2020 THEN profit_margin END)::NUMERIC, 2) AS margin_2020,
    -- Заказы 2019
    COUNT(CASE WHEN "year" = 2019 THEN 1 END) AS orders_2019,
    -- Заказы 2020
    COUNT(CASE WHEN "year" = 2020 THEN 1 END) AS orders_2020
FROM proj.sales
WHERE month = 6 
GROUP BY category, "month" 
ORDER BY category;


-- Анализ пикового месяца (декабрь 2019 - самая большая прибыль)
SELECT 
	category,
	ROUND(SUM(profit)::NUMERIC, 2) AS total_profit,
	ROUND(AVG(profit_margin)::NUMERIC, 2) AS avg_margin,
	COUNT(DISTINCT customer_name) AS costumers_count,
	COUNT(*) AS sales_count
FROM proj.sales 
WHERE "month" = 12 AND "year" = 2019
GROUP BY category
ORDER BY total_profit DESC;


-- Анализ наименее прибыльного месяца (февраль 2020 - резкий спад прибыли)
SELECT 
	category,
	ROUND(SUM(profit)::NUMERIC, 2) AS total_profit,
	ROUND(AVG(profit_margin)::NUMERIC, 2) AS avg_margin,
	COUNT(DISTINCT customer_name) AS costumers_count,
	COUNT(*) AS sales_count
FROM proj.sales 
WHERE "month" = 2 AND "year" = 2020
GROUP BY category
ORDER BY total_profit DESC;

-- Анализ упущенной выгоды по странам
-- Какие страны показывают низкую активность, но высокую маржинальность?
-- (Возможность для роста)
WITH country_performance AS (
    SELECT 
        country,
        COUNT(*) as order_count,
        AVG(profit_margin) as avg_margin,
        SUM(order_value_EUR) as total_revenue,
        -- Рейтинг по марже и объему
        ROW_NUMBER() OVER (ORDER BY AVG(profit_margin) DESC) as margin_rank,
        ROW_NUMBER() OVER (ORDER BY SUM(order_value_EUR) DESC) as revenue_rank
    FROM proj.sales
    GROUP BY country
)
SELECT 
    country,
    order_count,
    avg_margin,
    total_revenue,
    margin_rank,
    revenue_rank,
    -- Страны с высокой маржей, но низким объемом = потенциал роста
    CASE 
        WHEN margin_rank <= 5 AND revenue_rank > 5 THEN 'HIGH POTENTIAL'
        WHEN margin_rank <= 10 AND revenue_rank > 10 THEN 'MEDIUM POTENTIAL'
        ELSE 'SATURATED'
    END as growth_potential
FROM country_performance
ORDER BY avg_margin DESC;

-- Что покупают в странах с высоким потенциалом?
SELECT 
    country,
    category,
    COUNT(*) as orders,
    ROUND(AVG(profit_margin)::NUMERIC, 2) as avg_margin,
    ROUND(SUM(profit)::NUMERIC, 2) as total_profit
FROM proj.sales
WHERE country IN ('Austria', 'Denmark', 'Bulgaria', 'Luxembourg')
GROUP BY country, category
ORDER BY country, total_profit DESC;

-- Анализ эффективности менеджеров
-- Кто приносит наибольшую прибыль?
    SELECT 
        sales_manager,
        country,
        COUNT(DISTINCT customer_name) as unique_customers,
        SUM(order_value_eur) as total_revenue,
        SUM(profit) as total_profit,
        ROUND(AVG(profit_margin)::NUMERIC, 2) as avg_margin,
        -- Насколько сложные сделки делает менеджер?
        ROUND(AVG(order_value_eur)::NUMERIC, 2) as avg_deal_size,
        -- Как часто клиенты возвращаются к нему?
        ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT customer_name), 1) as deals_per_customer
    FROM proj.sales
    GROUP BY sales_manager, country
   ORDER BY total_profit desc   

