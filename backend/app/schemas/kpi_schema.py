from datetime import date

from pydantic import BaseModel


class KPIValue(BaseModel):
    kpi_name: str
    value: float
    unit: str
    target: float | None = None
    status: str | None = None
    as_of_date: date


class KPIDashboard(BaseModel):
    warehouse_id: int | None = None
    warehouse_name: str | None = None
    kpis: list[KPIValue]


class KPIDefinition(BaseModel):
    kpi_name: str
    domain: str
    description: str
    formula: str
    unit: str
    target: float | None = None
    frequency: str
    owner: str


class InventorySummary(BaseModel):
    warehouse_name: str
    total_skus: int
    total_quantity: int
    total_value: float
    stockout_count: int
    reorder_count: int
