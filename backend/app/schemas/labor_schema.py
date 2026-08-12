from pydantic import BaseModel


class LaborProductivity(BaseModel):
    department: str
    activity_type: str
    headcount: int
    total_hours: float
    total_units: int
    avg_uph: float
    total_errors: int
    total_cost: float

