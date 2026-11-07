-- Tablas donde "Generar QRs" deja las hojas de etiquetas que genera.
-- Se ejecuta UNA vez en Supabase: SQL Editor > New query > pegar > Run.
--
-- Cada vez que se genera, el programa sube una corrida nueva y borra las anteriores
-- (hojas y etiquetas se borran en cascada), así que siempre queda solo la última.

create table if not exists corridas (
  id              text primary key,                  -- AAAAMMDD-HHMMSS-xxxx
  creada          timestamptz not null default now(),
  formato         text not null,                     -- Carta, A4 u Oficio
  orientacion     text not null,                     -- Horizontal o Vertical
  con_marca       boolean not null default false,    -- si se imprimió la franja de marca
  total_etiquetas integer not null default 0
);

-- Una fila por hoja impresa. tipo: SIN = PDF sin descripción, CON = PDF con descripción.
create table if not exists hojas (
  corrida_id        text not null references corridas(id) on delete cascade,
  tipo              text not null check (tipo in ('SIN', 'CON')),
  numero            integer not null,                -- número de hoja dentro de su PDF (desde 1)
  pdf               text not null,                   -- nombre del PDF
  ancho_mm          numeric not null,                -- tamaño de la hoja
  alto_mm           numeric not null,
  etiqueta_ancho_mm numeric not null,                -- tamaño de la etiqueta (sin la franja de marca)
  etiqueta_alto_mm  numeric not null,
  marca_alto_mm     numeric not null default 0,      -- alto de la franja de marca (0 = sin marca)
  total             integer not null default 0,      -- etiquetas en esta hoja
  primary key (corrida_id, tipo, numero)
);

-- Una fila por etiqueta impresa (si una fila de la hoja de cálculo tiene 3 copias, son 3 filas).
create table if not exists etiquetas (
  corrida_id  text not null references corridas(id) on delete cascade,
  tipo        text not null check (tipo in ('SIN', 'CON')),
  orden       integer not null,                      -- orden de impresión dentro del PDF (desde 0)
  hoja        integer not null,                      -- número de hoja donde quedó
  x_mm        numeric not null,                      -- posición de la celda desde la esquina
  y_mm        numeric not null,                      --   superior izquierda de la hoja
  acostada    boolean not null default false,        -- true = girada 90 grados
  codigo      text not null,                         -- lo que dice el QR de la etiqueta
  copia       integer not null default 1,            -- copia N de ...
  copias      integer not null default 1,            -- ... M (misma fila de la hoja de cálculo)
  fila_hoja   integer,                               -- fila en la hoja de cálculo
  marca       text,
  talla       text,
  venta       integer,                               -- precio de venta (no se envía el de compra)
  color       text,
  estilo      text,
  categoria   text,
  descripcion text,
  genero      text,
  zapatos     boolean not null default false,        -- true = se imprime duplicada
  pegada      boolean not null default false,        -- la usa el otro sistema: ya está pegada
  pegada_en   timestamptz,
  primary key (corrida_id, tipo, orden),
  foreign key (corrida_id, tipo, hoja) references hojas (corrida_id, tipo, numero) on delete cascade
);

create index if not exists etiquetas_codigo_idx on etiquetas (codigo);
create index if not exists etiquetas_hoja_idx   on etiquetas (corrida_id, tipo, hoja);

-- Permisos: el programa y la página usan la llave "anon" del proyecto.
-- (Son datos de etiquetas de la tienda; si más adelante quieres restringirlo, aquí se cambia.)
alter table corridas  enable row level security;
alter table hojas     enable row level security;
alter table etiquetas enable row level security;

drop policy if exists "anon todo" on corridas;
drop policy if exists "anon todo" on hojas;
drop policy if exists "anon todo" on etiquetas;
create policy "anon todo" on corridas  for all to anon using (true) with check (true);
create policy "anon todo" on hojas     for all to anon using (true) with check (true);
create policy "anon todo" on etiquetas for all to anon using (true) with check (true);

-- Opcional: que la página se entere en vivo cuando se genera una corrida nueva o se marca una etiqueta.
-- alter publication supabase_realtime add table corridas, etiquetas;
