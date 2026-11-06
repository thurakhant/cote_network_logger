'use strict';
const assert = require('node:assert/strict');
const d = require('../web/dashboard.js');
const fs=require('node:fs');
const html=fs.readFileSync(require.resolve('../web/dashboard.html'),'utf8');
const source=fs.readFileSync(require.resolve('../web/dashboard.js'),'utf8');
assert.doesNotMatch(html, /<style|\sstyle=|\son[a-z]+=|<script(?! src=)/i);
assert.doesNotMatch(source, /innerHTML|insertAdjacentHTML|localStorage|sessionStorage|console\./);
assert.match(html, /src="\/dashboard.js"/);
assert.match(html, /href="\/dashboard.css"/);
const body = content => ({kind:'json',content,truncated:false,omissionReason:null});
const call = content => ({request:{method:'POST',url:"https://example.test/a'b",headers:{accept:['application/json']},captureWarnings:[],body:body(content)}});
(async () => {
  for (const value of [false,0,'',null]) assert.equal(d.bodyCopy(body(value)).text, JSON.stringify(value,null,2));
  assert.equal(d.shellQuote("a'b"), "'a'\"'\"'b'");
  assert.match(d.curlForCall(call(false)).text, /--data-raw 'false'/);
  const optionUrl=call(null);optionUrl.request.url='--config=/tmp/untrusted';
  assert.match(d.curlForCall(optionUrl).text, /--url '--config=/);

  const c = call('secret'); c.request.captureWarnings=['bodyFieldsOmitted','queryEncodingApproximate'];
  assert.doesNotMatch(d.curlForCall(c).text,/--data/); assert.ok(d.curlForCall(c).warnings.includes('queryEncodingApproximate'));
  c.request.headers.authorization=['secret']; assert.doesNotMatch(d.curlForCall(c).text,/secret/);
  assert.equal(d.bodyCopy({kind:'multipartSummary',summary:{fileCount:1}}).text,null);
  const s=d.createState();
  assert.equal(d.applySnapshot(s,{schemaVersion:2,sessionId:'a',version:2,clearGeneration:0,calls:[{id:'1'}]}),true);
  s.selected='1'; assert.equal(d.applySnapshot(s,{schemaVersion:2,sessionId:'a',version:1,clearGeneration:0,calls:[]}),false);
  assert.equal(d.applySnapshot(s,{schemaVersion:2,sessionId:'a',version:3,clearGeneration:1,calls:[]}),true); assert.equal(s.selected,null);
  const encoded=new TextEncoder().encode('{"type":"changed"}\n'); let records=[];
  await d.readNotifications(new ReadableStream({start(c){c.enqueue(encoded.slice(0,5));c.enqueue(encoded.slice(5));c.close();}}),x=>records.push(x)); assert.equal(records.length,1);
  await assert.rejects(d.readNotifications(new ReadableStream({start(c){c.enqueue(new Uint8Array(4097).fill(65));c.close();}}),()=>{}),/limit/);
  const actions=[]; const doc={body:{appendChild(){actions.push('append');}},createElement(){return {setAttribute(){},select(){actions.push('select');},remove(){actions.push('remove');}}},execCommand(){actions.push('exec');return false;}};
  assert.equal(await d.copyText('safe',{navigator:{clipboard:{writeText:async()=>{throw Error();}}},document:doc,manual:t=>actions.push(t)}),'manual'); assert.deepEqual(actions,['append','select','exec','remove','safe']);
  console.log('dashboard v2 helper tests passed');
})().catch(e=>{console.error(e);process.exitCode=1;});

(async function transportTests(){
  const jobs=new Map();let next=0;const requests=[];const snapshots=[];const statuses=[];
  let finishCalls, stream;
  const reply=(value,status=200)=>({ok:status>=200&&status<300,status,headers:{get:()=> '"s:1"'},json:async()=>value});
  const client=d.createClient({setTimeout:(fn,ms)=>{const id=++next;jobs.set(id,{fn,ms});return id;},clearTimeout:id=>jobs.delete(id),onSnapshot:s=>snapshots.push(s.version),onStatus:s=>statuses.push(s),fetch:async(path,init)=>{
    requests.push({path,init});
    if(path.endsWith('/session'))return reply({schemaVersion:2,sessionId:'s',version:0});
    if(path.endsWith('/calls'))return new Promise(resolve=>{finishCalls=resolve;});
    if(path.endsWith('/ack'))return reply(null,204);
    return {ok:true,status:200,body:new ReadableStream({start(c){stream=c;}})};
  }});
  const flush=()=>new Promise(resolve=>setImmediate(resolve));
  await client.pair('private-token');await flush();
  function run(ms){const entry=[...jobs].find(([,job])=>job.ms===ms);assert.ok(entry,'scheduled '+ms);jobs.delete(entry[0]);entry[1].fn();}
  run(250);await flush();
  stream.enqueue(new TextEncoder().encode('{"type":"authenticated","schemaVersion":2,"sessionId":"s","clientId":"c","version":1}\n'));
  await flush();
  assert.equal(requests.filter(r=>r.path.endsWith('/ack')).length,1,'ACK independent of blocked snapshot');
  assert.deepEqual(JSON.parse(requests.find(r=>r.path.endsWith('/ack')).init.body),{sessionId:'s',clientId:'c',version:1});
  assert.equal(requests.filter(r=>r.path.endsWith('/calls')).length,1,'one snapshot in flight');
  finishCalls(reply({schemaVersion:2,sessionId:'s',version:0,clearGeneration:0,calls:[]}));await flush();assert.deepEqual(snapshots,[],'late lower version ignored');
  run(250);await flush();finishCalls(reply({schemaVersion:2,sessionId:'s',version:1,clearGeneration:0,calls:[]}));await flush();assert.deepEqual(snapshots,[1]);
  client.refresh();run(250);await flush();assert.equal(requests.at(-1).init.headers['If-None-Match'],'"s:1"');
  finishCalls(reply(null,401));await flush();assert.equal(client.state.calls.length,0);assert.match(statuses.at(-1),/Pairing required/);assert.equal(jobs.size,1,'only aborted stream deadline pending until read settles');
  stream.close();await flush();assert.equal(jobs.size,0,'401 prevents reconnect');
  for(const r of requests){assert.equal(r.init.headers.Authorization,'Bearer private-token');assert.ok(!r.path.includes('private-token'));}
  console.log('dashboard v2 transport tests passed');
})().catch(e=>{console.error(e);process.exitCode=1;});

(async function pollingStatusTest(){
  const jobs=new Map();let next=0;const statuses=[];
  const client=d.createClient({setTimeout:(fn,ms)=>{const id=++next;jobs.set(id,{fn,ms});return id;},clearTimeout:id=>jobs.delete(id),onStatus:s=>statuses.push(s),fetch:async path=>{
    if(path.endsWith('/events'))return {ok:false,status:503};
    const payload=path.endsWith('/session')?{schemaVersion:2,sessionId:'p',version:0}:{schemaVersion:2,sessionId:'p',version:0,clearGeneration:0,calls:[]};
    return {ok:true,status:200,headers:{get:()=>null},json:async()=>payload};
  }});
  await client.pair('token');await new Promise(resolve=>setImmediate(resolve));
  const item=[...jobs].find(([,value])=>value.ms===250);jobs.delete(item[0]);item[1].fn();
  await new Promise(resolve=>setImmediate(resolve));
  assert.match(statuses.at(-1),/Polling/,'snapshot polling must not claim a live notification connection');
  client.stop();console.log('dashboard polling status test passed');
})().catch(e=>{console.error(e);process.exitCode=1;});

(async function pendingClearTest(){
  const jobs=new Map();let next=0,finishDelete;const views=[];
  const old={id:'old'};let snapshot={schemaVersion:2,sessionId:'clear',version:1,clearGeneration:0,calls:[old]};
  const reply=value=>({ok:true,status:200,headers:{get:()=>null},json:async()=>value});
  const client=d.createClient({setTimeout:(fn,ms)=>{const id=++next;jobs.set(id,{fn,ms});return id;},clearTimeout:id=>jobs.delete(id),onSnapshot:s=>views.push(s.calls.map(c=>c.id)),fetch:async(path,init)=>{
    if(path.endsWith('/session'))return reply({schemaVersion:2,sessionId:'clear',version:1});
    if(path.endsWith('/events'))return {ok:false,status:503};
    if(init.method==='DELETE')return new Promise(resolve=>finishDelete=resolve);
    return reply(snapshot);
  }});
  const flush=()=>new Promise(resolve=>setImmediate(resolve));
  function debounce(){const job=[...jobs].find(([,v])=>v.ms===250);assert.ok(job);jobs.delete(job[0]);job[1].fn();}
  await client.pair('token');await flush();debounce();await flush();assert.deepEqual(client.state.calls,[old]);
  client.refresh();const clearing=client.clear();debounce();await flush();
  assert.deepEqual(client.state.calls,[],'pending DELETE cannot restore old rows');
  snapshot={...snapshot,version:2,clearGeneration:1,calls:[]};finishDelete(reply(snapshot));await clearing;await flush();debounce();await flush();
  assert.equal(client.state.clearGeneration,1);assert.deepEqual(client.state.calls,[]);client.stop();
  console.log('dashboard pending-clear race test passed');
})().catch(e=>{console.error(e);process.exitCode=1;});
