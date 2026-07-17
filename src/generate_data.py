"""Generate deterministic, realistic-looking e-commerce CSV files for the project."""

from __future__ import annotations

import csv
import random
from datetime import datetime, timedelta, timezone
from pathlib import Path


RNG = random.Random(42)
DATA_DIR = Path(__file__).resolve().parents[1] / "data"
START = datetime(2023, 1, 1, tzinfo=timezone.utc)
END = datetime(2025, 12, 31, 23, 59, tzinfo=timezone.utc)

CITIES = ["Moscow", "Saint Petersburg", "Kazan", "Yekaterinburg", "Novosibirsk", "Krasnodar"]
CHANNELS = ["organic", "paid_search", "social", "email", "referral"]
CATEGORIES = {
    "Kitchen": ("Pan", "Kettle", "Knife set", "Storage box"),
    "Textile": ("Blanket", "Pillow", "Towel set", "Bed sheet"),
    "Lighting": ("Floor lamp", "Desk lamp", "Pendant light", "Night light"),
    "Decor": ("Mirror", "Vase", "Wall art", "Candle holder"),
    "Storage": ("Shelf", "Basket", "Organizer", "Hanger"),
}


def iso(value: datetime) -> str:
    return value.isoformat()


def random_datetime(start: datetime, end: datetime) -> datetime:
    return start + (end - start) * RNG.random()


def write_csv(name: str, fieldnames: list[str], rows: list[dict]) -> None:
    with (DATA_DIR / name).open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    DATA_DIR.mkdir(exist_ok=True)

    customers = []
    for number in range(1, 1801):
        registered_at = random_datetime(START - timedelta(days=365), END - timedelta(days=15))
        customers.append(
            {
                "customer_id": f"C{number:05d}",
                "registered_at": iso(registered_at),
                "city": RNG.choice(CITIES),
                "acquisition_channel": RNG.choices(CHANNELS, weights=[34, 25, 18, 13, 10])[0],
            }
        )

    products = []
    for category, names in CATEGORIES.items():
        for number in range(1, 33):
            base_name = RNG.choice(names)
            price = round(RNG.uniform(690, 11990), 2)
            products.append(
                {
                    "product_id": f"P{len(products) + 1:04d}",
                    "product_name": f"{base_name} {number}",
                    "category": category,
                    "unit_price": price,
                    "unit_cost": round(price * RNG.uniform(0.32, 0.58), 2),
                }
            )
    product_by_id = {product["product_id"]: product for product in products}

    orders, order_items, payments, returns = [], [], [], []
    customer_by_id = {customer["customer_id"]: customer for customer in customers}
    for number in range(1, 12001):
        customer = RNG.choice(customers)
        registered_at = datetime.fromisoformat(customer["registered_at"])
        order_start = max(registered_at + timedelta(days=1), START)
        if order_start > END:
            order_start = START
        ordered_at = random_datetime(order_start, END)
        status = RNG.choices(["completed", "cancelled"], weights=[92, 8])[0]
        order_id = f"O{number:06d}"
        orders.append(
            {
                "order_id": order_id,
                "customer_id": customer["customer_id"],
                "ordered_at": iso(ordered_at),
                "status": status,
                "delivery_days": RNG.randint(1, 9) if status == "completed" else "",
                "promo_code": RNG.choices(["", "WELCOME10", "SPRING15", "EMAIL7"], weights=[68, 12, 11, 9])[0],
            }
        )
        if status == "cancelled":
            continue

        order_total = 0.0
        selected = RNG.sample(products, k=RNG.choices([1, 2, 3, 4], weights=[48, 30, 16, 6])[0])
        for position, product in enumerate(selected, start=1):
            quantity = RNG.choices([1, 2, 3], weights=[74, 21, 5])[0]
            discount = RNG.choices([0.0, 0.05, 0.10, 0.15, 0.20], weights=[57, 13, 17, 8, 5])[0]
            line_total = round(quantity * product["unit_price"] * (1 - discount), 2)
            item_id = f"I{number:06d}_{position}"
            order_items.append(
                {
                    "order_item_id": item_id,
                    "order_id": order_id,
                    "product_id": product["product_id"],
                    "quantity": quantity,
                    "unit_price": product["unit_price"],
                    "discount_pct": discount,
                }
            )
            order_total += line_total
            return_probability = 0.035 if product["category"] != "Textile" else 0.055
            if RNG.random() < return_probability:
                refunded_amount = round(line_total * RNG.choice([0.5, 1.0]), 2)
                returns.append(
                    {
                        "return_id": f"R{len(returns) + 1:05d}",
                        "order_item_id": item_id,
                        "returned_at": iso(ordered_at + timedelta(days=RNG.randint(4, 27))),
                        "reason": RNG.choice(["damaged", "wrong_item", "quality", "changed_mind"]),
                        "refunded_amount": refunded_amount,
                    }
                )
        payments.append(
            {
                "payment_id": f"PAY{number:06d}",
                "order_id": order_id,
                "paid_at": iso(ordered_at + timedelta(minutes=RNG.randint(0, 12))),
                "payment_method": RNG.choices(["card", "sbp", "wallet", "cash"], weights=[54, 25, 14, 7])[0],
                "amount": round(order_total, 2),
            }
        )

    write_csv("customers.csv", list(customers[0]), customers)
    write_csv("products.csv", list(products[0]), products)
    write_csv("orders.csv", list(orders[0]), orders)
    write_csv("order_items.csv", list(order_items[0]), order_items)
    write_csv("payments.csv", list(payments[0]), payments)
    write_csv("returns.csv", list(returns[0]), returns)
    print(f"Created {len(customers)} customers, {len(orders)} orders and {len(order_items)} order items in {DATA_DIR}")


if __name__ == "__main__":
    main()
