/* ============================================================
   Pantalla de contraseña del Cuadro de Mando (disuasoria)
   - Cubre la página hasta que se introduce la contraseña correcta.
   - La contraseña NO está en el código: solo su hash SHA-256.
   - Recuerda el acceso mientras el navegador esté abierto
     (sessionStorage). Al cerrarlo, vuelve a pedirla.
   NOTA: es una barrera visual; los datos agregados siguen siendo
   accesibles por URL directa (web pública). Para bloqueo real -> Cloudflare Access.
   ============================================================ */
(function(){
  var KEY = 'panel_unlocked_v1';
  var HASH = '0b6052da2bd037546068c80c8471cbc9d99126df58b68d81e8a5f37c3300022e';

  try { if (sessionStorage.getItem(KEY) === '1') return; } catch(e){}

  // Ocultar la página de inmediato para evitar parpadeo
  document.documentElement.style.visibility = 'hidden';

  function sha256(txt){
    return crypto.subtle.digest('SHA-256', new TextEncoder().encode(txt)).then(function(buf){
      return Array.prototype.map.call(new Uint8Array(buf), function(b){ return ('0'+b.toString(16)).slice(-2); }).join('');
    });
  }

  function build(){
    var css = ''
      + '#gate-ov{position:fixed;inset:0;z-index:2147483647;display:flex;align-items:center;justify-content:center;padding:24px;'
      + 'font-family:Segoe UI,system-ui,-apple-system,sans-serif;'
      + 'background:radial-gradient(1100px 560px at 50% -10%,#1d3e6b,transparent),linear-gradient(160deg,#0a1830,#13294b 60%,#0a1830)}'
      + '#gate-ov .gate-box{width:100%;max-width:360px;text-align:center;color:#eaf1fb}'
      + '#gate-ov .gate-logo{height:64px;width:auto;filter:brightness(0) invert(1);margin-bottom:22px}'
      + '#gate-ov h1{font-size:21px;font-weight:800;color:#fff;margin:0 0 6px}'
      + '#gate-ov p{font-size:14px;color:#9fb3d1;margin:0 0 22px}'
      + '#gate-ov input{width:100%;background:#16223f;border:2px solid #2c3d63;border-radius:12px;color:#eaf1fb;'
      + 'font-size:15px;padding:14px 16px;outline:none;text-align:center}'
      + '#gate-ov input:focus{border-color:#DEDC00}'
      + '#gate-ov button{width:100%;margin-top:12px;background:#DEDC00;color:#13294b;border:none;border-radius:12px;'
      + 'padding:14px;font-size:15.5px;font-weight:800;cursor:pointer;transition:.15s}'
      + '#gate-ov button:hover{filter:brightness(1.05)}'
      + '#gate-ov .gate-err{display:none;color:#ff8a8a;font-size:13px;font-weight:700;margin-top:14px}';
    var st = document.createElement('style'); st.textContent = css; document.head.appendChild(st);

    var ov = document.createElement('div');
    ov.id = 'gate-ov';
    ov.innerHTML =
        '<div class="gate-box">'
      +   '<img class="gate-logo" src="assets/logo-ingesco.png" alt="INGESCO">'
      +   '<h1>Cuadro de Mando de Marketing</h1>'
      +   '<p>Introduce la contraseña para acceder</p>'
      +   '<input id="gate-pass" type="password" placeholder="Contraseña" autocomplete="current-password">'
      +   '<button id="gate-btn" type="button">Entrar</button>'
      +   '<div class="gate-err" id="gate-err">Contraseña incorrecta</div>'
      + '</div>';
    document.body.appendChild(ov);
    document.documentElement.style.visibility = '';

    var inp = document.getElementById('gate-pass');
    var btn = document.getElementById('gate-btn');
    var err = document.getElementById('gate-err');

    function intentar(){
      sha256(inp.value || '').then(function(h){
        if (h === HASH){
          try { sessionStorage.setItem(KEY, '1'); } catch(e){}
          ov.parentNode && ov.parentNode.removeChild(ov);
        } else {
          err.style.display = 'block';
          inp.value = ''; inp.focus();
        }
      });
    }
    btn.addEventListener('click', intentar);
    inp.addEventListener('keydown', function(e){ if (e.key === 'Enter') intentar(); });
    inp.focus();
  }

  if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', build); }
  else { build(); }
})();
