from pydantic import BaseModel, ConfigDict, Field


class ErrorDetail(BaseModel):
    code: str = Field(description="Stable, machine-readable error code", examples=["database_unavailable"])
    message: str = Field(description="Human-readable error explanation")


class ErrorResponse(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "error": {
                        "code": "database_unavailable",
                        "message": "The analytics database is temporarily unavailable.",
                    }
                }
            ]
        }
    )

    error: ErrorDetail


class HealthResponse(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={"examples": [{"status": "healthy", "app": "Warehouse Analytics API"}]}
    )

    status: str = Field(description="Current API process status", examples=["healthy"])
    app: str = Field(description="Configured application name", examples=["Warehouse Analytics API"])
