-- =============================================================================
-- File    : seed_data.sql
-- Purpose : Insert reference / sample data into raw tables for dev & testing
-- Author  : Madhav Eadala
-- Date    : 2026-07-15
-- Run     : After V001_initial_setup.sql
-- =============================================================================

USE WarehouseAnalyticsDB;
GO

-- ── raw.warehouses ────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM raw.warehouses WHERE warehouse_code = 'WH-EAST-01')
BEGIN
    INSERT INTO raw.warehouses
        (warehouse_code, warehouse_name, address, city, state, zip_code, capacity_sqft, warehouse_type)
    VALUES
        ('WH-EAST-01', 'East Coast Distribution Center', '100 Industrial Blvd', 'Newark',     'NJ', '07105', 250000.00, 'Distribution'),
        ('WH-WEST-01', 'West Coast Fulfillment Hub',     '500 Commerce Way',    'Los Angeles', 'CA', '90001', 320000.00, 'Fulfillment'),
        ('WH-CENT-01', 'Central Cold Storage',           '200 Freeze Pkwy',     'Chicago',     'IL', '60601', 180000.00, 'Cold Storage'),
        ('WH-SOUT-01', 'Southern Fulfillment Center',    '75 Logistics Lane',   'Atlanta',     'GA', '30301', 210000.00, 'Fulfillment');
END
GO

-- ── raw.products ──────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM raw.products WHERE sku = 'SKU-ELEC-001')
BEGIN
    INSERT INTO raw.products
        (sku, product_name, category, subcategory, unit_cost, unit_price, weight_lbs, is_hazardous, is_perishable, reorder_point, reorder_quantity)
    VALUES
        ('SKU-ELEC-001', 'Wireless Headphones',      'Electronics',  'Audio',        45.00,  89.99,  0.75, 0, 0, 100, 500),
        ('SKU-ELEC-002', 'USB-C Charging Cable 6ft', 'Electronics',  'Accessories',   3.50,   9.99,  0.10, 0, 0, 500, 2000),
        ('SKU-FOOD-001', 'Organic Granola Bar 12pk', 'Food',         'Snacks',        4.20,   8.49,  1.20, 0, 1,  50, 200),
        ('SKU-FOOD-002', 'Cold Brew Coffee 8-Pack',  'Food',         'Beverages',     9.00,  18.99,  5.50, 0, 1,  30, 120),
        ('SKU-HOME-001', 'Stainless Steel Water Bottle', 'Home',     'Kitchen',       6.00,  14.99,  0.80, 0, 0, 200, 800),
        ('SKU-CHEM-001', 'Industrial Cleaner 1gal',  'Chemicals',    'Cleaning',      8.00,  15.99,  9.00, 1, 0,  25, 100);
END
GO

-- ── raw.employees ─────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM raw.employees WHERE employee_code = 'EMP-0001')
BEGIN
    DECLARE @wh1 INT = (SELECT warehouse_id FROM raw.warehouses WHERE warehouse_code = 'WH-EAST-01');
    DECLARE @wh2 INT = (SELECT warehouse_id FROM raw.warehouses WHERE warehouse_code = 'WH-WEST-01');

    INSERT INTO raw.employees
        (employee_code, first_name, last_name, email, department, job_title, warehouse_id, shift, hire_date, hourly_rate)
    VALUES
        ('EMP-0001', 'Carlos',  'Rivera',   'c.rivera@wap.local',   'Receiving',   'Receiving Associate',  @wh1, 'Day',   '2022-03-15', 18.50),
        ('EMP-0002', 'Diana',   'Chen',     'd.chen@wap.local',     'Picking',     'Picker I',             @wh1, 'Day',   '2021-07-01', 17.25),
        ('EMP-0003', 'Marcus',  'Johnson',  'm.johnson@wap.local',  'Packing',     'Packer II',            @wh1, 'Swing', '2023-01-10', 19.00),
        ('EMP-0004', 'Aisha',   'Williams', 'a.williams@wap.local', 'Shipping',    'Shipping Lead',        @wh1, 'Night', '2020-09-22', 22.75),
        ('EMP-0005', 'Ravi',    'Patel',    'r.patel@wap.local',    'Management',  'Shift Supervisor',     @wh2, 'Day',   '2019-05-14', 32.00),
        ('EMP-0006', 'Sophia',  'Martinez', 's.martinez@wap.local', 'Picking',     'Picker II',            @wh2, 'Swing', '2023-06-01', 17.75);
END
GO

-- ── raw.inventory (snapshot for today) ───────────────────────────────────────
IF NOT EXISTS (
    SELECT 1 FROM raw.inventory WHERE snapshot_date = CAST(GETDATE() AS DATE)
)
BEGIN
    DECLARE @today DATE = CAST(GETDATE() AS DATE);
    DECLARE @wh1i  INT  = (SELECT warehouse_id FROM raw.warehouses WHERE warehouse_code = 'WH-EAST-01');
    DECLARE @wh2i  INT  = (SELECT warehouse_id FROM raw.warehouses WHERE warehouse_code = 'WH-WEST-01');
    DECLARE @p1    INT  = (SELECT product_id   FROM raw.products   WHERE sku = 'SKU-ELEC-001');
    DECLARE @p2    INT  = (SELECT product_id   FROM raw.products   WHERE sku = 'SKU-ELEC-002');
    DECLARE @p3    INT  = (SELECT product_id   FROM raw.products   WHERE sku = 'SKU-HOME-001');

    INSERT INTO raw.inventory
        (warehouse_id, product_id, quantity_on_hand, quantity_reserved, quantity_available, bin_location, snapshot_date)
    VALUES
        (@wh1i, @p1, 450, 80,  370, 'A-01-B', @today),
        (@wh1i, @p2, 1800, 200, 1600, 'A-02-A', @today),
        (@wh1i, @p3, 620, 50,  570, 'B-05-C', @today),
        (@wh2i, @p1, 310, 40,  270, 'C-01-A', @today),
        (@wh2i, @p2, 950, 100, 850, 'C-02-B', @today);
END
GO

-- ── raw.shipments ─────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM raw.shipments WHERE shipment_number = 'SHP-2026-0001')
BEGIN
    DECLARE @wh1s INT = (SELECT warehouse_id FROM raw.warehouses WHERE warehouse_code = 'WH-EAST-01');
    DECLARE @wh2s INT = (SELECT warehouse_id FROM raw.warehouses WHERE warehouse_code = 'WH-WEST-01');

    INSERT INTO raw.shipments
        (shipment_number, warehouse_id, order_number, shipment_type, status, carrier,
         tracking_number, total_items, total_weight_lbs, ship_date, expected_delivery,
         actual_delivery, origin_address, dest_address, shipping_cost)
    VALUES
        ('SHP-2026-0001', @wh1s, 'ORD-10001', 'Outbound', 'Delivered',  'FedEx',  '1Z9999999999999990', 25, 45.50,  '2026-07-01', '2026-07-03', '2026-07-03', '100 Industrial Blvd, Newark NJ',   '55 Commerce St, New York NY',     38.75),
        ('SHP-2026-0002', @wh1s, 'ORD-10002', 'Outbound', 'In Transit', 'UPS',    '1Z8888888888888880', 10, 18.20,  '2026-07-13', '2026-07-16', NULL,         '100 Industrial Blvd, Newark NJ',   '200 Main St, Boston MA',          22.40),
        ('SHP-2026-0003', @wh2s, 'ORD-10003', 'Inbound',  'Delivered',  'DHL',    'GM123456789US',       60, 320.00, '2026-07-08', '2026-07-12', '2026-07-11', '800 Supplier Ave, Dallas TX',      '500 Commerce Way, Los Angeles CA', 95.00),
        ('SHP-2026-0004', @wh2s, 'ORD-10004', 'Outbound', 'Pending',    'USPS',   '9400111899223397614', 5,  6.75,   '2026-07-15', '2026-07-18', NULL,         '500 Commerce Way, Los Angeles CA', '300 Oak Rd, Seattle WA',           8.95);
END
GO

PRINT 'seed_data.sql completed — reference data inserted.';
GO
