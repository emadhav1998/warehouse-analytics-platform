import unittest
from datetime import date

from app.main import app, health_check
from app.routers.inventory import get_inventory_alerts, get_inventory_summary, get_warehouses
from app.routers.kpis import _rag_status, get_kpi_dashboard, get_kpi_definitions
from app.routers.shipments import get_shipment_performance


class FakeMappingResult:
    def __init__(self, rows):
        self._rows = rows if isinstance(rows, list) else [rows]

    def mappings(self):
        return self

    def one(self):
        if len(self._rows) != 1:
            raise AssertionError("Expected exactly one row")
        return self._rows[0]

    def all(self):
        return self._rows


class FakeSession:
    def __init__(self, results):
        self._results = iter(results)
        self.calls = []

    def execute(self, statement, params=None):
        self.calls.append((str(statement), params or {}))
        return FakeMappingResult(next(self._results))


class ApiTests(unittest.TestCase):
    def test_health_and_routes(self):
        self.assertEqual(health_check()["status"], "healthy")
        paths = {route.path for route in app.routes}
        self.assertIn("/health", paths)
        self.assertIn("/api/v1/kpis/dashboard", paths)
        self.assertIn("/api/v1/inventory/summary", paths)
        self.assertIn("/api/v1/inventory/alerts", paths)
        self.assertIn("/api/v1/inventory/warehouses", paths)
        self.assertIn("/api/v1/shipments/performance", paths)

    def test_rag_status(self):
        self.assertEqual(_rag_status(96, 95), "Green")
        self.assertEqual(_rag_status(90, 95), "Yellow")
        self.assertEqual(_rag_status(80, 95), "Red")
        self.assertEqual(_rag_status(2, 3, lower_is_better=True), "Green")
        self.assertEqual(_rag_status(4, 3, lower_is_better=True), "Yellow")
        self.assertEqual(_rag_status(5, 3, lower_is_better=True), "Red")
        self.assertIsNone(_rag_status(100, None))

    def test_kpi_catalog_is_complete_and_described(self):
        definitions = get_kpi_definitions()
        self.assertEqual(len(definitions), 38)
        self.assertEqual({item.domain for item in definitions}, {"Inventory", "Shipment", "Labor"})
        self.assertTrue(all(item.description and item.formula and item.owner for item in definitions))

    def test_kpi_dashboard_uses_live_query_results(self):
        db = FakeSession([
            {
                "warehouse_name": "East Distribution Center",
                "total_value": 16_000_000,
                "stockout_count": 2,
                "total_records": 100,
                "reorder_count": 4,
                "as_of_date": date(2026, 8, 10),
            },
            {"otd_rate": 96.5, "total_shipments": 200, "avg_transit": 2.4},
            {"avg_uph": 82.25, "total_labor_cost": 125_000, "error_rate": 1.5},
        ])

        dashboard = get_kpi_dashboard(warehouse_id=1, db=db)

        self.assertEqual(dashboard.warehouse_id, 1)
        self.assertEqual(dashboard.warehouse_name, "East Distribution Center")
        self.assertEqual(len(dashboard.kpis), 6)
        self.assertEqual(dashboard.kpis[0].status, "Green")
        self.assertEqual(dashboard.kpis[1].value, 2.0)
        self.assertTrue(all(call[1]["wh_id"] == 1 for call in db.calls))

    def test_inventory_and_shipment_mapping(self):
        warehouse_db = FakeSession([[
            {
                "warehouse_id": 1,
                "warehouse_code": "WH-EAST-01",
                "warehouse_name": "East Distribution Center",
                "city_state": "Newark, NJ",
            }
        ]])
        warehouses = get_warehouses(db=warehouse_db)
        self.assertEqual(warehouses[0].warehouse_id, 1)

        inventory_db = FakeSession([[
            {
                "warehouse_name": "East Distribution Center",
                "total_skus": 42,
                "total_quantity": 1000,
                "total_value": 250_000.0,
                "stockout_count": 2,
                "reorder_count": 5,
            }
        ]])
        summaries = get_inventory_summary(warehouse_id=None, db=inventory_db)
        self.assertEqual(summaries[0].total_skus, 42)

        alert_db = FakeSession([[
            {
                "warehouse": "East Distribution Center",
                "sku": "SKU-001",
                "product": "Widget",
                "on_hand": 0,
                "available": 0,
                "status": "Out of Stock",
                "reorder_point": 10,
            }
        ]])
        alerts = get_inventory_alerts(warehouse_id=None, limit=50, db=alert_db)
        self.assertEqual(alerts[0].status, "Out of Stock")

        shipment_db = FakeSession([[
            {
                "carrier": "UPS",
                "total_shipments": 10,
                "on_time": 9,
                "late": 1,
                "avg_transit_days": 2.3,
                "total_cost": 500.0,
                "avg_cost": 50.0,
            }
        ]])
        performance = get_shipment_performance(days=30, warehouse_id=None, db=shipment_db)
        self.assertEqual(performance[0].otd_rate, 90.0)
        self.assertEqual(shipment_db.calls[0][1]["lookback_days"], -30)


if __name__ == "__main__":
    unittest.main()
