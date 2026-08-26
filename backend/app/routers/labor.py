from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.api_docs import documented_responses
from app.database import get_db
from app.schemas.labor_schema import LaborProductivity


router = APIRouter()

LABOR_PRODUCTIVITY_QUERY = text("""
    SELECT
        fl.department,
        fl.activity_type,
        COUNT(DISTINCT fl.employee_id) AS headcount,
        COALESCE(SUM(fl.total_hours), 0) AS total_hours,
        COALESCE(SUM(fl.total_units), 0) AS total_units,
        COALESCE(SUM(fl.total_units) / NULLIF(SUM(fl.total_hours), 0), 0) AS avg_uph,
        COALESCE(SUM(fl.total_errors), 0) AS total_errors,
        COALESCE(SUM(fl.labor_cost), 0) AS total_cost
    FROM mart.fact_labor fl
    WHERE fl.date_key >= DATEADD(MONTH, -1, CAST(GETDATE() AS date))
      AND (:wh_id IS NULL OR fl.warehouse_id = :wh_id)
      AND (:department IS NULL OR fl.department = :department)
    GROUP BY fl.department, fl.activity_type
    ORDER BY avg_uph DESC
    OPTION (RECOMPILE)
""")


@router.get(
    "/productivity",
    response_model=list[LaborProductivity],
    summary="Analyze labor productivity",
    description="Aggregates the trailing month of labor activity by department and activity type.",
    response_description="Labor productivity and cost metrics.",
    operation_id="get_labor_productivity",
    responses=documented_responses("Labor productivity metrics.", [{"department": "Fulfillment", "activity_type": "Picking", "headcount": 24, "total_hours": 960.5, "total_units": 82450, "avg_uph": 85.84, "total_errors": 310, "total_cost": 22187.5}], validation=True),
)
def get_labor_productivity(
    warehouse_id: int | None = Query(default=None, gt=0, description="Positive warehouse ID; omit for all warehouses.", examples=[1]),
    department: str | None = Query(
        default=None,
        min_length=1,
        max_length=100,
        pattern=r"^[A-Za-z0-9 &()/.-]+$",
        description="Exact department name (1–100 allowed characters).",
        examples=["Fulfillment"],
    ),
    db: Session = Depends(get_db),
) -> list[LaborProductivity]:
    normalized_department = department.strip() if department else None
    if department is not None and not normalized_department:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="department must contain at least one non-whitespace character.",
        )
    rows = db.execute(
        LABOR_PRODUCTIVITY_QUERY,
        {"wh_id": warehouse_id, "department": normalized_department},
    ).mappings().all()
    return [LaborProductivity(**row) for row in rows]
