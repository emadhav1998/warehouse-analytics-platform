from pydantic import BaseModel, ConfigDict


class ShipmentPerformance(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [{"carrier": "UPS", "total_shipments": 320, "on_time": 305, "late": 15, "avg_transit_days": 2.75, "total_cost": 8125.5, "avg_cost": 25.39, "otd_rate": 95.31}]})

    carrier: str
    total_shipments: int
    on_time: int
    late: int
    avg_transit_days: float
    total_cost: float
    avg_cost: float
    otd_rate: float
