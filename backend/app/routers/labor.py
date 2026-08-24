from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import text
from sqlalchemy.orm import Session

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


@router.get("/productivity", response_model=list[LaborProductivity])
def get_labor_productivity(
    warehouse_id: int | None = Query(default=None, gt=0),
    department: str | None = Query(
        default=None,
        min_length=1,
        max_length=100,
        pattern=r"^[A-Za-z0-9 &()/.-]+$",
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
