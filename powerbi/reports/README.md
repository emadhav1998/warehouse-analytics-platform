# Warehouse Analytics report pages

The repository does not contain a PBIX/PBIP report project. The report canvas is therefore defined in
`dashboard_pages.json` as a source-controlled build specification. It covers the Executive Overview,
Inventory Analysis, Shipment Performance, hidden Late Shipment Detail drill-through page, tooltip pages,
visual interactions, and conditional-formatting rules.

## Build order in Power BI Desktop

1. Load the star-schema mart tables and create the relationships documented in `../measures/kpi_measures.dax`.
2. Mark `dim_date` as the date table using `dim_date[date_key]`.
3. Import `../theme/warehouse_analytics_theme.json` from **View > Themes > Browse for themes**.
4. Create `_Measures` from `../measures/measures_table.dax` and hide its placeholder column.
5. Add measures from the inventory, shipment, labor, dashboard, and KPI governance measure files; set `_Measures` as their home table.
6. Create the disconnected `KPI Catalog` calculated table from `../measures/kpi_governance.dax`. Sort `KPI Catalog[KPI]`
   by `KPI Catalog[Sort Order]`; do not create relationships from this table.
7. Create the field parameter from `../measures/field_parameters.dax`.
8. Build pages and visuals from `dashboard_pages.json` on the 1636 x 900 custom canvas. Visual positions use the
   1440-pixel content area after the 196-pixel navigation offset.
9. Sync Date Range and Warehouse across visible pages. Sync Category only where inventory context is relevant. Category filters inventory visuals
   only because the current model has no product relationship to shipment or labor facts.
10. Create the four bookmarks defined in `dashboard_pages.json`. Turn **Data** off for each bookmark so Top/Bottom and
    Scorecard/Trend toggles preserve slicer selections; capture only the display state of the named bookmark group.
11. Hide the tooltip and Late Shipment Detail pages, then test drill-through with **Keep all filters** enabled.

## Publishing and refresh

- Apply the reusable page navigator from `dashboard_pages.json` to every visible page. The hidden drill-through page keeps
  its Back button and is intentionally excluded from primary navigation.
- Configure the gateway and four daily refresh slots from `../config/refresh_schedule.json`. Before publishing, create
  `RangeStart` and `RangeEnd` Date/Time parameters and filter each fact query with `date_key >= RangeStart` and
  `date_key < RangeEnd`; then apply the matching incremental-refresh policy in the table properties.
- The initial parameter dates are development-window values only. Power BI Service replaces them with managed partitions
  after the first refresh.

## Model optimization

- Apply `../config/model_optimization.json` after all relationships and measures are present. Remove the listed duplicate
  or unused columns from the report model, not from the warehouse mart, so API and dbt consumers remain compatible.
- Keep relationship keys loaded but hidden. Disable Auto date/time and implicit measures, and keep dimension-to-fact
  filtering single-direction.
- The three dbt models under `../../dbt_warehouse/models/marts/aggregations/` provide monthly import aggregates for
  inventory, shipment, and labor trends. Configure their aggregation mappings exactly as listed in the optimization file.

## Automated QA

Run the structural validation before publishing:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File powerbi/tests/validate_report.ps1
```

This checks theme parsing, navigation coverage, required slicers, cross-filter flags, drill-through targets, bookmark
references, refresh policies, removed-column safety, and aggregate-model mappings. Complete final visual rendering,
keyboard navigation, mobile layout, gateway credentials, and service refresh tests in Power BI Desktop/Service.

## Formatting conventions

- Percentage measures already return percentage points because their DAX multiplies by 100; use `0.00`, not `0.00%`.
- Positive KPI movement uses `#38A169`; negative movement uses `#E53E3E`. Reverse this direction for cost and stock-out cards.
- Currency uses `$#,##0.00`, counts use `#,##0`, and rates use `0.00` with a percent sign in the visual title or suffix.
- Sort `dim_date[year_month]` by `dim_date[date_key]`. When the weekly toggle spans multiple years, include
  `dim_date[year]` in the visual hierarchy so identical week numbers are not combined.
- The KPI Governance matrix intentionally uses a disconnected catalog. `KPI Actual | Value` selects the standardized
  measure for each row, while target, variance, status, color, definition, and sparkline remain responsive to report filters.

## Geographic map limitation

The requested destination map is intentionally not configured. Although the raw shipment source has `dest_address`,
that field is not exposed by `fact_shipment`, and it is not split into geocodable city/state/latitude/longitude fields.
The specification records this under `unavailableVisuals`. Add modeled destination geography before enabling a map;
do not send raw addresses to an external geocoder from the report.
