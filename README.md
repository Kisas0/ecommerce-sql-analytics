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

## Что сказать на собеседовании

> Я спроектировал модель заказов интернет-магазина, построил воспроизводимый pipeline загрузки CSV в PostgreSQL и подготовил SQL-анализ: MoM-метрики, когорты retention, RFM-сегментацию и чистую выручку с учётом возвратов. Для расчётов использовал CTE, `FILTER`, `DATE_TRUNC`, `NTILE`, `LAG` и оконные агрегаты.

## Идеи для следующей итерации

- Собрать результаты запросов в Power BI / Metabase.
- Перенести генерацию и загрузку в Airflow или GitHub Actions.
- Добавить dbt-модель `fct_orders` и тесты уникальности ключей.
