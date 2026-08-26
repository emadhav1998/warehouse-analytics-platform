# KPI Governance Portal

The portal is a dependency-free static site. It reads the API base URL from the `data-api-base` attribute on each
page's `<body>` element; update that value for deployed environments.

## Run locally

Start the FastAPI backend on port 8000, then serve this directory over HTTP:

```powershell
..\.venv\Scripts\python.exe -m http.server 5500 --directory frontend
```

Open `http://localhost:5500`. Do not open the HTML with a `file://` URL because browser fetch policies vary.

## Pages

- Dashboard: live KPI cards and details with a live warehouse filter.
- KPI Catalog: searchable definitions loaded from `/api/v1/kpis/definitions`.
- Data Dictionary: versioned documentation for all current mart and aggregate tables.

