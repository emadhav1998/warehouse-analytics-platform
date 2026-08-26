"""
generate_sample_data.py
=======================
Generate realistic warehouse sample data for all raw tables.
Produces 30,000+ rows across warehouses, products, employees,
inventory, shipments, shipment_items, and labor_activities.

Usage
-----
    python scripts/generate_sample_data.py
    python scripts/generate_sample_data.py --server MYSERVER\\SQLEXPRESS
    python scripts/generate_sample_data.py --server MYSERVER --uid sa --pwd secret

Requirements
------------
    pip install -r scripts/requirements.txt
    ODBC Driver 17 for SQL Server must be installed:
    https://learn.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server
"""

import argparse
import random
import sys
from datetime import datetime, timedelta, date

try:
    from faker import Faker
    import pyodbc
except ImportError:
    sys.exit(
        "Missing dependencies.\n"
        "Run:  pip install -r scripts/requirements.txt"
    )

fake = Faker()
random.seed(42)  # reproducible runs

# ---------------------------------------------------------------------------
# Volume constants
# ---------------------------------------------------------------------------
NUM_WAREHOUSES        = 5
NUM_PRODUCTS          = 200
NUM_EMPLOYEES         = 80
NUM_INVENTORY_RECORDS = 10_000
NUM_SHIPMENTS         = 3_000
NUM_LABOR_ACTIVITIES  = 15_000
DATE_RANGE_DAYS       = 365
BATCH_SIZE            = 500      # rows per executemany call

# ---------------------------------------------------------------------------
# Reference data
# ---------------------------------------------------------------------------
WAREHOUSE_TYPES = [
    "Distribution Center", "Fulfillment Center", "Cold Storage", "Regional Hub",
]
DEPARTMENTS = [
    "Receiving", "Picking", "Packing", "Shipping", "Inventory Control", "Management",
]
SHIFTS           = ["Day", "Swing", "Night"]
CARRIERS         = ["FedEx", "UPS", "USPS", "DHL", "Amazon Logistics", "XPO Logistics"]
SHIPMENT_TYPES   = ["Inbound", "Outbound"]
SHIPMENT_STATUSES = ["Pending", "In Transit", "Delivered", "Cancelled", "Returned"]
ACTIVITY_TYPES   = ["Picking", "Packing", "Receiving", "Putaway", "Loading", "Cycle Count"]
STATES = [
    "AL", "AZ", "CA", "CO", "FL", "GA", "IL", "IN", "MI", "MN",
    "MO", "NJ", "NY", "NC", "OH", "PA", "TN", "TX", "WA", "WI",
]
CATEGORIES = [
    "Electronics", "Clothing", "Food & Beverage",
    "Home & Garden", "Automotive", "Health & Beauty",
]
SUBCATEGORIES = {
    "Electronics":     ["Audio", "Computers", "Accessories", "Wearables"],
    "Clothing":        ["Tops", "Bottoms", "Footwear", "Accessories"],
    "Food & Beverage": ["Snacks", "Beverages", "Frozen", "Dry Goods"],
    "Home & Garden":   ["Kitchen", "Tools", "Decor", "Outdoor"],
    "Automotive":      ["Parts", "Accessories", "Fluids", "Tools"],
    "Health & Beauty": ["Skincare", "Supplements", "Personal Care", "Fitness"],
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _d(d):
    """Format a date or datetime as 'YYYY-MM-DD', or return None."""
    if d is None:
        return None
    if isinstance(d, datetime):
        return d.strftime("%Y-%m-%d")
    return d.strftime("%Y-%m-%d")


def _dt(d):
    """Format a datetime as 'YYYY-MM-DD HH:MM:SS', or return None."""
    if d is None:
        return None
    return d.strftime("%Y-%m-%d %H:%M:%S")


def _batch_insert(cursor, conn, sql, rows, label):
    """Insert rows in fixed-size batches and print progress."""
    total = len(rows)
    for start in range(0, total, BATCH_SIZE):
        batch = rows[start : start + BATCH_SIZE]
        cursor.executemany(sql, batch)
        conn.commit()
        done = min(start + BATCH_SIZE, total)
        print(f"    {label}: {done:,}/{total:,} rows", end="\r")
    print(f"    {label}: {total:,}/{total:,} rows  ✓")


def _row_count(cursor, table):
    cursor.execute(f"SELECT COUNT(*) FROM raw.{table}")
    return cursor.fetchone()[0]


# ---------------------------------------------------------------------------
# Generators
# ---------------------------------------------------------------------------

def generate_warehouses(cursor, conn):
    offset = _row_count(cursor, "warehouses")
    rows = []
    for i in range(NUM_WAREHOUSES):
        wtype = random.choice(WAREHOUSE_TYPES)
        rows.append((
            f"WH-{offset + i + 1:04d}",
            f"{fake.city()} {wtype}"[:100],
            fake.street_address()[:255],
            fake.city()[:100],
            random.choice(STATES),
            "USA",
            fake.zipcode()[:20],
            round(random.uniform(50_000, 500_000), 2),
            wtype,
            1,
        ))
    _batch_insert(
        cursor, conn,
        "INSERT INTO raw.warehouses "
        "(warehouse_code, warehouse_name, address, city, state, country, "
        "zip_code, capacity_sqft, warehouse_type, is_active) "
        "VALUES (?,?,?,?,?,?,?,?,?,?)",
        rows,
        "Warehouses",
    )
    cursor.execute("SELECT warehouse_id FROM raw.warehouses")
    return [r[0] for r in cursor.fetchall()]


def generate_products(cursor, conn):
    offset = _row_count(cursor, "products")
    rows = []
    for i in range(NUM_PRODUCTS):
        cat  = random.choice(CATEGORIES)
        sub  = random.choice(SUBCATEGORIES[cat])
        cost = round(random.uniform(1.0, 500.0), 2)
        rows.append((
            f"SKU-{offset + i + 1:06d}",
            fake.catch_phrase()[:200],
            cat,
            sub,
            cost,
            round(cost * random.uniform(1.2, 3.0), 2),
            round(random.uniform(0.1, 100.0), 2),
            int(random.random() < 0.05),          # 5 % hazardous
            int(cat == "Food & Beverage"),
            random.randint(10, 100),
            random.randint(50, 500),
        ))
    _batch_insert(
        cursor, conn,
        "INSERT INTO raw.products "
        "(sku, product_name, category, subcategory, unit_cost, unit_price, "
        "weight_lbs, is_hazardous, is_perishable, reorder_point, reorder_quantity) "
        "VALUES (?,?,?,?,?,?,?,?,?,?,?)",
        rows,
        "Products",
    )
    cursor.execute("SELECT product_id FROM raw.products")
    return [r[0] for r in cursor.fetchall()]


def generate_employees(cursor, conn, warehouse_ids):
    offset = _row_count(cursor, "employees")
    rows = []
    for i in range(NUM_EMPLOYEES):
        rows.append((
            f"EMP-{offset + i + 1:05d}",
            fake.first_name()[:100],
            fake.last_name()[:100],
            fake.email()[:200],
            random.choice(DEPARTMENTS),
            fake.job()[:100],
            random.choice(warehouse_ids),
            random.choice(SHIFTS),
            _d(fake.date_between(start_date="-5y", end_date="today")),
            round(random.uniform(15.0, 45.0), 2),
            1,
        ))
    _batch_insert(
        cursor, conn,
        "INSERT INTO raw.employees "
        "(employee_code, first_name, last_name, email, department, job_title, "
        "warehouse_id, shift, hire_date, hourly_rate, is_active) "
        "VALUES (?,?,?,?,?,?,?,?,?,?,?)",
        rows,
        "Employees",
    )
    cursor.execute("SELECT employee_id FROM raw.employees")
    return [r[0] for r in cursor.fetchall()]


def generate_inventory(cursor, conn, warehouse_ids, product_ids):
    # Pre-load existing snapshot keys to respect the UNIQUE constraint
    cursor.execute(
        "SELECT warehouse_id, product_id, snapshot_date FROM raw.inventory"
    )
    used_keys = set()
    for row in cursor.fetchall():
        snap = row[2].date() if isinstance(row[2], datetime) else row[2]
        used_keys.add((row[0], row[1], snap))

    base = (datetime.now() - timedelta(days=DATE_RANGE_DAYS)).date()
    rows = []
    attempts = 0
    max_attempts = NUM_INVENTORY_RECORDS * 20  # safety cap

    while len(rows) < NUM_INVENTORY_RECORDS and attempts < max_attempts:
        attempts += 1
        wh   = random.choice(warehouse_ids)
        prod = random.choice(product_ids)
        snap = base + timedelta(days=random.randint(0, DATE_RANGE_DAYS))
        key  = (wh, prod, snap)
        if key in used_keys:
            continue
        used_keys.add(key)

        on_hand  = random.randint(0, 5_000)
        reserved = random.randint(0, min(on_hand, 500))
        expiry   = (snap + timedelta(days=random.randint(30, 730))) if random.random() > 0.7 else None
        rows.append((
            wh,
            prod,
            on_hand,
            reserved,
            on_hand - reserved,
            f"{random.choice('ABCDEF')}-{random.randint(1,50):02d}-{random.randint(1,10):02d}",
            f"LOT-{random.randint(10_000, 99_999)}",
            _d(expiry),
            _d(snap),
            _d(snap),
        ))

    if len(rows) < NUM_INVENTORY_RECORDS:
        print(f"    Warning: only generated {len(rows):,} unique inventory keys "
              f"(requested {NUM_INVENTORY_RECORDS:,})")

    _batch_insert(
        cursor, conn,
        "INSERT INTO raw.inventory "
        "(warehouse_id, product_id, quantity_on_hand, quantity_reserved, "
        "quantity_available, bin_location, lot_number, expiry_date, "
        "last_count_date, snapshot_date) "
        "VALUES (?,?,?,?,?,?,?,?,?,?)",
        rows,
        "Inventory",
    )


def generate_shipments(cursor, conn, warehouse_ids, product_ids):
    offset   = _row_count(cursor, "shipments")
    base     = (datetime.now() - timedelta(days=DATE_RANGE_DAYS)).date()
    ship_rows = []
    # Keep (shipment_number, num_items) to build line items after insert
    meta      = []

    for i in range(NUM_SHIPMENTS):
        ship_date = base + timedelta(days=random.randint(0, DATE_RANGE_DAYS))
        status    = random.choice(SHIPMENT_STATUSES)
        expected  = ship_date + timedelta(days=random.randint(1, 14))
        actual    = (
            expected + timedelta(days=random.randint(-2, 5))
            if status == "Delivered" else None
        )
        num_items = random.randint(1, 10)
        snum      = f"SHP-{offset + i + 1:07d}"
        ship_rows.append((
            snum,
            random.choice(warehouse_ids),
            f"ORD-{random.randint(100_000, 999_999)}",
            random.choice(SHIPMENT_TYPES),
            status,
            random.choice(CARRIERS),
            fake.bothify(text="1Z####??########").upper()[:100],
            num_items,
            round(random.uniform(0.5, 50.0) * num_items, 2),
            _d(ship_date),
            _d(expected),
            _d(actual),
            fake.address().replace("\n", ", ")[:255],
            fake.address().replace("\n", ", ")[:255],
            round(random.uniform(5.0, 500.0), 2),
        ))
        meta.append((snum, num_items))

    _batch_insert(
        cursor, conn,
        "INSERT INTO raw.shipments "
        "(shipment_number, warehouse_id, order_number, shipment_type, status, "
        "carrier, tracking_number, total_items, total_weight_lbs, ship_date, "
        "expected_delivery, actual_delivery, origin_address, dest_address, shipping_cost) "
        "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        ship_rows,
        "Shipments",
    )

    # Fetch real auto-generated shipment_ids keyed by shipment_number
    placeholders = ",".join("?" * len(meta))
    snums        = [m[0] for m in meta]
    cursor.execute(
        f"SELECT shipment_number, shipment_id FROM raw.shipments "
        f"WHERE shipment_number IN ({placeholders})",
        snums,
    )
    shipment_map = {row[0]: row[1] for row in cursor.fetchall()}

    # Build line-item rows using actual shipment_ids
    item_rows = []
    for snum, num_items in meta:
        sid = shipment_map.get(snum)
        if sid is None:
            continue
        for _ in range(num_items):
            qty   = random.randint(1, 100)
            price = round(random.uniform(5.0, 200.0), 2)
            item_rows.append((sid, random.choice(product_ids), qty, price, round(qty * price, 2)))

    _batch_insert(
        cursor, conn,
        "INSERT INTO raw.shipment_items "
        "(shipment_id, product_id, quantity, unit_price, line_total) "
        "VALUES (?,?,?,?,?)",
        item_rows,
        "Shipment items",
    )


def generate_labor(cursor, conn, employee_ids, warehouse_ids):
    base = (datetime.now() - timedelta(days=DATE_RANGE_DAYS)).date()
    rows = []
    for _ in range(NUM_LABOR_ACTIVITIES):
        act_date  = base + timedelta(days=random.randint(0, DATE_RANGE_DAYS))
        start_dt  = datetime(
            act_date.year, act_date.month, act_date.day,
            random.randint(5, 21), random.randint(0, 59),
        )
        end_dt    = start_dt + timedelta(hours=random.uniform(0.5, 4.0))
        rows.append((
            random.choice(employee_ids),
            random.choice(warehouse_ids),
            random.choice(ACTIVITY_TYPES),
            _d(act_date),
            _dt(start_dt),
            _dt(end_dt),
            random.randint(10, 500),
            random.randint(1, 50),
            random.randint(0, 5) if random.random() > 0.8 else 0,
        ))
    _batch_insert(
        cursor, conn,
        "INSERT INTO raw.labor_activities "
        "(employee_id, warehouse_id, activity_type, activity_date, "
        "start_time, end_time, units_processed, orders_processed, errors_count) "
        "VALUES (?,?,?,?,?,?,?,?,?)",
        rows,
        "Labor activities",
    )


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args():
    p = argparse.ArgumentParser(
        description="Generate sample data for WarehouseAnalyticsDB"
    )
    p.add_argument("--server",  default="localhost",
                   help="SQL Server host (default: localhost)")
    p.add_argument("--db",      default="WarehouseAnalyticsDB",
                   help="Database name (default: WarehouseAnalyticsDB)")
    p.add_argument("--driver",  default="ODBC Driver 17 for SQL Server",
                   help="ODBC driver name")
    p.add_argument("--uid",     default=None,
                   help="SQL login username (omit for Windows auth)")
    p.add_argument("--pwd",     default=None,
                   help="SQL login password (omit for Windows auth)")
    return p.parse_args()


def build_conn_string(args):
    base = f"DRIVER={{{args.driver}}};SERVER={args.server};DATABASE={args.db};"
    if args.uid and args.pwd:
        return base + f"UID={args.uid};PWD={args.pwd};"
    return base + "Trusted_Connection=yes;"


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    args     = parse_args()
    conn_str = build_conn_string(args)

    print(f"\nConnecting to [{args.server}].[{args.db}] ...")
    try:
        conn = pyodbc.connect(conn_str)
    except pyodbc.Error as exc:
        sys.exit(f"Connection failed:\n{exc}")

    conn.autocommit = False
    cursor = conn.cursor()

    try:
        print("\n[1/6] Warehouses")
        warehouse_ids = generate_warehouses(cursor, conn)

        print("\n[2/6] Products")
        product_ids = generate_products(cursor, conn)

        print("\n[3/6] Employees")
        employee_ids = generate_employees(cursor, conn, warehouse_ids)

        print("\n[4/6] Inventory snapshots")
        generate_inventory(cursor, conn, warehouse_ids, product_ids)

        print("\n[5/6] Shipments + line items")
        generate_shipments(cursor, conn, warehouse_ids, product_ids)

        print("\n[6/6] Labor activities")
        generate_labor(cursor, conn, employee_ids, warehouse_ids)

        # ── Summary ──────────────────────────────────────────────────────────
        print("\n" + "=" * 50)
        print("Sample data generation complete!")
        print("=" * 50)
        for tbl in (
            "warehouses", "products", "employees",
            "inventory", "shipments", "shipment_items", "labor_activities",
        ):
            cursor.execute(f"SELECT COUNT(*) FROM raw.{tbl}")
            print(f"  raw.{tbl:<22} {cursor.fetchone()[0]:>8,} rows")
        print("=" * 50 + "\n")

    except Exception as exc:
        conn.rollback()
        sys.exit(f"\nData generation failed — all changes rolled back.\nError: {exc}")
    finally:
        cursor.close()
        conn.close()


if __name__ == "__main__":
    main()
