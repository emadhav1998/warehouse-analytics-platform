import json
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]


def _read(relative_path: str) -> str:
    return (REPO_ROOT / relative_path).read_text(encoding="utf-8")


def test_performance_migration_has_all_covering_indexes():
    migration = _read("database/migrations/V003_add_performance_indexes.sql")
    expected_indexes = {
        "IX_fact_inventory_date_warehouse",
        "IX_fact_shipment_date_warehouse_status",
        "IX_fact_labor_date_warehouse_employee",
        "IX_inventory_snapshot",
        "IX_shipments_ship_date",
        "IX_labor_activity_date",
    }

    assert expected_indexes <= {line.strip(" []\r\n") for line in migration.split()}
    assert migration.count("NOT EXISTS") == len(expected_indexes)


def test_inventory_model_is_incremental_with_late_arrival_lookback():
    model = _read("dbt_warehouse/models/marts/fact_inventory.sql")

    assert "materialized='incremental'" in model
    assert "unique_key='inventory_fact_key'" in model
    assert "incremental_strategy='merge'" in model
    assert "{% if is_incremental() %}" in model
    assert "dateadd(" in model
    assert "-2" in model


def test_api_queries_enable_parameter_specific_plans():
    router_files = [
        "backend/app/routers/kpis.py",
        "backend/app/routers/inventory.py",
        "backend/app/routers/shipments.py",
        "backend/app/routers/labor.py",
    ]

    for router_file in router_files:
        assert "OPTION (RECOMPILE)" in _read(router_file)


def test_power_bi_aggregation_tables_are_enabled_and_prioritized():
    config = json.loads(_read("powerbi/config/model_optimization.json"))
    aggregations = config["aggregations"]

    assert config["settings"]["enableAggregationTables"] is True
    assert all(item["storageMode"] == "Import" for item in aggregations)
    precedence = [item["precedence"] for item in aggregations]
    assert len(precedence) == len(set(precedence))
    assert all(value > 0 for value in precedence)
