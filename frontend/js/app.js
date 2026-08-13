'use strict';

const API_BASE = document.body.dataset.apiBase || 'http://localhost:8000/api/v1';
const page = document.body.dataset.page;

async function requestJson(path) {
  const response = await fetch(`${API_BASE}${path}`, { headers: { Accept: 'application/json' } });
  if (!response.ok) {
    let message = `Request failed (${response.status})`;
    try {
      const body = await response.json();
      message = body?.error?.message || body?.detail || message;
    } catch { /* Keep the HTTP fallback. */ }
    throw new Error(message);
  }
  return response.json();
}

function setMessage(message = '') {
  const element = document.getElementById('pageMessage');
  if (element) element.textContent = message;
}

function makeElement(tag, className, text) {
  const element = document.createElement(tag);
  if (className) element.className = className;
  if (text !== undefined) element.textContent = text;
  return element;
}

function formatValue(value, unit) {
  const number = Number(value ?? 0);
  if (unit === 'USD') return number.toLocaleString('en-US', { style: 'currency', currency: 'USD', minimumFractionDigits: 2 });
  if (unit === '%') return `${number.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}%`;
  return `${number.toLocaleString('en-US', { maximumFractionDigits: 2 })}${unit ? ` ${unit}` : ''}`;
}

function statusClass(status) {
  const normalized = String(status || '').toLowerCase();
  return ['green', 'yellow', 'red'].includes(normalized) ? normalized : 'neutral';
}

function renderKPICards(kpis) {
  const container = document.getElementById('kpiCards');
  container.replaceChildren(...kpis.map((kpi) => {
    const card = makeElement('article', `kpi-card ${statusClass(kpi.status)}`);
    card.append(makeElement('h3', '', kpi.kpi_name), makeElement('div', 'value', formatValue(kpi.value, kpi.unit)));
    if (kpi.target !== null && kpi.target !== undefined) card.append(makeElement('div', 'target', `Target: ${formatValue(kpi.target, kpi.unit)}`));
    card.append(makeElement('span', `status-badge ${statusClass(kpi.status)}`, kpi.status || 'Monitor'));
    return card;
  }));
  container.setAttribute('aria-busy', 'false');
}

function renderKPITable(kpis) {
  const body = document.querySelector('#kpiTable tbody');
  body.replaceChildren(...kpis.map((kpi) => {
    const row = document.createElement('tr');
    const nameCell = document.createElement('td');
    nameCell.append(makeElement('strong', '', kpi.kpi_name));
    const values = [
      formatValue(kpi.value, kpi.unit),
      kpi.target === null || kpi.target === undefined ? 'N/A' : formatValue(kpi.target, kpi.unit),
      null,
      kpi.unit,
      new Date(`${kpi.as_of_date}T00:00:00`).toLocaleDateString(),
    ];
    row.append(nameCell);
    values.forEach((value, index) => {
      const cell = document.createElement('td');
      if (index === 2) cell.append(makeElement('span', `status-badge ${statusClass(kpi.status)}`, kpi.status || 'Monitor'));
      else cell.textContent = value;
      row.append(cell);
    });
    return row;
  }));
}

async function loadWarehouses() {
  const select = document.getElementById('warehouseFilter');
  try {
    const warehouses = await requestJson('/inventory/warehouses');
    warehouses.forEach((warehouse) => {
      const option = document.createElement('option');
      option.value = String(warehouse.warehouse_id);
      option.textContent = `${warehouse.warehouse_name} · ${warehouse.city_state}`;
      select.append(option);
    });
  } catch (error) {
    setMessage(`Warehouse list unavailable: ${error.message}`);
  }
}

async function fetchKPIs(warehouseId = '') {
  const cards = document.getElementById('kpiCards');
  cards.setAttribute('aria-busy', 'true');
  setMessage();
  try {
    const query = warehouseId ? `?warehouse_id=${encodeURIComponent(warehouseId)}` : '';
    const data = await requestJson(`/kpis/dashboard${query}`);
    renderKPICards(data.kpis);
    renderKPITable(data.kpis);
    document.getElementById('lastUpdated').textContent = `Updated ${new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;
  } catch (error) {
    cards.replaceChildren();
    cards.setAttribute('aria-busy', 'false');
    document.querySelector('#kpiTable tbody').replaceChildren();
    setMessage(`Unable to load KPI data. ${error.message}`);
  }
}

function renderCatalog(definitions) {
  const container = document.getElementById('catalogGrid');
  container.replaceChildren(...definitions.map((kpi) => {
    const article = makeElement('article', 'catalog-card');
    article.dataset.search = Object.values(kpi).join(' ').toLowerCase();
    article.append(makeElement('p', 'eyebrow', kpi.frequency), makeElement('h2', '', kpi.kpi_name), makeElement('div', 'formula', kpi.formula));
    const meta = makeElement('dl', 'meta-grid');
    [['Owner', kpi.owner], ['Unit', kpi.unit], ['Target', formatValue(kpi.target, kpi.unit)], ['Cadence', kpi.frequency]].forEach(([term, value]) => {
      const group = document.createElement('div'); group.append(makeElement('dt', '', term), makeElement('dd', '', value)); meta.append(group);
    });
    article.append(meta);
    return article;
  }));
  container.setAttribute('aria-busy', 'false');
}

async function loadCatalog() {
  try {
    renderCatalog(await requestJson('/kpis/definitions'));
    const input = document.getElementById('catalogSearch');
    input.addEventListener('input', () => {
      const query = input.value.trim().toLowerCase(); let visible = 0;
      document.querySelectorAll('.catalog-card').forEach((card) => { const show = card.dataset.search.includes(query); card.hidden = !show; if (show) visible += 1; });
      document.getElementById('catalogEmpty').hidden = visible !== 0;
    });
  } catch (error) { setMessage(`Unable to load KPI definitions. ${error.message}`); }
}

document.addEventListener('DOMContentLoaded', () => {
  if (page === 'dashboard') {
    loadWarehouses(); fetchKPIs();
    document.getElementById('warehouseFilter').addEventListener('change', (event) => fetchKPIs(event.target.value));
  } else if (page === 'catalog') loadCatalog();
  else if (page === 'dictionary' && window.initializeDictionary) window.initializeDictionary();
});

