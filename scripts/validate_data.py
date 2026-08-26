"""Data validation framework for Warehouse Analytics.

Run: python scripts/validate_data.py
Exit codes: 0 = all checks passed, 1 = data-quality failures, 2 = execution error.
"""

from __future__ import annotations

import argparse
import json
import os
from contextlib import closing
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Sequence

import pyodbc


DEFAULT_CONNECTION_STRING = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=localhost;DATABASE=WarehouseAnalyticsDB;Trusted_Connection=yes;"
)


@dataclass(frozen=True)
class ValidationCheck:
    name: str
    query: str
    expected: int = 0


@dataclass(frozen=True)
class ValidationResult:
    name: str
    expected: int
    actual: int | None
    status: str
    error: str | None = None


CHECKS: tuple[ValidationCheck, ...] = (
    ValidationCheck(
        "No orphan inventory records",
        """SELECT COUNT(*) FROM raw.inventory i
           LEFT JOIN raw.warehouses w ON i.warehouse_id = w.warehouse_id
           LEFT JOIN raw.products p ON i.product_id = p.product_id
           WHERE w.warehouse_id IS NULL OR p.product_id IS NULL""",
    ),
    ValidationCheck(
        "No orphan shipment records",
        """SELECT COUNT(*) FROM raw.shipments s
           LEFT JOIN raw.warehouses w ON s.warehouse_id = w.warehouse_id
           WHERE w.warehouse_id IS NULL AND s.warehouse_id IS NOT NULL""",
    ),
    ValidationCheck(
        "No orphan shipment item records",
        """SELECT COUNT(*) FROM raw.shipment_items si
           LEFT JOIN raw.shipments s ON si.shipment_id = s.shipment_id
           WHERE s.shipment_id IS NULL""",
    ),
    ValidationCheck(
        "No orphan labor activity records",
        """SELECT COUNT(*) FROM raw.labor_activities la
           LEFT JOIN raw.employees e ON la.employee_id = e.employee_id
           LEFT JOIN raw.warehouses w ON la.warehouse_id = w.warehouse_id
           WHERE (e.employee_id IS NULL AND la.employee_id IS NOT NULL)
              OR (w.warehouse_id IS NULL AND la.warehouse_id IS NOT NULL)""",
    ),
    ValidationCheck(
        "No duplicate SKUs",
        "SELECT COUNT(*) - COUNT(DISTINCT sku) FROM raw.products",
    ),
    ValidationCheck(
        "No null required business keys",
        """SELECT
             (SELECT COUNT(*) FROM raw.warehouses WHERE warehouse_code IS NULL)
           + (SELECT COUNT(*) FROM raw.products WHERE sku IS NULL)
           + (SELECT COUNT(*) FROM raw.employees WHERE employee_code IS NULL)
           + (SELECT COUNT(*) FROM raw.shipments WHERE shipment_number IS NULL)""",
    ),
    ValidationCheck(
        "No negative inventory quantities",
        """SELECT COUNT(*) FROM raw.inventory
           WHERE quantity_on_hand < 0 OR quantity_reserved < 0 OR quantity_available < 0""",
    ),
    ValidationCheck(
        "Inventory quantities balance",
        """SELECT COUNT(*) FROM raw.inventory
           WHERE quantity_on_hand <> quantity_reserved + quantity_available""",
    ),
    ValidationCheck(
        "Ship date is not after expected delivery",
        """SELECT COUNT(*) FROM raw.shipments
           WHERE ship_date > expected_delivery""",
    ),
    ValidationCheck(
        "Labor hours are within valid range",
        """SELECT COUNT(*) FROM raw.labor_activities
           WHERE (start_time IS NULL AND end_time IS NOT NULL)
              OR (start_time IS NOT NULL AND end_time IS NULL)
              OR DATEDIFF(MINUTE, start_time, end_time) < 0
              OR DATEDIFF(MINUTE, start_time, end_time) > 1440""",
    ),
    ValidationCheck(
        "All employees reference valid warehouses",
        """SELECT COUNT(*) FROM raw.employees e
           LEFT JOIN raw.warehouses w ON e.warehouse_id = w.warehouse_id
           WHERE w.warehouse_id IS NULL AND e.warehouse_id IS NOT NULL""",
    ),
)


def execute_checks(cursor: Any, checks: Sequence[ValidationCheck] = CHECKS) -> list[ValidationResult]:
    results: list[ValidationResult] = []
    for check in checks:
        try:
            cursor.execute(check.query)
            row = cursor.fetchone()
            if row is None:
                raise RuntimeError("check returned no result row")
            actual = int(row[0])
            results.append(
                ValidationResult(
                    name=check.name,
                    expected=check.expected,
                    actual=actual,
                    status="PASS" if actual == check.expected else "FAIL",
                )
            )
        except Exception as exc:  # Continue so the report identifies every query error.
            results.append(
                ValidationResult(
                    name=check.name,
                    expected=check.expected,
                    actual=None,
                    status="ERROR",
                    error=str(exc),
                )
            )
    return results


def build_report(results: Sequence[ValidationResult], generated_at: datetime | None = None) -> dict[str, Any]:
    timestamp = generated_at or datetime.now(timezone.utc)
    counts = {status: sum(result.status == status for result in results) for status in ("PASS", "FAIL", "ERROR")}
    return {
        "generated_at": timestamp.isoformat(),
        "status": "PASS" if counts["FAIL"] == 0 and counts["ERROR"] == 0 else "FAIL",
        "summary": {"passed": counts["PASS"], "failed": counts["FAIL"], "errors": counts["ERROR"], "total": len(results)},
        "checks": [asdict(result) for result in results],
    }


def print_report(report: dict[str, Any]) -> None:
    print("\n" + "=" * 72)
    print(f"DATA VALIDATION REPORT - {report['generated_at']}")
    print("=" * 72)
    for result in report["checks"]:
        actual = "n/a" if result["actual"] is None else result["actual"]
        print(f"[{result['status']:^5}] {result['name']} (expected={result['expected']}, actual={actual})")
        if result["error"]:
            print(f"        Error: {result['error']}")
    summary = report["summary"]
    print("-" * 72)
    print(f"SUMMARY: {summary['passed']} passed, {summary['failed']} failed, {summary['errors']} errors, {summary['total']} total")
    print("=" * 72 + "\n")


def write_json_report(report: dict[str, Any], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


def run_validations(connection_string: str, report_path: Path | None = None) -> int:
    try:
        with closing(pyodbc.connect(connection_string, timeout=10)) as connection:
            with closing(connection.cursor()) as cursor:
                results = execute_checks(cursor)
    except pyodbc.Error as exc:
        print(f"Database connection failed: {exc}")
        return 2

    report = build_report(results)
    print_report(report)
    if report_path:
        write_json_report(report, report_path)
        print(f"JSON report written to {report_path}")
    if report["summary"]["errors"]:
        return 2
    return 0 if report["status"] == "PASS" else 1


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run Warehouse Analytics raw-data quality checks.")
    parser.add_argument(
        "--connection-string",
        default=os.getenv("WAREHOUSE_DB_CONNECTION_STRING", DEFAULT_CONNECTION_STRING),
        help="pyodbc connection string; defaults to WAREHOUSE_DB_CONNECTION_STRING or local trusted SQL Server.",
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=Path(__file__).resolve().parent / "reports" / "data_validation_report.json",
        help="JSON report path (default: scripts/reports/data_validation_report.json).",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    return run_validations(args.connection_string, args.report)


if __name__ == "__main__":
    raise SystemExit(main())
