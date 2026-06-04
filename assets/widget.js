/* ============================================================
   Asistente flotante (pop-up) · INGESCO Dashboard
   - Botón flotante en todas las páginas
   - Opción 1: preguntar a la IA (conoce los datos del dashboard)
   - Opción 2: escribir por Teams al responsable
   Configuración abajo (CONFIG).
   ============================================================ */
(function(){
  var CONFIG = {
    teamsEmail: "aleix.ruiz@ingesco.com",  // correo de Teams del responsable
    aiUrl: "https://asistente-ingesco.aleixcr9.workers.dev/",   // función de IA (Cloudflare Worker)
    titulo: "¿Tienes una duda?"
  };

  // ---- Estilos ----
  var css = ''
   + '.asis-btn{position:fixed;right:22px;bottom:22px;z-index:99999;width:58px;height:58px;border-radius:50%;'
   + 'background:#DEDC00;color:#1e2b50;border:none;cursor:pointer;font-size:32px;font-weight:800;font-family:Segoe UI,sans-serif;'
   + 'box-shadow:0 8px 24px rgba(30,43,80,.30);display:flex;align-items:center;justify-content:center;transition:.15s}'
   + '.asis-btn:hover{transform:scale(1.07)}'
   + '.asis-panel{position:fixed;right:22px;bottom:90px;z-index:99999;width:392px;max-width:calc(100vw - 32px);'
   + 'background:#f3f5cf;color:#1e2b50;border:1px solid #cdd06a;border-radius:16px;box-shadow:0 16px 50px rgba(30,43,80,.30);'
   + 'font-family:Segoe UI,system-ui,sans-serif;overflow:hidden;display:none}'
   + '.asis-panel.abierto{display:block}'
   + '.asis-head{display:flex;justify-content:space-between;align-items:center;padding:14px 16px;background:#dfe06b;color:#1e2b50;font-weight:800}'
   + '.asis-head .x{cursor:pointer;color:#5a6030;font-size:18px}'
   + '.asis-body{padding:16px}'
   + '.asis-op{display:flex;align-items:center;gap:12px;width:100%;text-align:left;background:#fff;border:1px solid #cdd06a;'
   + 'color:#1e2b50;border-radius:12px;padding:14px;margin-bottom:10px;cursor:pointer;font-size:14px;transition:.15s}'
   + '.asis-op:hover{border-color:#1e2b50;background:#fbfce8}'
   + '.asis-op .ic{font-size:24px}'
   + '.asis-op b{display:block;font-size:14.5px}.asis-op span{font-size:12px;color:#6b7050}'
   + '.asis-chat{display:none;flex-direction:column;height:380px}'
   + '.asis-chat.on{display:flex}'
   + '.asis-msgs{flex:1;overflow:auto;padding:14px;display:flex;flex-direction:column;gap:10px}'
   + '.asis-m{max-width:85%;padding:9px 12px;border-radius:12px;font-size:13.5px;line-height:1.45;white-space:pre-wrap}'
   + '.asis-m.u{align-self:flex-end;background:#1e2b50;color:#fff}'
   + '.asis-m.a{align-self:flex-start;background:#fff;border:1px solid #cdd06a}'
   + '.asis-in{display:flex;gap:8px;padding:12px;border-top:1px solid #cdd06a}'
   + '.asis-in input{flex:1;background:#fff;border:1px solid #cdd06a;color:#1e2b50;border-radius:10px;padding:10px;font-size:13.5px;outline:none}'
   + '.asis-in button{background:#1e2b50;border:none;color:#fff;border-radius:10px;padding:0 14px;cursor:pointer;font-weight:700}'
   + '.asis-back{padding:8px 16px;color:#6b7050;cursor:pointer;font-size:12.5px;border-bottom:1px solid #cdd06a}'
   + '.asis-back:hover{color:#1e2b50}';
  var st = document.createElement('style'); st.textContent = css; document.head.appendChild(st);

  // ---- HTML ----
  var btn = document.createElement('button');
  btn.className = 'asis-btn'; btn.innerHTML = '?'; btn.title = 'XIELA IA'; document.body.appendChild(btn);

  var panel = document.createElement('div');
  panel.className = 'asis-panel';
  panel.innerHTML =
     '<div class="asis-head"><span>🤖 XIELA IA</span><span class="x" id="asisX">✕</span></div>'
   + '<div class="asis-body" id="asisMenu">'
   +   '<p style="font-size:14.5px;color:#1e2b50;font-weight:700;margin-bottom:14px">'+CONFIG.titulo+'</p>'
   +   '<button class="asis-op" id="asisIA"><span class="ic">🤖</span><span><b>Preguntar a XIELA IA</b><span>Resuelve dudas sobre los datos del panel</span></span></button>'
   +   '<button class="asis-op" id="asisTeams"><span class="ic">💬</span><span><b>Escribir a Aleix por Teams</b><span>Manda un mensaje directo por Teams</span></span></button>'
   + '</div>'
   + '<div class="asis-chat" id="asisChat">'
   +   '<div class="asis-back" id="asisBack">← Volver</div>'
   +   '<div class="asis-msgs" id="asisMsgs"></div>'
   +   '<div class="asis-in"><input id="asisInput" placeholder="Escribe tu pregunta..." autocomplete="off"><button id="asisSend">➤</button></div>'
   + '</div>';
  document.body.appendChild(panel);

  function $(id){ return document.getElementById(id); }
  function abrir(v){ panel.classList.toggle('abierto', v); }
  btn.onclick = function(){ abrir(!panel.classList.contains('abierto')); };
  $('asisX').onclick = function(){ abrir(false); };

  // Teams
  $('asisTeams').onclick = function(){
    var url = 'https://teams.microsoft.com/l/chat/0/0?users=' + encodeURIComponent(CONFIG.teamsEmail);
    window.open(url, '_blank');
  };

  // IA
  function verChat(on){ $('asisMenu').style.display = on?'none':'block'; $('asisChat').classList.toggle('on', on); }
  $('asisIA').onclick = function(){ verChat(true); if(!$('asisMsgs').dataset.init){ addMsg('a','¡Hola! 👋 Pregúntame lo que quieras sobre los datos de este panel (visitas, leads, búsquedas…).'); $('asisMsgs').dataset.init='1'; } };
  $('asisBack').onclick = function(){ verChat(false); };

  function addMsg(tipo, texto){ var m=document.createElement('div'); m.className='asis-m '+tipo; m.textContent=texto; $('asisMsgs').appendChild(m); $('asisMsgs').scrollTop=$('asisMsgs').scrollHeight; return m; }

  // Recoge un resumen de los datos cargados en la página actual
  function contexto(){
    var d = {};
    try{ if(window.GA) d.analytics = window.GA; }catch(e){}
    try{ if(window.GSC) d.searchConsole = {totales:window.GSC.totales, totalesLargo:window.GSC.totalesLargo, queries:(window.GSC.queries||[]).slice(0,10), paginas:(window.GSC.paginas||[]).slice(0,10)}; }catch(e){}
    try{ if(window.LEADS) d.leads = {total:window.LEADS.total, nuevos30:window.LEADS.nuevos30, porFuente:window.LEADS.porFuente, porEtapa:window.LEADS.porEtapa, porFormulario:window.LEADS.porFormulario}; }catch(e){}
    try{ if(window.CLARITY_IA) d.traficoIA = window.CLARITY_IA; }catch(e){}
    try{ if(window.CITAS) d.citasIA = window.CITAS; }catch(e){}
    try{ if(window.INDEX) d.indexacion = {indexadas:window.INDEX.indexadas, noIndexadas:window.INDEX.noIndexadas}; }catch(e){}
    return d;
  }

  function enviar(){
    var inp=$('asisInput'); var q=(inp.value||'').trim(); if(!q) return;
    addMsg('u', q); inp.value='';
    if(!CONFIG.aiUrl){ addMsg('a','⚙️ La IA todavía no está activada. En cuanto montemos la conexión, responderé con los datos del panel. Mientras, puedes escribir por Teams.'); return; }
    var cargando = addMsg('a','…');
    fetch(CONFIG.aiUrl, { method:'POST', headers:{'Content-Type':'application/json'},
      body: JSON.stringify({ pregunta:q, pagina:document.title, datos:contexto() }) })
      .then(function(r){ return r.json(); })
      .then(function(j){ cargando.textContent = j.respuesta || j.error || 'Sin respuesta.'; })
      .catch(function(){ cargando.textContent='No pude conectar con la IA. Inténtalo más tarde o escribe por Teams.'; });
  }
  $('asisSend').onclick = enviar;
  $('asisInput').addEventListener('keydown', function(e){ if(e.key==='Enter') enviar(); });
})();