DROP TABLE IF EXISTS returns, payments, order_items, orders, products, customers CASCADE;

CREATE TABLE customers (
    customer_id TEXT PRIMARY KEY,
    registered_at TIMESTAMPTZ NOT NULL,
    city TEXT NOT NULL,
    acquisition_channel TEXT NOT NULL CHECK (acquisition_channel IN ('organic', 'paid_search', 'social', 'email', 'referral'))
);

CREATE TABLE products (
    product_id TEXT PRIMARY KEY,
    product_name TEXT NOT NULL,
    category TEXT NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL CHECK (unit_price > 0),
    unit_cost NUMERIC(10, 2) NOT NULL CHECK (unit_cost >= 0)
);

CREATE TABLE orders (
    order_id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL REFERENCES customers(customer_id),
    ordered_at TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('completed', 'cancelled')),
    delivery_days INTEGER CHECK (delivery_days BETWEEN 0 AND 60),
    promo_code TEXT
);

CREATE TABLE order_items (
    order_item_id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL REFERENCES orders(order_id),
    product_id TEXT NOT NULL REFERENCES products(product_id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10, 2) NOT NULL CHECK (unit_price > 0),
    discount_pct NUMERIC(5, 4) NOT NULL CHECK (discount_pct BETWEEN 0 AND 1)
);

CREATE TABLE payments (
    payment_id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL REFERENCES orders(order_id),
    paid_at TIMESTAMPTZ NOT NULL,
    payment_method TEXT NOT NULL CHECK (payment_method IN ('card', 'sbp', 'wallet', 'cash')),
    amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0)
);

CREATE TABLE returns (
    return_id TEXT PRIMARY KEY,
    order_item_id TEXT NOT NULL REFERENCES order_items(order_item_id),
    returned_at TIMESTAMPTZ NOT NULL,
    reason TEXT NOT NULL CHECK (reason IN ('damaged', 'wrong_item', 'quality', 'changed_mind')),
    refunded_amount NUMERIC(12, 2) NOT NULL CHECK (refunded_amount >= 0)
);

CREATE INDEX idx_orders_customer_ordered_at ON orders (customer_id, ordered_at);
CREATE INDEX idx_orders_completed_at ON orders (ordered_at) WHERE status = 'completed';
CREATE INDEX idx_items_order ON order_items (order_id);
CREATE INDEX idx_returns_item ON returns (order_item_id);
