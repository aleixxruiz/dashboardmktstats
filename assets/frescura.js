/* ============================================================
   Frescura de datos · portada del dashboard INGESCO
   ------------------------------------------------------------
   Pinta en #frescura una fila de "chips", uno por fuente, con
   su FECHA REAL de datos y un color segun cuanto hace que se
   actualizo (verde = al dia, ambar = algo viejo, rojo = viejo).
   Clave: para "Citas de IA" usa el PERIODO real de los datos,
   no el re-sellado diario (que enganaba: parecia de hoy).
   ============================================================ */
(function(){
  var HOY = new Date(); HOY.setHours(0,0,0,0);

  // Parseo de fechas: admite "dd/MM/yyyy [HH:mm]" y "yyyy-MM-dd"
  function pd(s){
    if(!s) return null;
    s = String(s).trim();
    var m = s.match(/(\d{1,2})\/(\d{1,2})\/(\d{4})/);
    if(m) return new Date(+m[3], +m[2]-1, +m[1]);
    var i = s.match(/(\d{4})-(\d{1,2})-(\d{1,2})/);
    if(i) return new Date(+i[1], +i[2]-1, +i[3]);
    return null;
  }
  // Fin de un rango "29/05/2026 - 04/06/2026" (la fecha mas reciente = frescura real)
  function finRango(s){
    if(!s) return null;
    var p = String(s).split(/\s[-–]\s/);
    return pd(p.length>1 ? p[p.length-1] : s);
  }
  function dias(d){ return d ? Math.round((HOY - d)/86400000) : null; }
  function texto(n){
    if(n==null) return 'sin datos';
    if(n<=0) return 'hoy'; if(n===1) return 'ayer';
    if(n<7) return 'hace '+n+' días';
    if(n<14) return 'hace 1 semana';
    if(n<31) return 'hace '+Math.round(n/7)+' semanas';
    if(n<60) return 'hace 1 mes';
    return 'hace '+Math.round(n/30)+' meses';
  }
  // verde <=8 dias, ambar <=35, rojo >35, gris = sin dato
  function color(n){ if(n==null) return '#7a89a3'; if(n<=8) return '#34c98a'; if(n<=35) return '#e0b341'; return '#ff6b6b'; }

  var FUENTES = [
    {nom:'Comportamiento IA', pag:'visibilidad-ia.html', f:function(){ return window.CLARITY && window.CLARITY.fechaActualizacion; }},
    {nom:'Analytics',         pag:'analytics.html',       f:function(){ return window.GA && window.GA.fechaActualizacion; }},
    {nom:'Search Console',    pag:'google-search.html',   f:function(){ return window.GSC && window.GSC.fechaActualizacion; }},
    {nom:'Indexación',        pag:'google-search.html',   f:function(){ return window.INDEX && window.INDEX.fechaActualizacion; }},
    {nom:'Leads',             pag:'leads.html',            f:function(){ return window.LEADS && window.LEADS.fechaActualizacion; }},
    {nom:'Oportunidades',     pag:'clientes-cualificados.html', f:function(){ return window.SAGE && window.SAGE.fechaActualizacion; }},
    {nom:'DirectIndustry',    pag:'directindustry.html',   f:function(){ return window.DIRECTINDUSTRY && (window.DIRECTINDUSTRY.generado || (window.DIRECTINDUSTRY.rango && window.DIRECTINDUSTRY.rango.hasta)); }},
    {nom:'Citas de IA',       pag:'visibilidad-ia.html',   rango:true, f:function(){ return window.CITAS && (window.CITAS.periodo || window.CITAS.fechaActualizacion); }}
  ];

  function esc(s){ return String(s==null?'':s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&quot;').replace(/"/g,'&quot;'); }

  function render(){
    var cont = document.getElementById('frescura'); if(!cont) return null;
    var chips='', rojos=0, listos=0;
    FUENTES.forEach(function(s){
      var val=null; try{ val=s.f(); }catch(e){}
      var d = s.rango ? finRango(val) : pd(val);
      var n = dias(d);
      if(val) listos++;
      if(n!=null && n>35) rojos++;
      chips += '<a class="fr-chip" href="'+s.pag+'" title="'+(val?('Dato real: '+esc(val)):'Sin datos cargados')+'">'
        + '<span class="fr-dot" style="background:'+color(n)+'"></span>'
        + '<b>'+s.nom+'</b> <span class="edad">'+texto(n)+'</span></a>';
    });
    var aviso = rojos>0
      ? '<div class="fr-aviso">⚠️ '+rojos+(rojos>1?' fuentes sin actualizar':' fuente sin actualizar')+' (en rojo) — el resto está al día</div>'
      : (listos ? '<div class="fr-aviso ok">✓ Todas las fuentes al día</div>' : '');
    cont.innerHTML = aviso + '<div class="fr-chips">'+chips+'</div>';
    return listos;
  }

  // Los datos los carga el widget de forma asincrona: reintenta hasta que aparezcan
  var intentos=0;
  function run(){ var ok = render(); intentos++; if((ok==null || ok<6) && intentos<15){ setTimeout(run, 500); } }
  if(document.readyState!=='loading') run(); else document.addEventListener('DOMContentLoaded', run);
})();
