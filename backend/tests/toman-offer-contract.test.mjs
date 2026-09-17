import assert from 'node:assert/strict';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const offer = fs.readFileSync(new URL('../src/routes/offer_routes.js', import.meta.url), 'utf8');
const mapper = fs.readFileSync(new URL('../src/repository/mappers.js', import.meta.url), 'utf8');
const views = fs.readFileSync(new URL('../src/repository/views.js', import.meta.url), 'utf8');
const serialization = fs.readFileSync(new URL('../src/db/serialization.js', import.meta.url), 'utf8');
const payment = fs.readFileSync(new URL('../src/routes/payment_routes.js', import.meta.url), 'utf8');

assert.match(offer, /tomanField \? tomanField\(body\.price, 'price'\)/);
assert.match(mapper, /offerFromRow[\s\S]*price: String\(r\.price \?\? '0'\)/);
assert.match(views, /offers[\s\S]*price:String\(o\.price \?\? '0'\)/);
assert.match(serialization, /offers[\s\S]*price:String\(r\.price \?\? '0'\)/);
assert.match(payment, /BigInt\(String\(a\.price\|\|'0'\)\)/);
console.log('toman-offer-contract: 5 assertions passed');
