from pydantic import BaseModel


class InventoryAlert(BaseModel):
    warehouse: str
    sku: str
    product: str
    on_hand: int
    available: int
    status: str
    reorder_point: int


class WarehouseOption(BaseModel):
    warehouse_id: int
    warehouse_code: str
    warehouse_name: str
    city_state: str
