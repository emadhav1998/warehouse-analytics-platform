from pydantic import BaseModel


class ShipmentPerformance(BaseModel):
    carrier: str
    total_shipments: int
    on_time: int
    late: int
    avg_transit_days: float
    total_cost: float
    avg_cost: float
    otd_rate: float

