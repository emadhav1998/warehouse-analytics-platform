'use strict';

global.window = {};
require('../js/data-dictionary.js');

const expectedColumnCounts = {
  dim_date: 18,
  dim_warehouse: 14,
  dim_product: 17,
  dim_employee: 14,
  fact_inventory: 18,
  fact_shipment: 24,
  fact_labor: 20,
  agg_inventory_monthly: 11,
  agg_shipment_monthly: 13,
  agg_labor_monthly: 10,
};

const dictionary = window.DATA_DICTIONARY;
if (dictionary.length !== Object.keys(expectedColumnCounts).length) throw new Error('Unexpected table count.');

for (const table of dictionary) {
  const expected = expectedColumnCounts[table.name];
  if (expected === undefined) throw new Error(`Unexpected table: ${table.name}`);
  if (table.columns.length !== expected) throw new Error(`${table.name}: expected ${expected} columns, found ${table.columns.length}`);
  const names = table.columns.map(([name]) => name);
  if (new Set(names).size !== names.length) throw new Error(`${table.name}: duplicate column names`);
  for (const [name, type, description] of table.columns) {
    if (!name || !type || !description) throw new Error(`${table.name}: incomplete column metadata`);
  }
}

console.log(`PASS: ${dictionary.length} tables and ${dictionary.reduce((sum, table) => sum + table.columns.length, 0)} columns documented`);

