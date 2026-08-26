from datetime import datetime

from typing import Literal

from pydantic import BaseModel, ConfigDict


class DataQualityCheck(BaseModel):
    check_name: str
    failed_rows: int
    status: Literal["Passed", "Failed"]


class DataQualityReport(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [{"status": "Passed", "checked_at": "2026-08-26T14:30:00Z", "checks": [{"check_name": "Negative inventory quantities", "failed_rows": 0, "status": "Passed"}]}]})

    status: Literal["Passed", "Failed"]
    checked_at: datetime
    checks: list[DataQualityCheck]
