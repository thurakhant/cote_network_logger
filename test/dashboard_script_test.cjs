// Run with: node test/dashboard_script_test.cjs
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('lib/web_server/dashboard_script.dart', 'utf8').split("return r'''")[1].split("''';")[0];
const context = vm.createContext({console, window: {}, document: {addEventListener() {}}, setTimeout() {}});
vm.runInContext(source, context);
const merged = {
  transactionId: 'one', type: 'response', method: 'POST', url: 'https://example.test',
  requestHeaders: {'x-request': 'yes'}, headers: {'x-response': ['yes']},
  requestTimestamp: '2026-01-01T01:00:00Z', timestamp: '2026-01-01T01:00:01Z',
  requestBody: {hello: 'world'}, responseBody: {ok: true}, statusCode: 200
};
context.merged = merged;
const transaction = vm.runInContext('groupLogsIntoTransactions([merged])[0]', context);
assert.equal(transaction.timestamp, merged.requestTimestamp);
assert.equal(transaction.request.headers['x-request'], 'yes');
assert.equal(transaction.response.headers['x-response'][0], 'yes');
const curl = vm.runInContext('generateCurlCommand(groupLogsIntoTransactions([merged])[0].request)', context);
assert.match(curl, /x-request: yes/);
assert.doesNotMatch(curl, /x-response/);
assert.match(curl, /--data.*hello/);
assert.match(vm.runInContext('createDetailedView(groupLogsIntoTransactions([merged])[0])', context), /Request Headers/);
console.log('Dashboard merged request and cURL tests passed.');
