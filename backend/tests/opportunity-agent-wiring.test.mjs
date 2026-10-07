import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const APP = fs.readFileSync(new URL('../src/app.js', import.meta.url), 'utf8');

test('app wires Opportunity Agent service into its route factory', () => {
  assert.match(
    APP,
    /import \{[^}]*buildOpportunityAgentState[^}]*\} from ['"]\.\/services\/opportunity_agent\.js['"];/,
  );
  assert.match(APP, /createOpportunityAgentRoutes\(/);
  assert.match(APP, /buildOpportunityAgentState\(input\)/);
  assert.match(APP, /parts\[0\] === 'opportunity-agent'/);
});
