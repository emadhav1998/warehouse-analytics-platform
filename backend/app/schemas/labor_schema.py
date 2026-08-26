from pydantic import BaseModel, ConfigDict


class LaborProductivity(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [{"department": "Fulfillment", "activity_type": "Picking", "headcount": 24, "total_hours": 960.5, "total_units": 82450, "avg_uph": 85.84, "total_errors": 310, "total_cost": 22187.5}]})

    department: str
    activity_type: str
    headcount: int
    total_hours: float
    total_units: int
    avg_uph: float
    total_errors: int
    total_cost: float
