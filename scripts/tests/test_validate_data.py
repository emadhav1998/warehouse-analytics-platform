from datetime import datetime, timezone

import json

from scripts.validate_data import CHECKS, ValidationCheck, build_report, execute_checks, write_json_report


class FakeCursor:
    def __init__(self, outcomes):
        self.outcomes = iter(outcomes)
        self.current = None

    def execute(self, query):
        self.current = next(self.outcomes)
        if isinstance(self.current, Exception):
            raise self.current
        return self

    def fetchone(self):
        return None if self.current is None else (self.current,)


def test_execute_checks_reports_pass_fail_and_error():
    checks = [ValidationCheck("pass", "one"), ValidationCheck("fail", "two"), ValidationCheck("error", "three")]
    results = execute_checks(FakeCursor([0, 3, RuntimeError("bad query")]), checks)
    assert [result.status for result in results] == ["PASS", "FAIL", "ERROR"]
    assert results[1].actual == 3
    assert results[2].error == "bad query"


def test_build_report_summary_and_status():
    checks = [ValidationCheck("first", "one"), ValidationCheck("second", "two")]
    results = execute_checks(FakeCursor([0, 0]), checks)
    report = build_report(results, datetime(2026, 8, 17, tzinfo=timezone.utc))
    assert report["status"] == "PASS"
    assert report["summary"] == {"passed": 2, "failed": 0, "errors": 0, "total": 2}
    assert report["generated_at"] == "2026-08-17T00:00:00+00:00"


def test_catalog_has_unique_comprehensive_checks():
    assert len(CHECKS) == 11
    assert len({check.name for check in CHECKS}) == len(CHECKS)
    assert all(check.query.lstrip().upper().startswith("SELECT") for check in CHECKS)


def test_write_json_report(tmp_path):
    report = build_report(execute_checks(FakeCursor([0]), [ValidationCheck("pass", "select")]))
    output = tmp_path / "validation.json"
    write_json_report(report, output)
    assert json.loads(output.read_text(encoding="utf-8"))["status"] == "PASS"
