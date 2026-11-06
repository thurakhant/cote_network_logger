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
    const doc=win.document, el=id=>doc.getElementById(id);
    function node(tag,text,cls) { const n=doc.createElement(tag); if(text!==undefined) n.textContent=text; if(cls)n.className=cls; return n; }
    const dialog=el('copyDialog');
    function closeCopy() { el('copyText').value=''; if(dialog.open) dialog.close(); }
    function notice(text) {el('notice').textContent=text;}
    const client=createClient({fetch:win.fetch.bind(win),onStatus:text=>{el('wsText').textContent=text;el('wsText').classList.toggle('live',text==='Live');el('wsDot').classList.toggle('live',text==='Live');notice(text==='Live' ? 'Connected. Captured at Dio; this may differ from bytes sent over the network.' : text);},onInvalidate:()=>{closeCopy();render();},onSnapshot:render});
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
    function render() {
      const state=client.state, tbody=el('logsTableBody');tbody.replaceChildren();
      const search=el('searchInput').value.toLowerCase(),method=el('methodFilter').value,status=el('statusFilter').value;
      const calls=state.calls.filter(c=>{const code=c.response?.statusCode;return (!method||c.request.method===method)&&(!status||String(code).startsWith(status[0]))&&(!search||[c.request.url,c.request.method,code,c.state].join(' ').toLowerCase().includes(search));});
      el('logCount').textContent=state.calls.length;el('requestCount').textContent=state.calls.length;el('errorCount').textContent=state.calls.filter(c=>c.error).length;el('lastUpdated').textContent=new Date().toLocaleTimeString();
      if(!calls.length) {const row=node('tr');const cell=node('td','No captured calls match.','no-logs');cell.colSpan=6;row.appendChild(cell);tbody.appendChild(row);}
      for(const call of calls) {
        const row=node('tr'); const expanded=state.selected===call.id;
        const toggle=button(expanded?'−':'+',()=>{state.selected=expanded?null:call.id;render();});toggle.setAttribute('aria-label','Details for '+call.request.method+' '+call.request.url);toggle.setAttribute('aria-expanded',String(expanded));
        const first=node('td'); first.appendChild(toggle);row.appendChild(first);
        const values=[call.state,call.request.method,call.request.url,call.response?.statusCode ?? '—',call.request.startedAt || 'Unknown start'];
        values.forEach((v,i)=>{const cell=node('td',String(v),i===2?'url-cell':i===4?'timestamp':undefined); if(i===2)cell.title=v;row.appendChild(cell);});tbody.appendChild(row);
        if(!expanded)continue;
        const detailRow=node('tr',undefined,'details-row expanded'),cell=node('td',undefined,'details-cell');cell.colSpan=6;const panel=node('div',undefined,'details-content');
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
    el('refreshButton').addEventListener('click',()=>client.refresh());el('clearButton').addEventListener('click',()=>client.clear());el('copyClose').addEventListener('click',closeCopy);dialog.addEventListener('close',()=>{el('copyText').value='';});
    function pairing() {const hash=win.location.hash;win.history.replaceState(null,'',win.location.pathname+win.location.search);const value=new URLSearchParams(hash.slice(1)).get('token');client.pair(value);}
    win.addEventListener('hashchange',pairing);win.addEventListener('pagehide',()=>client.stop());pairing();render();return client;
  }
  const api={shellQuote,bodyCopy,curlForCall,createState,applySnapshot,readNotifications,copyText,createClient,mount};
  if(typeof module!=='undefined' && module.exports) module.exports=api;
  else {root.CoteDashboard=api;mount(root);}
})(typeof window!=='undefined'?window:globalThis);
