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

  // Cargar TODOS los datos del panel (en cualquier página) para que el asistente
  // tenga la foto completa de todas las fuentes, no solo de la página actual.
  ['datos/datos.js','datos/datos-ia.js','datos/ga.js','datos/gsc.js','datos/leads.js',
   'datos/sage.js','datos/directindustry.js','datos/citas-ia.js','datos/indexacion.js',
   'datos/historico.js','datos/historico-ia.js'].forEach(function(src){
    if([].some.call(document.scripts, function(s){ return s.src && s.src.indexOf(src) >= 0; })) return;
    var sc = document.createElement('script'); sc.src = src; sc.async = true; sc.onerror = function(){};
    document.head.appendChild(sc);
  });

  // ---- Estilos ----
  var css = ''
   + '.asis-btn{position:fixed;right:22px;bottom:22px;z-index:99999;width:58px;height:58px;border-radius:50%;'
   + 'background:#DEDC00;color:#1e2b50;border:none;cursor:pointer;font-size:32px;font-weight:800;font-family:Segoe UI,sans-serif;'
   + 'box-shadow:0 8px 24px rgba(30,43,80,.30);display:flex;align-items:center;justify-content:center;transition:.15s}'
   + '.asis-btn:hover{transform:scale(1.07)}'
   + '.asis-portal{position:fixed;right:90px;bottom:22px;z-index:99999;width:58px;height:58px;border-radius:50%;'
   + 'background:#1e2b50;color:#fff;border:2px solid #DEDC00;cursor:pointer;font-size:26px;text-decoration:none;'
   + 'box-shadow:0 8px 24px rgba(30,43,80,.30);display:flex;align-items:center;justify-content:center;transition:.15s}'
   + '.asis-portal:hover{transform:scale(1.07)}'
   + '@media(max-width:520px){.asis-portal{right:88px}}'
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
   + '.asis-back:hover{color:#1e2b50}'
   + '.asis-pet{align-self:flex-start;display:inline-flex;align-items:center;gap:8px;margin-top:2px;'
   + 'background:#1e2b50;color:#fff;text-decoration:none;border-radius:10px;padding:9px 14px;font-size:13px;font-weight:700}'
   + '.asis-pet:hover{background:#2a3b6b}';
  var st = document.createElement('style'); st.textContent = css; document.head.appendChild(st);

  // ---- HTML ----
  var btn = document.createElement('button');
  btn.className = 'asis-btn'; btn.innerHTML = '?'; btn.title = 'XIELA IA'; document.body.appendChild(btn);

  // Acceso directo al Portal de Marketing (herramienta externa del departamento)
  var portal = document.createElement('a');
  portal.className = 'asis-portal';
  portal.href = 'https://dena-fss.ardicloud.com:8443/portal_marqueting.html';
  portal.target = '_blank'; portal.rel = 'noopener';
  portal.title = 'Portal de Marketing'; portal.innerHTML = '⚡';
  document.body.appendChild(portal);

  var panel = document.createElement('div');
  panel.className = 'asis-panel';
  panel.innerHTML =
     '<div class="asis-head"><span>🤖 XIELA IA</span><span class="x" id="asisX">✕</span></div>'
   + '<div class="asis-body" id="asisMenu">'
   +   '<p style="font-size:14.5px;color:#1e2b50;font-weight:700;margin-bottom:14px">'+CONFIG.titulo+'</p>'
   +   '<button class="asis-op" id="asisIA"><span class="ic">🤖</span><span><b>Preguntar a XIELA IA</b><span>Resuelve dudas sobre los datos del panel</span></span></button>'
   +   '<button class="asis-op" id="asisTeams"><span class="ic">💬</span><span><b>Escribir al equipo de marketing</b><span>Manda un mensaje al equipo por Teams</span></span></button>'
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
  $('asisIA').onclick = function(){ verChat(true); if(!$('asisMsgs').dataset.init){ addMsg('a','¡Hola! 👋 Soy XIELA. Analizo todos los datos del panel (web, IA, búsquedas, leads, oportunidades y DirectIndustry), los cruzo y te doy conclusiones. Pregúntame lo que quieras.'); $('asisMsgs').dataset.init='1'; } };
  $('asisBack').onclick = function(){ verChat(false); };

  function addMsg(tipo, texto){ var m=document.createElement('div'); m.className='asis-m '+tipo; m.textContent=texto; $('asisMsgs').appendChild(m); $('asisMsgs').scrollTop=$('asisMsgs').scrollHeight; return m; }

  // Botón para ir a Peticiones (cuando la IA no tiene datos para responder)
  function botonPeticiones(){
    if($('asisMsgs').querySelector('.asis-pet-ultimo')) $('asisMsgs').querySelector('.asis-pet-ultimo').classList.remove('asis-pet-ultimo');
    var a=document.createElement('a'); a.className='asis-pet asis-pet-ultimo'; a.href='peticiones.html';
    a.innerHTML='📝 Pedirlo en Peticiones';
    $('asisMsgs').appendChild(a); $('asisMsgs').scrollTop=$('asisMsgs').scrollHeight;
  }

  // Recoge un resumen de TODOS los datos del panel (todas las fuentes)
  function corta(a,n){ return Array.isArray(a) ? a.slice(0, n||15) : a; }
  function contexto(){
    var d = {};
    try{ if(window.GA) d.analytics = window.GA; }catch(e){}
    try{ if(window.GSC) d.searchConsole = {totales:window.GSC.totales, totalesLargo:window.GSC.totalesLargo, queries:corta(window.GSC.queries,12), paginas:corta(window.GSC.paginas,12)}; }catch(e){}
    try{ if(window.LEADS) d.leads = {total:window.LEADS.total, nuevos30:window.LEADS.nuevos30, prev30:window.LEADS.prev30, porFuente:window.LEADS.porFuente, porEtapa:window.LEADS.porEtapa, porFormulario:window.LEADS.porFormulario, porMes:window.LEADS.porMes, porPais:corta(window.LEADS.porPais,15)}; }catch(e){}
    try{ if(window.SAGE) d.oportunidadesSage = {total:window.SAGE.total, ganadas:window.SAGE.ganadas, perdidas:window.SAGE.perdidas, enCurso:window.SAGE.abiertas, porOrigen:window.SAGE.porOrigen, porSector:window.SAGE.porSector, porMes:corta(window.SAGE.porMes,24), empresasConSector:window.SAGE.empresasConSector, actualizado:window.SAGE.fechaActualizacion}; }catch(e){}
    try{ if(window.DIRECTINDUSTRY){ var di=window.DIRECTINDUSTRY; d.directIndustry={generado:di.generado, rango:di.rango, panel:di.panel, kpis:di.kpis, insignia:di.insignia, porPais:corta(di.porPais,15), porSector:corta(di.porSector,12), porMesVisita:di.porMesVisita, porMesPeticion:di.porMesPeticion, topProductos:corta(di.topProductos,12)}; } }catch(e){}
    try{ if(window.CLARITY_IA) d.traficoIA = window.CLARITY_IA; }catch(e){}
    try{ if(window.CITAS) d.citasIA = window.CITAS; }catch(e){}
    try{ if(window.INDEX) d.indexacion = {indexadas:window.INDEX.indexadas, noIndexadas:window.INDEX.noIndexadas}; }catch(e){}
    try{ if(window.CLARITY_HISTORICO) d.clarityHistorico = corta(window.CLARITY_HISTORICO,30); }catch(e){}
    try{ if(window.CLARITY_IA_HISTORICO) d.iaHistorico = corta(window.CLARITY_IA_HISTORICO,30); }catch(e){}
    // Guía para que la IA interprete bien las cifras y NO invente unidades
    d._guia = {
      nota: "IMPORTANTE: todas las cifras de este panel son CONTEOS (número de...). NO existe ningún dato de facturación, ventas ni importes en euros: nunca añadas el símbolo € ni inventes valores monetarios. Única excepción de unidad: en searchConsole el CTR es un porcentaje y la posición es la posición media en Google.",
      campos: {
        analytics: "Google Analytics (web): usuarios, sesiones y páginas vistas.",
        searchConsole: "Google Search Console: clics, impresiones, CTR (%) y posición media en Google; queries y páginas con su nº de clics e impresiones.",
        leads: "HubSpot: total = nº total de contactos; nuevos30 = contactos nuevos en los últimos 30 días (prev30 = los 30 días anteriores); porFuente/porEtapa/porFormulario/porPais = nº de contactos en cada categoría; porMes = contactos nuevos por mes.",
        oportunidadesSage: "Sage CRM: total/ganadas/perdidas/enCurso = nº de oportunidades; porOrigen = nº de oportunidades por origen; porMes = nº de oportunidades por mes; porSector = NÚMERO DE EMPRESAS por sector (es un conteo de empresas, NO dinero); empresasConSector = nº de empresas con sector asignado.",
        directIndustry: "DirectIndustry (escaparate B2B): panel.standContent/standHighlight/advertisement = visualizaciones y clics; panel.prospectos = nº de empresas identificadas y prospects; panel.solicitudes = nº de solicitudes (exclusivas, comparativas, RFQ); insignia = nº de peticiones y de vistas por producto (PDC con sus modelos, PREVISTORM, PDC electrónico); porPais/porSector = nº de visitantes; topProductos = nº de veces visto; kpis = conteos de visitantes/peticiones/productos.",
        traficoIA: "Clarity: sesiones que llegan desde asistentes de IA, por plataforma.",
        citasIA: "Cuota de autoridad en IA (SoA, en %) y nº de consultas y páginas citadas.",
        indexacion: "Nº de páginas indexadas y no indexadas en Google."
      }
    };
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
      .then(function(j){
        var txt = (j.respuesta || j.error || 'Sin respuesta.');
        var pide = txt.indexOf('##PETICION##') >= 0;
        txt = txt.replace(/##PETICION##/g,'').trim();
        cargando.textContent = txt;
        if(pide) botonPeticiones();
      })
      .catch(function(){ cargando.textContent='No pude conectar con la IA. Inténtalo más tarde o escribe por Teams.'; });
  }
  $('asisSend').onclick = enviar;
  $('asisInput').addEventListener('keydown', function(e){ if(e.key==='Enter') enviar(); });
})();