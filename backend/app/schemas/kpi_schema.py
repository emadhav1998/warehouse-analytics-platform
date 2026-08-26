from datetime import date

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class KPIValue(BaseModel):
    kpi_name: str = Field(description="Standardized KPI display name", examples=["On-Time Delivery Rate"])
    value: float = Field(description="Current calculated KPI value", examples=[96.25])
    unit: str = Field(description="Display unit", examples=["%"])
    target: float | None = Field(default=None, description="Governance target", examples=[95.0])
    status: Literal["Green", "Yellow", "Red"] | None = Field(
        default=None, description="Target-based RAG status", examples=["Green"]
    )
    as_of_date: date = Field(description="Latest inventory snapshot date", examples=["2026-08-26"])


class KPIDashboard(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [{"warehouse_id": 1, "warehouse_name": "Atlanta Distribution Center", "kpis": [{"kpi_name": "On-Time Delivery Rate", "value": 96.25, "unit": "%", "target": 95.0, "status": "Green", "as_of_date": "2026-08-26"}]}]})

    warehouse_id: int | None = Field(default=None, description="Applied warehouse identifier")
    warehouse_name: str | None = Field(default=None, description="Applied warehouse name")
    kpis: list[KPIValue] = Field(description="Thirteen governed warehouse KPIs")


class KPIDefinition(BaseModel):
    kpi_name: str = Field(description="Canonical KPI name")
    domain: str = Field(description="Business subject area", examples=["Inventory"])
    description: str = Field(description="Business meaning of the KPI")
    formula: str = Field(description="Technology-neutral calculation formula")
    unit: str = Field(description="Display unit")
    target: float | None = Field(default=None, description="Approved performance target")
    frequency: str = Field(description="Expected refresh cadence", examples=["Daily"])
    owner: str = Field(description="Accountable business role", examples=["Inventory Manager"])


class InventorySummary(BaseModel):
    warehouse_name: str = Field(description="Warehouse display name")
    total_skus: int = Field(description="Distinct products in the latest snapshot", ge=0)
    total_quantity: int = Field(description="Total on-hand units", ge=0)
    total_value: float = Field(description="Inventory value at cost in USD", ge=0)
    stockout_count: int = Field(description="Out-of-stock snapshot rows", ge=0)
    reorder_count: int = Field(description="Rows requiring reorder", ge=0)
