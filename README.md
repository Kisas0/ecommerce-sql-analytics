# E-commerce customer analytics

Портфолио-проект для роли SQL / Data Analyst. Компания продаёт товары для дома онлайн и хочет понять, как растут продажи, кто возвращается за повторной покупкой и какие клиенты наиболее ценны.

## Бизнес-вопросы

- Как меняются выручка, число заказов и средний чек от месяца к месяцу?
- Какая доля клиентов возвращается и как выглядит retention по когортам?
- Какие сегменты клиентов требуют разных коммуникаций по RFM-модели?
- Какие категории приносят больше всего чистой выручки с учётом возвратов?

## Стек

`PostgreSQL 16` · `Python 3.11+` · `pandas` · `SQLAlchemy` · `psycopg`

## Структура

```text
ecommerce_analytics/
├── schema.sql              # Нормализованная модель и индексы
├── analytics.sql           # 8 аналитических SQL-запросов
├── docker-compose.yml      # Локальный PostgreSQL
├── requirements.txt
└── src/
    ├── generate_data.py    # Детерминированные CSV за 2023–2025
    └── load_to_postgres.py # Очистка pandas и загрузка в PostgreSQL
```

## Быстрый запуск (PowerShell)

```powershell
docker compose up -d
py -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python src/generate_data.py
$env:DATABASE_URL = 'postgresql+psycopg://portfolio:portfolio@localhost:5434/ecommerce'
psql -h localhost -p 5434 -U portfolio -d ecommerce -f schema.sql
python src/load_to_postgres.py
psql -h localhost -p 5434 -U portfolio -d ecommerce -f analytics.sql
```

Пароль PostgreSQL: `portfolio`. Если `psql` не установлен, откройте `analytics.sql` в DBeaver и выполните его после загрузки данных.

## Ключевые результаты

- Рассчитана помесячная выручка и динамика MoM.
- Выполнен когортный анализ удержания клиентов.
- Проведена RFM-сегментация покупателей.
- Учтены возвраты при расчёте чистой выручки.
- Использованы оконные функции и CTE.

## SQL Skills

`CTE` `Window Functions` `LAG()` `DATE_TRUNC()` `FILTER`
`CASE` `GROUP BY` `JOIN` `SUM` `COUNT` `AVG`

## Project Output

The project generates analytical reports including:

- Monthly revenue trends
- Revenue by product category
- Customer cohort retention analysis

![SQL Query Results](photo_5391333517821681258_w.jpg)
