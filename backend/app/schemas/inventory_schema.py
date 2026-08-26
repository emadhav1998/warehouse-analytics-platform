from pydantic import BaseModel, ConfigDict, Field


class InventoryAlert(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [{"warehouse": "Atlanta Distribution Center", "sku": "SKU-10042", "product": "Safety Gloves", "on_hand": 5, "available": 0, "status": "Out of Stock", "reorder_point": 20}]})

    warehouse: str
    sku: str
    product: str
    on_hand: int
    available: int
    status: str
    reorder_point: int


class WarehouseOption(BaseModel):
    warehouse_id: int = Field(description="Natural warehouse identifier", gt=0)
    warehouse_code: str
    warehouse_name: str
    city_state: str
