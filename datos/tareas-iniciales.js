/* ============================================================
   Tareas iniciales del equipo de marketing INGESCO
   Sintetizadas del tablero de Microsoft Planner ("Propostes tasques MKT").
   Solo se incluyen las tareas ACTIVAS (No iniciado / En curso);
   se han descartado las ya completadas (histórico 2024-2025).
   Reparto orientativo por persona y área; se puede reasignar
   arrastrando o editando cada tarjeta en el tablero.
   ============================================================ */
window.TAREAS_INICIALES = [

  /* ---------- En curso ---------- */
  { id:'seed-2',  titulo:'🚨 Revisar continguts landing SEM', desc:'Revisar y validar los contenidos de la landing de la campaña SEM.', resp:'aleix', area:'seo', prio:'alta', estado:'curso' },
  { id:'seed-10', titulo:'Propuesta documento/plantilla de soluciones', desc:'Preparar propuesta de documento/plantilla de soluciones para presentar a gerencia.', resp:'patricia', area:'contenido', prio:'media', estado:'curso' },
  { id:'seed-17', titulo:'Apoyo acción comercial promoción SPD 370242 y 370220', desc:'Como parte de la acción comercial de venta de protectores STT en stock (370242 y 370220), preparar notas según normativa nacional e internacional para adjuntar a los presupuestos. Validar Ramon, Patricia y Piero.', resp:'patricia', area:'crm', prio:'media', estado:'curso' },

  /* ---------- Lis · en proceso (fichas de producto) ---------- */
  { id:'seed-147', titulo:'FICHAS CONTADORES', desc:'Fichas técnicas de contadores.', resp:'lis', area:'diseno', prio:'media', estado:'curso' },
  { id:'seed-148', titulo:'FICHAS PREVISTORM', desc:'Fichas técnicas PREVISTORM.', resp:'lis', area:'diseno', prio:'media', estado:'curso' },
  { id:'seed-150', titulo:'FICHA PDC AIR', desc:'Ficha del nuevo PDC AIR.', resp:'lis', area:'diseno', prio:'media', estado:'curso' },
  { id:'seed-166', titulo:'Fichas PDC', desc:'Fichas técnicas PDC (versiones finales corregidas).', resp:'lis', area:'diseno', prio:'media', estado:'curso' },
  { id:'seed-167', titulo:'Fichas PDCE en todos los idiomas', desc:'Fichas PDCE traducidas y maquetadas en todos los idiomas.', resp:'lis', area:'diseno', prio:'media', estado:'curso' },
  { id:'seed-170', titulo:'Ficha técnica TOHMY', desc:'Ficha comercial del dispositivo de telemedida de resistencia de puesta a tierra TOHMY (diseño según brief: franja azul, ventajas, imagen producto, caja destacada, beneficios seguridad/comodidad/rentabilidad). Ver detalle completo en Teams.', resp:'lis', area:'diseno', prio:'media', estado:'curso' },

  /* ---------- En revisión ---------- */
  { id:'seed-57',  titulo:'Crear nueva imagen ficha pararrayos', desc:'Nueva imagen de la ficha técnica de pararrayos: mezcla entre la ficha técnica actual y la comercial. Puede ser completamente distinta a la actual.', resp:'lis', area:'diseno', prio:'alta', estado:'revision' },
  { id:'seed-157', titulo:'Maquetar presentación internacional', desc:'Maquetar la presentación comercial internacional.', resp:'patricia', area:'contenido', prio:'media', estado:'revision' },
  { id:'seed-164', titulo:'Presentación LinkedIn comerciales', desc:'Presentación de LinkedIn para el equipo comercial.', resp:'patricia', area:'contenido', prio:'media', estado:'revision' },
  { id:'seed-165', titulo:'Plan de marketing 2026', desc:'Elaborar el plan de marketing 2026.', resp:'aleix', area:'otro', prio:'alta', estado:'revision' },
  { id:'seed-168', titulo:'Reducir tamaño dossier PDC', desc:'Reducir el peso/tamaño del dossier PDC.', resp:'lis', area:'diseno', prio:'media', estado:'revision' },

  /* ---------- Por hacer · Digital / Web / SEO (Aleix) ---------- */
  { id:'seed-12',  titulo:'Concepción landing SEM nuevo texto (renovación)', desc:'Renovar el texto de la landing SEM.', resp:'aleix', area:'seo', prio:'media', estado:'pendiente' },
  { id:'seed-34',  titulo:'SEO: posicionar nuevas KW detector de tormentas', desc:'Posicionar keywords: sensor de rayo, lightning warning system, lightning sensor, alerta/alarma de rayos, lightning alert, lightning detector.', resp:'aleix', area:'seo', prio:'media', estado:'pendiente' },
  { id:'seed-42',  titulo:'⚡ Campaña INGESCO FV', desc:'Landing page + integrar formulario HS + BBDD cribada + campaña LinkedIn (mín. 30 días, ppto máx).', resp:'aleix', area:'seo', prio:'media', estado:'pendiente' },
  { id:'seed-47',  titulo:'Cambiar mensaje automático solicitud presupuesto Calculus', desc:'Cambiar el mensaje automático de solicitud de presupuesto en Calculus (adjuntas capturas y código fuente web en Teams).', resp:'aleix', area:'web', prio:'media', estado:'pendiente' },
  { id:'seed-50',  titulo:'Revisión webs distribuidores', desc:'Actualizar imágenes y contenido de las webs de distribuidores.', resp:'aleix', area:'web', prio:'media', estado:'pendiente' },
  { id:'seed-58',  titulo:'SEO WEB INGESCO', desc:'Auditoría SEO, Looker Studio para gerencia, extensión SEO, cambiar titles y URLs, keyword research. Metatags home (título, descripción, abstract, keywords) editables por página.', resp:'aleix', area:'seo', prio:'media', estado:'pendiente' },
  { id:'seed-59',  titulo:'FORMULARIOS HUBSPOT', desc:'Gestión de formularios de webinars en HubSpot con listas activas por horquilla de fechas (filtros por fecha de creación del contacto).', resp:'aleix', area:'crm', prio:'media', estado:'pendiente' },
  { id:'seed-60',  titulo:'ESTRATEGIA META WEBINAR', desc:'Distribución presupuesto (300€): TF 70%, retargeting 30%. Audiencias frías (intereses, lookalike) y retargeting (vídeo 50%+, interacciones 15 días, visitantes landing, formularios incompletos).', resp:'aleix', area:'redes', prio:'media', estado:'pendiente' },
  { id:'seed-61',  titulo:'EXCEL COMPRAS', desc:'Mantener el Excel de compras (Google Sheets).', resp:'aleix', area:'otro', prio:'baja', estado:'pendiente' },
  { id:'seed-63',  titulo:'Modificar microsite WordPress de SEM', desc:'Modificar el microsite WordPress usado para SEM.', resp:'aleix', area:'web', prio:'media', estado:'pendiente' },
  { id:'seed-64',  titulo:'Crear landing PT/BZ', desc:'Crear landing para Portugal / Brasil.', resp:'aleix', area:'web', prio:'media', estado:'pendiente' },
  { id:'seed-69',  titulo:'Estrategia de contenido para RRSS (LinkedIn, Meta…)', desc:'Definir la estrategia de contenido para redes sociales.', resp:'aleix', area:'redes', prio:'media', estado:'pendiente' },
  { id:'seed-70',  titulo:'Automatizar leads en Excel autoactualizable (webinar Chipre)', desc:'Automatizar un Excel de leads que se actualice solo.', resp:'aleix', area:'crm', prio:'media', estado:'pendiente' },
  { id:'seed-75',  titulo:'Revisar GA4 post remodelación (diaria)', desc:'Revisión diaria de GA4 tras la remodelación de la web.', resp:'aleix', area:'seo', prio:'media', estado:'pendiente' },
  { id:'seed-142', titulo:'SEO PT + LANDING SEM PT', desc:'SEO en portugués y landing SEM para Portugal.', resp:'aleix', area:'seo', prio:'media', estado:'pendiente' },
  { id:'seed-143', titulo:'CAMPAÑA SEM PT', desc:'Campaña SEM para Portugal.', resp:'aleix', area:'seo', prio:'media', estado:'pendiente' },

  /* ---------- Por hacer · Contenido / Comercial (Patricia) ---------- */
  { id:'seed-26',  titulo:'Revisar presentaciones comerciales (3 idiomas)', desc:'Revisar las presentaciones comerciales en los 3 idiomas.', resp:'patricia', area:'contenido', prio:'media', estado:'pendiente' },
  { id:'seed-53',  titulo:'Relación documental de Calidad', desc:'Revisión de la documentación de calidad vigente.', resp:'patricia', area:'otro', prio:'media', estado:'pendiente' },
  { id:'seed-54',  titulo:'Case Study: canal de Panamá', desc:'Elaborar caso de éxito del canal de Panamá.', resp:'patricia', area:'contenido', prio:'media', estado:'pendiente' },
  { id:'seed-55',  titulo:'Noticia: rayos en torres de comunicación y aerogeneradores (EOLOS)', desc:'Noticia sobre protección frente al rayo en torres de comunicación y aerogeneradores. Vincular Pic de Carroi.', resp:'patricia', area:'contenido', prio:'media', estado:'pendiente' },

  /* ---------- Por hacer · Diseño (Lis) ---------- */
  { id:'seed-20',  titulo:"FOTOS PDC's", desc:'Reportaje/fotos de los PDC.', resp:'lis', area:'diseno', prio:'media', estado:'pendiente' },
  { id:'seed-51',  titulo:'Creación de archivo de material de impresión', desc:'Organizar un archivo con el material de impresión.', resp:'lis', area:'diseno', prio:'media', estado:'pendiente' },
  { id:'seed-68',  titulo:'Safety Instructions Labelec', desc:'Instrucciones de seguridad para Labelec.', resp:'lis', area:'diseno', prio:'media', estado:'pendiente' },
  { id:'seed-135', titulo:'Actualizar presentaciones webinar con Canva', desc:'Actualizar las presentaciones de webinar en Canva.', resp:'lis', area:'diseno', prio:'media', estado:'pendiente' },
  { id:'seed-149', titulo:'REDISEÑO LOGO LABELEC', desc:'Rediseño del logo de Labelec.', resp:'lis', area:'diseno', prio:'media', estado:'pendiente' },
  { id:'seed-151', titulo:'Esquemas web para autos fichas de producto', desc:'Esquemas para la web / autogeneración de fichas de producto.', resp:'lis', area:'diseno', prio:'media', estado:'pendiente' },
  { id:'seed-152', titulo:'REDISEÑO LOGO DENA DESARROLLOS', desc:'Rediseño del logo de DENA Desarrollos.', resp:'lis', area:'diseno', prio:'media', estado:'pendiente' },
  { id:'seed-153', titulo:'REDISEÑO LOGO PREVISTORM', desc:'Rediseño del logo PREVISTORM.', resp:'lis', area:'diseno', prio:'media', estado:'pendiente' },
  { id:'seed-154', titulo:'Tríptico instrucciones Labelec', desc:'Tríptico de instrucciones para Labelec.', resp:'lis', area:'diseno', prio:'media', estado:'pendiente' },
  { id:'seed-155', titulo:'MANUAL DE ESTILOS', desc:'Manual de estilos de marca.', resp:'lis', area:'diseno', prio:'media', estado:'pendiente' },
  { id:'seed-156', titulo:'Rediseño web Paratonnerre Maroc', desc:'Rediseño de la web de Paratonnerre Maroc.', resp:'lis', area:'web', prio:'media', estado:'pendiente' },
  { id:'seed-159', titulo:'Cambiar páginas de gracias post-formulario', desc:'Rediseñar las páginas de agradecimiento tras enviar un formulario.', resp:'lis', area:'web', prio:'media', estado:'pendiente' },
  { id:'seed-161', titulo:'Actualizar dossier EOLOS a partir de la presentación', desc:'Actualizar el dossier EOLOS partiendo de la presentación.', resp:'lis', area:'diseno', prio:'media', estado:'pendiente' },
  { id:'seed-162', titulo:'Rehacer catálogo en todos los idiomas', desc:'Rehacer el catálogo en todos los idiomas actualizando erratas y enlaces.', resp:'lis', area:'diseno', prio:'media', estado:'pendiente' },
  { id:'seed-169', titulo:'REDISEÑO ROLL UP', desc:'Rediseño del roll up.', resp:'lis', area:'diseno', prio:'media', estado:'pendiente' },
  { id:'seed-171', titulo:'Maquetar documento plantas FV', desc:'Maquetar el documento de plantas fotovoltaicas en español, portugués y francés (en ese orden).', resp:'lis', area:'diseno', prio:'media', estado:'pendiente' },
  { id:'seed-172', titulo:"Actualizar Manual d'estils INGESCO", desc:'Actualizar el manual de estilos de INGESCO.', resp:'lis', area:'diseno', prio:'media', estado:'pendiente' },
  { id:'seed-173', titulo:'Rediseñar página de gracias del formulario web', desc:'Rediseñar la página de agradecimiento del formulario web.', resp:'lis', area:'web', prio:'media', estado:'pendiente' }

];
