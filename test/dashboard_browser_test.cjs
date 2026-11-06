'use strict';
const assert=require('node:assert/strict');
const http=require('node:http');
const fs=require('node:fs');
const path=require('node:path');
const {chromium,webkit}=require('playwright');
const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const hostile='</script><img src=x onerror="window.__xss=1">';
function call(id,url='https://example.test/'+hostile){
  return {id,state:'completed',revision:2,incompleteRequest:false,durationMicros:12500,observedAt:'2026-11-06T00:00:00.000Z',endedAt:'2026-11-06T00:00:00.012500Z',error:null,
    request:{method:'POST',url,headers:{'content-type':['application/json']},body:{kind:'json',content:{hostile,ok:false},knownSizeBytes:80,truncated:false,omissionReason:null,summary:null,contentType:'application/json'},startedAt:'2026-11-06T00:00:00.000Z',captureWarnings:[]},
    response:{statusCode:200,headers:{},body:{kind:'json',content:false,knownSizeBytes:5,truncated:false,omissionReason:null,summary:null,contentType:'application/json'},endedAt:'2026-11-06T00:00:00.012500Z',captureWarnings:[]}};
}
async function harness(){
  let snapshot={schemaVersion:2,sessionId:'session-1',version:1,clearGeneration:0,calls:[call('first')]};
  let reject=false,client=0,delayNext=false,pending=null;
  const events=new Set(),requests=[];
  const send=(res,value,status=200)=>{res.writeHead(status,{'content-type':'application/json'});res.end(value===null?'':JSON.stringify(value));};
  const server=http.createServer((req,res)=>{
    requests.push({path:req.url,auth:req.headers.authorization,method:req.method});
    res.setHeader('cache-control','no-store');
    res.setHeader('content-security-policy',"default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'");
    if(['/','/dashboard.js','/dashboard.css'].includes(req.url)){
      const file=req.url==='/'?'dashboard.html':req.url.slice(1);
      res.setHeader('content-type',file.endsWith('js')?'text/javascript':file.endsWith('css')?'text/css':'text/html');
      return res.end(fs.readFileSync(path.join(__dirname,'../web',file)));
    }
    if(reject||req.headers.authorization!=='Bearer browser-test-token')return send(res,{schemaVersion:2,error:{code:'unauthorized'}},401);
    if(req.url==='/api/v2/session')return send(res,{...snapshot,calls:undefined});
    if(req.url==='/api/v2/events'){
      res.writeHead(200,{'content-type':'application/x-ndjson'});
      res.write(JSON.stringify({type:'authenticated',schemaVersion:2,sessionId:snapshot.sessionId,clientId:'client-'+(++client),version:snapshot.version})+'\n');
      events.add(res);res.on('close',()=>events.delete(res));return;
    }
    if(req.url==='/api/v2/events/ack'){
      let body='';req.on('data',chunk=>body+=chunk);req.on('end',()=>{assert.ok(Buffer.byteLength(body)<=512);const ack=JSON.parse(body);assert.deepEqual(Object.keys(ack).sort(),['clientId','sessionId','version']);res.writeHead(204);res.end();});return;
    }
    if(req.url==='/api/v2/calls'&&req.method==='DELETE'){
      snapshot={...snapshot,version:snapshot.version+1,clearGeneration:snapshot.clearGeneration+1,calls:[]};notify();return send(res,{...snapshot,calls:undefined});
    }
    if(req.url==='/api/v2/calls'){
      const captured=JSON.parse(JSON.stringify(snapshot));
      const reply=()=>{if(res.destroyed)return;res.setHeader('etag','"'+captured.sessionId+':'+captured.version+'"');if(req.headers['if-none-match']===res.getHeader('etag')){res.writeHead(304);res.end();}else send(res,captured);};
      if(delayNext){delayNext=false;pending=reply;return;}reply();return;
    }
    send(res,{},404);
  });
  function notify(){for(const res of events)res.write(JSON.stringify({type:'changed',sessionId:snapshot.sessionId,version:snapshot.version})+'\n');}
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  return {url:'http://127.0.0.1:'+server.address().port,requests,
    update(value){snapshot={...snapshot,...value};notify();},
    delay(){delayNext=true;},get pending(){return pending!==null;},release(){const fn=pending;pending=null;fn();},
    eof(){for(const res of [...events])res.end();},unauthorized(){reject=true;notify();},authorize(){reject=false;},
    async close(){for(const res of events)res.end();server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}};
}
async function until(predicate,message){for(let i=0;i<100;i++){if(predicate())return;await wait(20);}throw Error(message);}
(async()=>{
  for(const [name,engine]of Object.entries({chromium,webkit})){
    const h=await harness();let browser;
    try{
      browser=await engine.launch({headless:true});
      const page=await browser.newPage({viewport:{width:1400,height:900}});const errors=[];page.on('pageerror',error=>errors.push(error.message));
      await page.addInitScript(()=>{window.__violations=[];document.addEventListener('securitypolicyviolation',e=>window.__violations.push({directive:e.violatedDirective,source:e.sourceFile,line:e.lineNumber,blocked:e.blockedURI,sample:e.sample}));Object.defineProperty(navigator,'clipboard',{configurable:true,value:{writeText:async()=>{throw Error('denied');}}});document.execCommand=()=>false;});
      await page.goto(h.url);
      assert.equal(h.requests.filter(r=>r.path.startsWith('/api/')).length,0,'unpaired shell requests no data');
      await page.goto(h.url+'/#token=browser-test-token');
      await page.waitForFunction(()=>document.getElementById('logCount').textContent==='1');
      assert.equal(new URL(page.url()).hash,'','fragment removed');
      assert.doesNotMatch(await page.locator('#notice').textContent(),/pairing link/i,'connected banner must not ask for pairing');
      assert.equal(await page.evaluate(()=>localStorage.length+sessionStorage.length),0);
      assert.equal(await page.evaluate(()=>window.__xss),undefined);
      await page.getByRole('button',{name:/Details for/}).click();
      await page.getByRole('button',{name:'Copy cURL',exact:true}).click();
      await page.waitForFunction(()=>document.getElementById('copyDialog').open);
      assert.match(await page.locator('#copyText').inputValue(),/--data-raw/);
      assert.match(await page.locator('#copyText').inputValue(),/false/);
      assert.equal(await page.locator('#logsTableBody img').count(),0,'hostile markup stays text');
      h.update({version:2,clearGeneration:1,calls:[call('after-clear','https://example.test/after-clear')]});
      await page.waitForFunction(()=>document.getElementById('logsTableBody').textContent.includes('after-clear'));
      assert.equal(await page.locator('#copyDialog').evaluate(el=>el.open),false,'remote clear invalidates copy');
      assert.equal(await page.locator('.details-row').count(),0,'remote clear invalidates details');
      h.delay();h.update({version:3,calls:[call('stale','https://example.test/stale')]});
      await until(()=>h.pending,'delayed snapshot not requested');
      h.update({version:4,calls:[call('latest','https://example.test/latest')]});h.release();
      await page.waitForFunction(()=>document.getElementById('logsTableBody').textContent.includes('/latest'));
      assert.doesNotMatch(await page.locator('#logsTableBody').textContent(),/\/stale/);
      const before=h.requests.filter(r=>r.path==='/api/v2/events').length;h.eof();
      await until(()=>h.requests.filter(r=>r.path==='/api/v2/events').length>before,'normal EOF did not reconnect');
      await page.setViewportSize({width:390,height:844});
      const overflow=await page.evaluate(()=>{const bounds=document.querySelector('.controls').getBoundingClientRect();return [...document.querySelectorAll('.controls > *, .stat-item')].filter(el=>{const r=el.getBoundingClientRect();return r.left<bounds.left-1||r.right>bounds.right+1||r.right>innerWidth;}).map(el=>el.id||el.className);});
      assert.deepEqual(overflow,[],'mobile toolbar and stats fit without clipping');
      h.unauthorized();
      await page.waitForFunction(()=>document.getElementById('wsText').textContent.includes('authorization expired'));
      const stopped=h.requests.length;await wait(1200);assert.equal(h.requests.length,stopped,'401 stops retries');
      assert.deepEqual(errors,[]);assert.deepEqual(await page.evaluate(()=>window.__violations),[],'strict CSP works');
      for(const req of h.requests.filter(r=>r.path.startsWith('/api/'))){assert.equal(req.auth,'Bearer browser-test-token');assert.ok(!req.path.includes('browser-test-token'));}
      console.log(name+': pairing, CSP/XSS, copy fallback, remote clear, stale snapshot, EOF reconnect and 401 checks passed');
      // Screenshot preparation injects inline styles in Playwright WebKit.
      // Keep artifact acquisition on a separate page AFTER the strict CSP
      // functional assertions, so app violations cannot be hidden by filtering.
      h.authorize();
      const visual=await browser.newPage({viewport:{width:1400,height:900}});
      await visual.addInitScript(()=>{Object.defineProperty(navigator,'clipboard',{configurable:true,value:{writeText:async()=>{throw Error('denied');}}});document.execCommand=()=>false;});
      await visual.goto(h.url+'/#token=browser-test-token');
      await visual.waitForFunction(()=>document.getElementById('logCount').textContent==='1');
      await visual.screenshot({path:'/tmp/cote-v2-dashboard-normal-'+name+'.png',fullPage:true,caret:'initial'});
      await visual.setViewportSize({width:390,height:844});
      await visual.screenshot({path:'/tmp/cote-v2-dashboard-mobile-'+name+'.png',fullPage:true,caret:'initial'});
      await visual.setViewportSize({width:1400,height:900});
      await visual.getByRole('button',{name:/Details for/}).click();
      await visual.getByRole('button',{name:'Copy cURL',exact:true}).click();
      await visual.waitForFunction(()=>document.getElementById('copyDialog').open);
      await visual.screenshot({path:'/tmp/cote-v2-dashboard-'+name+'.png',fullPage:true,caret:'initial'});
      await visual.close();
    }finally{if(browser)await browser.close();await h.close();}
  }
})().catch(error=>{console.error(error);process.exitCode=1;});
