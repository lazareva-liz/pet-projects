# E-commerce Sales Export Analysis
![Python](https://img.shields.io/badge/Python-3.9+-3776AB?logo=python&logoColor=white)
![Pandas](https://img.shields.io/badge/Pandas-1.5+-150458?logo=pandas&logoColor=white)
![Jupyter](https://img.shields.io/badge/Jupyter-F37626?logo=jupyter&logoColor=white)
![DataLens](https://img.shields.io/badge/DataLens-FF0000?logo=yandex&logoColor=white)
## Комплексный анализ экспортных продаж (2019-2020)

### Проблематика:
**Цели исследования:**
- Выявить ключевые драйверы прибыли

- Оценить риски концентрации клиентов по странам

- Проанализировать эффективность каналов продаж

- Сегментировать клиентов и товары для стратегии роста

- Сформулировать data-driven рекомендации

**Ключевые вопросы:**
- Какая страна лидирует по объему продаж? Это устойчивое преимущество или риск?

- С каких устройств чаще совершают заказы? Почему?

- Какие категории товаров наиболее прибыльны и высокомаржинальны?

- Как пандемия повлияла на структуру продаж?


*Проведен комплексный анализ 1000 заказов из 15 стран за 2 года.*

---

## Исходные данные
**Структура данных**
Исходный датасет: 1000 записей × 10 полей

`country` -	Страна-импортер

`order_value_eur` - Сумма заказа в евро

`cost`	-	Себестоимость заказа

`date`	-	Дата заказа

`category` -	Категория товара

`customer_name` -	Название клиента

`sales_manager`	-	Менеджер продаж

`sales_rep`	-	Торговый представитель

`device_type`	-	Устройство (PC/Mobile/Tablet)

`order_id`	-	Уникальный ID заказа

**Созданные признаки:**

`profit` = `order_value_eur - cost` - Выручка в евро

`profit_margin` = `(profit / order_value_eur) × 100` - Маржинальность, %

`year`, `month` — Год, месяц (для временного анализа)

---
