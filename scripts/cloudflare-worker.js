/* ============================================================
   Cloudflare Worker · Asistente IA + Peticiones · dashboard INGESCO
   ------------------------------------------------------------
   Dos funciones segun el cuerpo del POST:
   - { accion:'peticion', nombre, tipo, detalle }  -> publica la peticion en TEAMS
   - { pregunta, pagina, datos }                   -> pregunta a Google Gemini (IA)

   SECRETOS (Worker -> Settings -> Variables and Secrets):
   - ANTHROPIC_API_KEY = clave Claude (sk-ant-...) [IA primaria]
   - GEMINI_API_KEY    = clave Gemini (AIza...)    [IA de reserva]
   - TEAMS_WEBHOOK_URL = URL del flujo de Teams    [para las peticiones]

   Webhook de Teams (Power Automate / Workflows):
   En el canal de Teams -> ... -> Workflows -> plantilla
   "Publicar en un canal cuando se reciba una solicitud de webhook".
   Copia la URL HTTPS que genera y guardala como secreto TEAMS_WEBHOOK_URL.
   ============================================================ */
export default {
  async fetch(request, env) {
    const origin = request.headers.get('Origin') || '';
    const permitido = origin.indexOf('aleixxruiz.github.io') >= 0 ? origin : 'https://aleixxruiz.github.io';
    const cors = {
      'Access-Control-Allow-Origin': permitido,
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type'
    };
    if (request.method === 'OPTIONS') return new Response(null, { headers: cors });
    if (request.method !== 'POST') return new Response('Method not allowed', { status: 405, headers: cors });

    try {
      const body = await request.json();

      // ===== PETICION -> Teams =====
      if (body && body.accion === 'peticion') {
        if (!env.TEAMS_WEBHOOK_URL) {
          return new Response(JSON.stringify({ error: 'Teams no esta configurado todavia.' }), { status: 500, headers: { ...cors, 'Content-Type': 'application/json' } });
        }
        const nombre  = (body.nombre  || '').toString().slice(0, 200) || '(sin nombre)';
        const tipo    = (body.tipo    || '-').toString().slice(0, 200);
        const detalle = (body.detalle || '').toString().slice(0, 4000) || '(sin detalle)';
        const card = {
          type: 'message',
          attachments: [{
            contentType: 'application/vnd.microsoft.card.adaptive',
            content: {
              type: 'AdaptiveCard',
              $schema: 'http://adaptivecards.io/schemas/adaptive-card.json',
              version: '1.4',
              body: [
                { type: 'TextBlock', size: 'Large', weight: 'Bolder', text: '📝 Nueva petición · Cuadro de Mando de Marketing' },
                { type: 'FactSet', facts: [
                    { title: 'De:',   value: nombre },
                    { title: 'Tipo:', value: tipo }
                ]},
                { type: 'TextBlock', text: detalle, wrap: true }
              ]
            }
          }]
        };
        const tr = await fetch(env.TEAMS_WEBHOOK_URL, {
          method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(card)
        });
        if (tr.ok) return new Response(JSON.stringify({ ok: true }), { headers: { ...cors, 'Content-Type': 'application/json' } });
        return new Response(JSON.stringify({ error: 'Teams devolvio ' + tr.status }), { status: 502, headers: { ...cors, 'Content-Type': 'application/json' } });
      }

      // ===== PREGUNTA -> IA (Claude primario, Gemini de reserva) =====
      const { pregunta, pagina, datos } = body;
      const sistema =
        "Eres XIELA, analista de marketing senior de INGESCO (proteccion contra el rayo: pararrayos PDC, detectores de tormenta PREVISTORM, puesta a tierra). " +
        "Tu mision es RAZONAR sobre los datos del panel y sacar conclusiones propias, como un analista experto: no te limites a repetir cifras. " +
        "Cruza metricas entre fuentes (Google Analytics, Search Console, HubSpot/leads, Sage CRM/oportunidades, DirectIndustry, Clarity/trafico de IA), " +
        "detecta tendencias, causas probables, relaciones y oportunidades, y aporta una conclusion clara y, cuando proceda, una recomendacion accionable. " +
        "Estructura: primero la respuesta/conclusion directa; luego el porque, apoyado en los datos. Responde en espanol, con tono profesional para directivos, " +
        "y con la extension que pida la pregunta (breve si es simple, mas desarrollada si es analitica). Puedes usar listas o pasos si ayuda. " +
        "REGLA DE ORO con las cifras: usa unicamente numeros que aparezcan en los datos del panel; NUNCA inventes cifras ni fechas. " +
        "Puedes razonar, estimar tendencias e interpretar, pero todo dato concreto debe salir de los datos. " +
        "Si la pregunta NO se puede responder porque NO hay ningun dato en el panel sobre el que razonar, dilo con sinceridad (sin inventar) y " +
        "anade al FINAL del mensaje, en una linea aparte, exactamente este texto: ##PETICION## " +
        "Ese marcador hara que al usuario se le ofrezca abrir la pagina de Peticiones para solicitar ese dato o analisis al equipo. " +
        "No uses ##PETICION## si SI has podido responder con los datos.";
      const prompt = "Pregunta del usuario: " + pregunta + "\n\nPagina actual del panel: " + pagina +
        "\n\nDatos del panel (JSON con todas las fuentes disponibles):\n" + JSON.stringify(datos).slice(0, 40000);

      // --- IA PRIMARIA: Claude (Anthropic) ---
      // Opus 4.8: sin 'thinking' (respuesta directa y rapida) y sin 'temperature'
      // (los modelos Opus 4.7+ rechazan ese parametro). max_tokens 4096 para
      // respuestas analiticas sin que se corten.
      async function llamarClaude() {
        if (!env.ANTHROPIC_API_KEY) return '';   // sin clave -> pasa a Gemini
        const resp = await fetch('https://api.anthropic.com/v1/messages', {
          method: 'POST',
          headers: {
            'content-type': 'application/json',
            'x-api-key': env.ANTHROPIC_API_KEY,
            'anthropic-version': '2023-06-01'
          },
          body: JSON.stringify({
            model: 'claude-opus-4-8',
            max_tokens: 4096,
            system: sistema,
            messages: [{ role: 'user', content: prompt }]
          })
        });
        const j = await resp.json();
        if (!resp.ok) throw new Error((j.error && j.error.message) || ('HTTP ' + resp.status));
        // La respuesta es una lista de bloques; nos quedamos con el texto.
        return (j.content || [])
          .filter(function(b){ return b.type === 'text'; })
          .map(function(b){ return b.text; })
          .join('\n').trim();
      }

      // --- IA DE RESERVA: Gemini (Google), si Claude falla o no hay saldo ---
      async function llamarGemini() {
        const MODELOS = ['gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-2.5-flash-lite'];
        function cuerpoPara(modelo) {
          const gen = { temperature: 0.4, maxOutputTokens: 4096 };
          if (modelo.indexOf('2.5') >= 0) gen.thinkingConfig = { thinkingBudget: 0 };
          return JSON.stringify({
            systemInstruction: { parts: [{ text: sistema }] },
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: gen
          });
        }
        let out = '', ultimoError = '';
        for (const modelo of MODELOS) {
          let hecho = false;
          for (let intento = 0; intento < 2 && !hecho; intento++) {
            try {
              const url = 'https://generativelanguage.googleapis.com/v1beta/models/' + modelo + ':generateContent?key=' + env.GEMINI_API_KEY;
              const resp = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: cuerpoPara(modelo) });
              const j = await resp.json();
              const txt = j.candidates && j.candidates[0] && j.candidates[0].content && j.candidates[0].content.parts && j.candidates[0].content.parts[0].text;
              if (txt) { out = txt; hecho = true; break; }
              ultimoError = (j.error && j.error.message) || ('HTTP ' + resp.status);
              if (resp.status === 503 || resp.status === 429 || /overload|high demand|UNAVAILABLE|RESOURCE_EXHAUSTED/i.test(ultimoError)) {
                await new Promise(function(r){ setTimeout(r, 700); });
              } else { break; }
            } catch (err) { ultimoError = err.message; await new Promise(function(r){ setTimeout(r, 400); }); }
          }
          if (out) break;
        }
        return out;
      }

      // Claude primero; si falla (error, sin saldo o sin clave), Gemini de reserva.
      let respuesta = '';
      try { respuesta = await llamarClaude(); }
      catch (err) { console.log('Claude fallo, uso Gemini de reserva: ' + err.message); }
      if (!respuesta) {
        try { respuesta = await llamarGemini(); } catch (err) { console.log('Gemini fallo: ' + err.message); }
      }
      if (!respuesta) respuesta = 'El servicio de IA esta muy solicitado ahora mismo. Vuelve a intentarlo en unos segundos.';
      return new Response(JSON.stringify({ respuesta }), { headers: { ...cors, 'Content-Type': 'application/json' } });
    } catch (e) {
      return new Response(JSON.stringify({ error: 'Error: ' + e.message }), { status: 500, headers: { ...cors, 'Content-Type': 'application/json' } });
    }
  }
};