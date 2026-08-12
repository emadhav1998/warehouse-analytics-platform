from datetime import datetime

from pydantic import BaseModel


class DataQualityCheck(BaseModel):
    check_name: str
    failed_rows: int
    status: str


class DataQualityReport(BaseModel):
    status: str
    checked_at: datetime
    checks: list[DataQualityCheck]

