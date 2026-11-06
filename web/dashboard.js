(function (root) {
  'use strict';
  const deniedHeaders = /^(authorization|proxy-authorization|cookie|set-cookie|x-api-key)$/i;
  const integer = n => Number.isSafeInteger(n) && n >= 0;
  const shellQuote = text => "'" + String(text).replace(/'/g, "'\"'\"'") + "'";
  function bodyCopy(body, warnings = []) {
    const reasons = [...warnings];
    if (!body || body.kind === 'absent') return {text:null, warnings:reasons};
    if (body.truncated) reasons.push('truncated');
    if (body.omissionReason) reasons.push(body.omissionReason);
    if (!['json','text'].includes(body.kind)) reasons.push(body.kind);
    const incomplete = reasons.length > 0;
    return {text:incomplete ? null : body.kind === 'json' ? JSON.stringify(body.content, null, 2) : body.content, warnings:[...new Set(reasons)]};
  }
  function curlForCall(call) {
    const r = call.request;
    const warnings = [...(r.captureWarnings || [])];
    if (call.incompleteRequest) warnings.push('missingRequest');
    const parts = ['curl', '-X', shellQuote(r.method), '--url', shellQuote(r.url)];
    for (const [name, values] of Object.entries(r.headers || {})) {
      if (deniedHeaders.test(name) || values.some(v => /\[REDACTED\]|[\r\n]/.test(v))) { warnings.push('headerOmitted'); continue; }
      for (const value of values) parts.push('-H', shellQuote(name + ': ' + value));
    }
    const captured = bodyCopy(r.body, warnings);
    if (captured.text !== null) parts.push('--data-raw',shellQuote(captured.text));
    return {text:parts.join(' '), warnings:[...new Set([...warnings,...captured.warnings])]};
  }
  function formatDuration(call) {
    return call.state==='pending' || !Number.isFinite(call.durationMicros) || call.durationMicros<0 ? '—' : (call.durationMicros/1000).toFixed(2).replace(/\.?0+$/,'')+' ms';
  }
  function formatCapturedSize(call) {
    const size=call.response?.body?.knownSizeBytes;
    if(!Number.isFinite(size) || size<0) return 'Unknown';
    return size<1024 ? size+' B' : (size/1024).toFixed(1)+' KiB';
  }
  function createViewState() {return {paused:false,resumePending:false,frozen:null,selected:new Set(),detail:null};}
  function snapshotOf(state,calls=state.calls) {return {schemaVersion:2,sessionId:state.sessionId,version:state.version,clearGeneration:state.clearGeneration,calls};}
  function pauseView(view,state) {view.paused=true;view.frozen=snapshotOf(state,[...state.calls]);}
  function visibleSnapshot(state,view) {return view.paused && view.frozen ? view.frozen : snapshotOf(state);}
  function invalidateView(view,state) {view.selected.clear();view.detail=null;if(view.paused)view.frozen=snapshotOf(state,[]);}
  function waitingCount(state,view) {if(!view.paused)return 0;const frozen=new Set((view.frozen?.calls||[]).map(c=>c.id));return state.calls.filter(c=>!frozen.has(c.id)).length;}
  function exportCall(call) {
    const output=JSON.parse(JSON.stringify(call));
    for(const part of [output.request,output.response]) {
      if(!part)continue;
      for(const name of Object.keys(part.headers||{})) if(deniedHeaders.test(name)) {delete part.headers[name];(part.captureWarnings||=[]).push('headerOmitted');}
      const body=part.body;if(!body)continue;
      const captured=bodyCopy(body,part.captureWarnings||[]);
      if(captured.text===null && body.kind!=='absent') {
        body.content=null;
        body.omissionReason=body.omissionReason||captured.warnings[0]||body.kind;
        if(['json','text'].includes(body.kind))body.kind='omitted';
      }
    }
    return output;
  }
  function buildJsonExport(snapshot,calls) {
    if(!calls.length)throw Error('No calls to export. Select calls or change the filter.');
    return {...snapshotOf(snapshot,calls.map(exportCall)),_cote:{capturePoint:'dio',wireExact:false,comment:'Sanitized capture at Dio interception; not byte-exact network traffic.'}};
  }
  function buildHarExport(snapshot,calls) {
    if(!calls.length)throw Error('No calls to export. Select calls or change the filter.');
    const entries=[],skipped=[];
    const headers=values=>Object.entries(values||{}).flatMap(([name,list])=>deniedHeaders.test(name)?[]:list.map(value=>({name,value})));
    for(const original of calls) {
      let url;
      try {url=new URL(original.request.url);if(!['http:','https:'].includes(url.protocol))throw Error();}
      catch(_){skipped.push({id:original.id,reason:'URL is not an absolute HTTP URL'});continue;}
      if(!original.request.startedAt || !Number.isFinite(Date.parse(original.request.startedAt))) {skipped.push({id:original.id,reason:'Request start is unknown'});continue;}
      if(!Number.isFinite(original.durationMicros) || original.durationMicros<0 || original.state==='pending') {skipped.push({id:original.id,reason:'Observed duration is unknown'});continue;}
      const call=exportCall(original),request=call.request,response=call.response;
      url.hash='';url.username='';url.password='';
      const requestBody=bodyCopy(request.body,request.captureWarnings||[]),responseBody=bodyCopy(response?.body,response?.captureWarnings||[]);
      const mime=part=>part?.body?.contentType||part?.headers?.['content-type']?.[0]||'';
      const harRequest={method:request.method,url:url.href,httpVersion:'',cookies:[],headers:headers(request.headers),queryString:[...url.searchParams].map(([name,value])=>({name,value})),headersSize:-1,bodySize:-1};
      if(requestBody.text!==null)harRequest.postData={mimeType:mime(request),text:requestBody.text};
      const known=response?.body?.knownSizeBytes;
      const content={size:Number.isFinite(known)&&known>=0?known:-1,mimeType:mime(response)};
      if(responseBody.text!==null)content.text=responseBody.text;
      entries.push({startedDateTime:request.startedAt,time:call.durationMicros/1000,request:harRequest,response:{status:response?.statusCode??0,statusText:'',httpVersion:'',cookies:[],headers:headers(response?.headers),content,redirectURL:'',headersSize:-1,bodySize:-1},cache:{},timings:{blocked:-1,dns:-1,connect:-1,send:0,wait:call.durationMicros/1000,receive:0,ssl:-1},comment:'Synthetic HAR timing: wait is observed Dio total, not measured TTFB; network phases are unavailable. Sizes are sanitized captured bytes, not wire bytes.',_cote:{capturePoint:'dio',observedDurationMicros:call.durationMicros,timingAllocation:'syntheticWait',callId:call.id,state:call.state,capturedSizeBytes:known??null,requestBodyReasons:requestBody.warnings,responseBodyReasons:responseBody.warnings}});
    }
    return {har:{log:{version:'1.2',creator:{name:'CoTe Network Logger',version:'2'},entries,comment:'Sanitized Dio capture; not byte-exact network traffic.'}},skipped};
  }
  function createState() { return {sessionId:null,version:-1,clearGeneration:-1,calls:[],selected:null,epoch:0}; }
  function applySnapshot(state, snapshot) {
    if (snapshot.schemaVersion !== 2 || typeof snapshot.sessionId !== 'string' || !integer(snapshot.version) || !integer(snapshot.clearGeneration) || !Array.isArray(snapshot.calls)) throw Error('Invalid snapshot');
    if (state.sessionId === snapshot.sessionId && (snapshot.version < state.version || snapshot.clearGeneration < state.clearGeneration)) return false;
    if (state.sessionId !== snapshot.sessionId || snapshot.clearGeneration > state.clearGeneration) { state.selected=null; state.epoch++; }
    Object.assign(state,{sessionId:snapshot.sessionId,version:snapshot.version,clearGeneration:snapshot.clearGeneration,calls:snapshot.calls});
    if (!state.calls.some(c=>c.id===state.selected)) state.selected=null;
    return true;
  }
  // Bound raw UTF-8 bytes before decoding, including lines split across chunks.
  async function readNotifications(stream, receive) {
    const reader=stream.getReader(); const line=new Uint8Array(4096); let length=0;
    try {
      for (;;) {
        const {value,done}=await reader.read();
        if (done) { if(length) throw Error('Incomplete notification'); break; }
        for (const byte of value) {
          if (byte===10) { if(length) receive(JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(line.subarray(0,length)))); length=0; }
          else { if(length===line.length) throw Error('Notification line limit'); line[length++]=byte; }
        }
      }
    } finally { await reader.cancel().catch(()=>{}); reader.releaseLock(); }
  }
  async function copyText(text, env) {
    const valid=env.valid || (()=>true);
    if(!valid()) return 'cancelled';
    try { if(env.navigator.clipboard) { await env.navigator.clipboard.writeText(text); return valid() ? 'copied' : 'cancelled'; } } catch (_) { /* Plain HTTP may deny clipboard. */ }
    if(!valid()) return 'cancelled';
    const area=env.document.createElement('textarea'); area.value=text; area.className='copy-fallback'; area.setAttribute('readonly',''); env.document.body.appendChild(area); area.select();
    let copied=false; try { copied=env.document.execCommand('copy'); } catch (_) { /* Manual fallback below. */ } finally { area.remove(); }
    if(!valid()) return 'cancelled';
    if(copied) return 'copied'; env.manual(text); return 'manual';
  }
  function createClient(options) {
    const fetcher=options.fetch;
    const later=options.setTimeout || setTimeout, cancel=options.clearTimeout || clearTimeout;
    const state=createState(); let token=null, generation=0, flight=false, dirty=false, etag=null, timer=null, retry=null, streamAbort=null, snapshotAbort=null, failures=0, expectedSession=null, expectedVersion=0, streamLive=false, clearing=false;
    const status=s=>options.onStatus?.(s);
    function invalidate() { state.calls=[]; state.selected=null; state.epoch++; options.onInvalidate?.(); }
    function stop() { generation++; token=null; streamLive=false; clearing=false; cancel(timer); cancel(retry); timer=retry=null; streamAbort?.abort(); snapshotAbort?.abort(); etag=null; dirty=false; invalidate(); }
    function unauthorized() { stop(); status('Pairing required — authorization expired.'); }
    async function request(path, init={}) {
      const auth=token, requestGeneration=generation; const result=await fetcher(path,{...init,cache:'no-store',headers:{...(init.headers||{}),Authorization:'Bearer '+auth}});
      if(result.status===401 && auth===token && requestGeneration===generation) unauthorized();
      if(!result.ok && result.status!==304) throw Error('Request failed');
      return result;
    }
    function schedule() { dirty=true; if(!token || clearing || flight || timer!==null) return; timer=later(()=>{timer=null; refresh();},250); }
    async function refresh() {
      if(!token || clearing || flight) {dirty=true;return;}
      flight=true; dirty=false; const own=generation, epochAtStart=state.epoch; snapshotAbort=new AbortController();
      try {
        const res=await request('/api/v2/calls',{signal:snapshotAbort.signal,headers:etag ? {'If-None-Match':etag} : {}});
        if(own!==generation) return;
        if(res.status!==304) {
          const snapshot=await res.json(); if(own!==generation) return;
          if(epochAtStart!==state.epoch) {dirty=true;return;}
          if(expectedSession && snapshot.sessionId!==expectedSession || snapshot.version<expectedVersion) { dirty=true; return; }
          const epoch=state.epoch;
          if(applySnapshot(state,snapshot)) { etag=res.headers.get('etag'); if(epoch!==state.epoch) options.onInvalidate?.(); options.onSnapshot?.(state); }
        }
        status(streamLive ? 'Live' : 'Polling — notifications disconnected.');
        options.onSynced?.(state);
      } catch (_) { if(own===generation && token) status('Offline — showing stale captured calls.'); }
      finally { flight=false; if(dirty && token) schedule(); }
    }
    function reconnect(own, normal) {
      if(own!==generation || !token) return;
      const wait=normal ? 0 : [1000,2000,4000,8000,16000,30000][Math.min(failures++,5)];
      if(!normal) status('Offline — showing stale captured calls. Retrying.');
      retry=later(()=>{retry=null; schedule(); events(own);},wait);
    }
    async function events(own) {
      streamAbort=new AbortController(); const controller=streamAbort;
      // Server closes at 30 seconds. A slightly longer client deadline also bounds stalled peers.
      const deadline=later(()=>controller.abort(),35000); let authenticated=null;
      try {
        const response=await request('/api/v2/events',{signal:controller.signal}); if(own!==generation) return;
        schedule();
        await readNotifications(response.body,line=>{
          if(own!==generation) return;
          if(!integer(line.version) || typeof line.sessionId!=='string') throw Error('Invalid notification');
          if(!authenticated) {
            if(line.type!=='authenticated' || line.schemaVersion!==2 || typeof line.clientId!=='string') throw Error('Missing authentication');
            authenticated=line; failures=0; streamLive=true;
            if(expectedSession && expectedSession!==line.sessionId) {invalidate(); etag=null; expectedVersion=0;}
            expectedSession=line.sessionId;
          } else if(line.type!=='changed' || line.sessionId!==authenticated.sessionId || line.version<authenticated.version) throw Error('Invalid notification');
          expectedVersion=Math.max(expectedVersion,line.version); authenticated.version=line.version;
          const body=JSON.stringify({sessionId:line.sessionId,clientId:authenticated.clientId,version:line.version});
          if(new TextEncoder().encode(body).length>512) throw Error('ACK limit');
          // ACK never waits for a snapshot fetch or rendering.
          request('/api/v2/events/ack',{method:'POST',headers:{'Content-Type':'application/json'},body}).catch(()=>{if(own===generation) controller.abort();});
          schedule();
        });
        if(!authenticated) throw Error('Missing authentication');
        if(own===generation) streamLive=false;
        reconnect(own,true);
      } catch (_) { if(own===generation) streamLive=false; reconnect(own,false); } finally {cancel(deadline);}
    }
    async function pair(value) {
      stop(); token=value || null; expectedSession=null; expectedVersion=0; state.sessionId=null; state.version=-1; state.clearGeneration=-1; failures=0;
      if(!token) {status('Pairing required — open a pairing link from your app.');return;}
      const own=generation;
      try {
        const response=await request('/api/v2/session'); const session=await response.json(); if(own!==generation) return;
        if(session.schemaVersion!==2 || typeof session.sessionId!=='string' || !integer(session.version)) throw Error('Invalid session');
        expectedSession=session.sessionId; expectedVersion=session.version; schedule(); events(own);
      } catch (_) { if(own===generation && token) { status('Offline — retrying connection.'); retry=later(()=>{if(own===generation) {schedule();events(own);}},1000); } }
    }
    async function clear() {
      if(!token || clearing) return; clearing=true; invalidate(); options.onSnapshot?.(state); const own=generation; etag=null;
      try { const res=await request('/api/v2/calls',{method:'DELETE'}); const result=await res.json(); if(own!==generation) return;
        if(result.sessionId===expectedSession && integer(result.clearGeneration) && integer(result.version)) {state.clearGeneration=Math.max(state.clearGeneration,result.clearGeneration); expectedVersion=Math.max(expectedVersion,result.version);}
        schedule();
      } catch (_) { if(own===generation && token) status('Clear could not be confirmed — reconnect to reconcile.'); }
      finally { if(own===generation) {clearing=false; if(token) schedule();} }
    }
    return {pair,refresh:schedule,clear,stop,state};
  }
  function mount(win) {
    const doc=win.document, el=id=>doc.getElementById(id), view=createViewState();let pendingExport=null;
    function node(tag,text,cls) { const n=doc.createElement(tag); if(text!==undefined) n.textContent=text; if(cls)n.className=cls; return n; }
    const dialog=el('copyDialog');
    function closeCopy() { el('copyText').value=''; if(dialog.open) dialog.close(); }
    function notice(text) {el('notice').textContent=text;}
    const client=createClient({fetch:win.fetch.bind(win),onStatus:text=>{el('wsText').textContent=text;el('wsText').classList.toggle('live',text==='Live');el('wsDot').classList.toggle('live',text==='Live');notice(text==='Live' ? 'Connected. Captured at Dio; this may differ from bytes sent over the network.' : text);if(text.startsWith('Offline')&&view.resumePending){view.resumePending=false;updatePause();}},onInvalidate:()=>{closeCopy();pendingExport=null;if(el('exportDialog').open)el('exportDialog').close();invalidateView(view,client.state);render();},onSnapshot:()=>{if(view.paused)updatePause();else render();},onSynced:()=>{if(view.resumePending){view.resumePending=false;view.paused=false;view.frozen=null;render();}}});
    function copy(value, warnings=[]) {
      const epoch=client.state.epoch;
      notice(warnings.length ? 'Incomplete capture: '+warnings.join(', ') : 'Captured at Dio; this may differ from bytes sent over the network.');
      return copyText(value,{navigator:win.navigator,document:doc,valid:()=>client.state.epoch===epoch,manual:text=>{el('copyText').value=text;dialog.showModal();el('copyText').select();}}).then(result=>{if(result==='copied') notice((warnings.length?'Incomplete capture: '+warnings.join(', ')+'. ':'')+'Copied.');});
    }
    function button(label,action) {const b=node('button',label,'copy-btn section-copy');b.type='button';b.addEventListener('click',action);return b;}
    function section(parent,title,value,copyValue,warnings=[]) {
      const details=node('details',undefined,'expandable-section');const summary=node('summary',title,'expandable-header');details.appendChild(summary);
      const content=node('div',undefined,'json-container');content.appendChild(node('pre',value,'json-content'));
      if(warnings.length) content.appendChild(node('p','Incomplete capture: '+warnings.join(', ')));
      if(copyValue!==null) content.appendChild(button('Copy '+title,()=>copy(copyValue,warnings)));
      details.appendChild(content);parent.appendChild(details);
    }
    function bodySection(parent,title,body,warnings) {
      const result=bodyCopy(body,warnings);
      const label=body ? [body.kind,body.contentType,body.truncated?'truncated':null,body.omissionReason].filter(Boolean).join(' · ') : 'absent';
      const visible=body && ['json','text'].includes(body.kind) ? (body.kind==='json'?JSON.stringify(body.content,null,2):body.content) : JSON.stringify(body?.summary || {},null,2);
      section(parent,title+' — '+label,visible,result.text,result.warnings);
    }
    function filteredCalls(calls) {
      const search=el('searchInput').value.toLowerCase(),method=el('methodFilter').value,status=el('statusFilter').value;
      return calls.filter(c=>{const code=c.response?.statusCode;return (!method||c.request.method===method)&&(!status||String(code).startsWith(status[0]))&&(!search||[c.request.url,c.request.method,code,c.state].join(' ').toLowerCase().includes(search));});
    }
    function updatePause() {
      el('pauseButton').textContent=view.resumePending?'Resuming…':view.paused?'Resume':'Pause';el('pauseButton').disabled=view.resumePending;
      el('waitingCount').textContent=view.paused?waitingCount(client.state,view)+' calls waiting':'';
    }
    function download(value,extension) {
      const blob=new win.Blob([JSON.stringify(value,null,2)],{type:extension==='har'?'application/json':'application/json'}),url=win.URL.createObjectURL(blob);
      const link=doc.createElement('a');link.href=url;link.download='cote-dio-capture-'+new Date().toISOString().replace(/[:.]/g,'-')+'.'+extension;doc.body.appendChild(link);link.click();link.remove();win.setTimeout(()=>win.URL.revokeObjectURL(url),1000);
    }
    function exportCalls(format) {
      const snapshot=visibleSnapshot(client.state,view);
      const calls=el('exportScope').value==='selected'?snapshot.calls.filter(c=>view.selected.has(c.id)):filteredCalls(snapshot.calls);
      try {
        if(format==='json'){download(buildJsonExport(snapshot,calls),'json');notice('Exported sanitized Dio capture; not wire-exact network traffic.');return;}
        const result=buildHarExport(snapshot,calls);
        if(!result.har.log.entries.length){notice('No eligible HAR calls. '+result.skipped.map(s=>s.reason).join('; '));return;}
        if(result.skipped.length){pendingExport={har:result.har,epoch:client.state.epoch};el('exportReasons').textContent=result.skipped.length+' skipped: '+result.skipped.map(s=>s.id+' — '+s.reason).join('; ');el('exportDialog').showModal();return;}
        download(result.har,'har');notice('Exported sanitized Dio capture; network phases and wire sizes are unknown.');
      }catch(error){notice(error.message);}
    }
    function render() {
      const state=visibleSnapshot(client.state,view), tbody=el('logsTableBody');tbody.replaceChildren();updatePause();
      const visibleIds=new Set(state.calls.map(c=>c.id));for(const id of view.selected)if(!visibleIds.has(id))view.selected.delete(id);
      if(!visibleIds.has(view.detail))view.detail=null;
      el('selectionCount').textContent=view.selected.size+' selected';
      const calls=filteredCalls(state.calls);
      el('selectFiltered').checked=calls.length>0&&calls.every(c=>view.selected.has(c.id));
      el('logCount').textContent=state.calls.length;el('requestCount').textContent=state.calls.length;el('errorCount').textContent=state.calls.filter(c=>c.error).length;el('lastUpdated').textContent=new Date().toLocaleTimeString();
      if(!calls.length) {const row=node('tr');const cell=node('td','No captured calls match.','no-logs');cell.colSpan=9;row.appendChild(cell);tbody.appendChild(row);}
      for(const call of calls) {
        const row=node('tr'); const expanded=view.detail===call.id;
        const toggle=button(expanded?'−':'+',()=>{view.detail=expanded?null:call.id;render();});toggle.setAttribute('aria-label','Details for '+call.request.method+' '+call.request.url);toggle.setAttribute('aria-expanded',String(expanded));
        const selection=node('td'),checkbox=node('input');checkbox.type='checkbox';checkbox.checked=view.selected.has(call.id);checkbox.setAttribute('aria-label','Select call '+call.id);checkbox.addEventListener('change',()=>{if(checkbox.checked)view.selected.add(call.id);else view.selected.delete(call.id);el('exportScope').value='selected';render();});selection.appendChild(checkbox);row.appendChild(selection);
        const first=node('td'); first.appendChild(toggle);row.appendChild(first);
        const values=[call.state,call.request.method,call.request.url,call.response?.statusCode ?? '—',formatDuration(call),formatCapturedSize(call),call.request.startedAt || 'Unknown start'];
        values.forEach((v,i)=>{const cell=node('td',String(v),i===2?'url-cell':i===6?'timestamp':undefined); if(i===2)cell.title=v;row.appendChild(cell);});tbody.appendChild(row);
        if(!expanded)continue;
        const detailRow=node('tr',undefined,'details-row expanded'),cell=node('td',undefined,'details-cell');cell.colSpan=9;const panel=node('div',undefined,'details-content');
        panel.appendChild(node('h3',call.request.method+' '+call.request.url));
        if(call.error)panel.appendChild(node('p',call.error.kind+': '+call.error.description));
        if(call.incompleteRequest)panel.appendChild(node('p','Incomplete request: the start was not observed.'));
        const curl=curlForCall(call);panel.appendChild(button('Copy cURL',()=>copy(curl.text,curl.warnings)));if(curl.warnings.length)panel.appendChild(node('p','Incomplete cURL: '+curl.warnings.join(', ')));
        section(panel,'Request headers',JSON.stringify(call.request.headers,null,2),JSON.stringify(call.request.headers,null,2),call.request.captureWarnings||[]);
        bodySection(panel,'Request body',call.request.body,call.request.captureWarnings||[]);
        if(call.response) {section(panel,'Response headers',JSON.stringify(call.response.headers,null,2),JSON.stringify(call.response.headers,null,2),call.response.captureWarnings||[]);bodySection(panel,'Response body',call.response.body,call.response.captureWarnings||[]);}
        cell.appendChild(panel);detailRow.appendChild(cell);tbody.appendChild(detailRow);
      }
    }
    for(const id of ['searchInput','methodFilter','statusFilter']) el(id).addEventListener(id==='searchInput'?'input':'change',render);
    el('pauseButton').addEventListener('click',()=>{if(view.paused){view.resumePending=true;updatePause();client.refresh();}else{pauseView(view,client.state);render();}});
    el('selectFiltered').addEventListener('change',()=>{for(const call of filteredCalls(visibleSnapshot(client.state,view).calls)){if(el('selectFiltered').checked)view.selected.add(call.id);else view.selected.delete(call.id);}el('exportScope').value='selected';render();});
    el('exportJson').addEventListener('click',()=>exportCalls('json'));el('exportHar').addEventListener('click',()=>exportCalls('har'));
    el('exportCancel').addEventListener('click',()=>{pendingExport=null;el('exportDialog').close();});
    el('exportConfirm').addEventListener('click',()=>{if(pendingExport&&pendingExport.epoch===client.state.epoch)download(pendingExport.har,'har');pendingExport=null;el('exportDialog').close();});
    el('exportDialog').addEventListener('close',()=>{pendingExport=null;});
    el('refreshButton').addEventListener('click',()=>client.refresh());el('clearButton').addEventListener('click',()=>client.clear());el('copyClose').addEventListener('click',closeCopy);dialog.addEventListener('close',()=>{el('copyText').value='';});
    function pairing() {const hash=win.location.hash;win.history.replaceState(null,'',win.location.pathname+win.location.search);const value=new URLSearchParams(hash.slice(1)).get('token');client.pair(value);}
    win.addEventListener('hashchange',pairing);win.addEventListener('pagehide',()=>client.stop());pairing();render();return client;
  }
  const api={shellQuote,bodyCopy,curlForCall,createState,applySnapshot,readNotifications,copyText,createClient,mount,formatDuration,formatCapturedSize,createViewState,pauseView,visibleSnapshot,invalidateView,waitingCount,buildJsonExport,buildHarExport};
  if(typeof module!=='undefined' && module.exports) module.exports=api;
  else {root.CoteDashboard=api;mount(root);}
})(typeof window!=='undefined'?window:globalThis);
