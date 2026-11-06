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
context.quotedRequest = {url: "https://example.test/it's", method: 'POST', headers: {"x-note": "it's fine"}, body: false};
const quotedCurl = vm.runInContext('generateCurlCommand(quotedRequest)', context);
assert.ok(quotedCurl.includes("'https://example.test/it'\\''s'"));
assert.ok(quotedCurl.includes("'x-note: it'\\''s fine'"));
assert.match(quotedCurl, /--data 'false'/);
console.log('Dashboard merged request and cURL tests passed.');

(async () => {
  let copied = null;
  let removed = false;
  context.navigator = {};
  context.document = {
    activeElement: {focus() {}},
    body: {appendChild() {}},
    createElement() { return {style: {}, setAttribute() {}, select() {copied = this.value;}, remove() {removed = true;}}; },
    execCommand(command) { assert.equal(command, 'copy'); return true; },
    getElementById() {return {getAttribute(name) {return name === 'data-raw-content' ? '{"hello":"world"}' : null;}};}
  };
  await vm.runInContext('copyText("plain HTTP body")', context);
  assert.equal(copied, 'plain HTTP body');
  assert.equal(removed, true);
  context.navigator.clipboard = {async writeText() {throw Error('permission denied');}};
  await vm.runInContext('copyText("permission fallback")', context);
  assert.equal(copied, 'permission fallback');
  delete context.navigator.clipboard;
  context.event = {preventDefault() {}, stopPropagation() {}, target: {textContent: 'Copy', style: {}}};
  vm.runInContext('allTransactions = groupLogsIntoTransactions([merged]); copyCurlCommand(event, "one")', context);
  await new Promise(resolve => setImmediate(resolve));
  assert.match(copied, /x-request: yes/);
  assert.equal(context.event.target.textContent, '✓ cURL Copied!');
  vm.runInContext('copyJsonContent(event, "body")', context);
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(copied, JSON.stringify({hello: 'world'}, null, 2));
  assert.equal(context.event.target.textContent, '✓ Copied!');
  context.document.execCommand = () => false;
  await assert.rejects(vm.runInContext('copyText("failure")', context));
  console.log('Plain HTTP body and cURL copy fallback tests passed.');
})().catch(error => {console.error(error); process.exitCode = 1;});
