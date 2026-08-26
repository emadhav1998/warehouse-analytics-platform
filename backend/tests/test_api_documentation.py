import json
from pathlib import Path

from app.main import app


API_PATHS = {
    "/health",
    "/api/v1/kpis/dashboard",
    "/api/v1/kpis/definitions",
    "/api/v1/inventory/warehouses",
    "/api/v1/inventory/summary",
    "/api/v1/inventory/alerts",
    "/api/v1/shipments/performance",
    "/api/v1/labor/productivity",
    "/api/v1/validation/data-quality",
}


def test_every_operation_has_complete_documentation():
    schema = app.openapi()
    assert set(schema["paths"]) == API_PATHS

    operation_ids = []
    for path, path_item in schema["paths"].items():
        operation = path_item["get"]
        assert operation["summary"]
        assert operation["description"]
        assert operation["responses"]["200"]["content"]["application/json"]["example"]
        operation_ids.append(operation["operationId"])

        if path != "/health" and path != "/api/v1/kpis/definitions":
            assert "503" in operation["responses"]
            assert operation["responses"]["503"]["content"]["application/json"]["example"]

        for parameter in operation.get("parameters", []):
            assert parameter["description"]
            assert parameter["schema"].get("examples")

    assert len(operation_ids) == len(set(operation_ids))


def test_postman_collection_covers_every_api_operation():
    collection_path = (
        Path(__file__).parents[1]
        / "postman"
        / "Warehouse_Analytics_API.postman_collection.json"
    )
    collection = json.loads(collection_path.read_text(encoding="utf-8"))

    def requests(items):
        for item in items:
            if "request" in item:
                yield item["request"]
            yield from requests(item.get("item", []))

    raw_urls = {request["url"]["raw"].split("?", 1)[0] for request in requests(collection["item"])}
    documented_urls = {f"{{{{base_url}}}}{path}" for path in API_PATHS}
    assert documented_urls <= raw_urls
    assert collection["auth"]["type"] == "noauth"
