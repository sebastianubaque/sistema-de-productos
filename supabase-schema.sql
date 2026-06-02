create table if not exists public.jahdiel_productos (
  id text primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.jahdiel_facturas (
  id text primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.jahdiel_costos_envios (
  id uuid primary key default gen_random_uuid(),
  cantidad_productos integer not null,
  costo numeric not null,
  fecha timestamptz not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.jahdiel_abonos (
  id uuid primary key default gen_random_uuid(),
  monto numeric not null,
  concepto text,
  fecha timestamptz not null,
  updated_at timestamptz not null default now()
);

alter table public.jahdiel_productos enable row level security;
alter table public.jahdiel_facturas enable row level security;
alter table public.jahdiel_costos_envios enable row level security;
alter table public.jahdiel_abonos enable row level security;

drop policy if exists "jahdiel_productos_public_read" on public.jahdiel_productos;
drop policy if exists "jahdiel_productos_public_write" on public.jahdiel_productos;
drop policy if exists "jahdiel_facturas_public_read" on public.jahdiel_facturas;
drop policy if exists "jahdiel_facturas_public_write" on public.jahdiel_facturas;
drop policy if exists "jahdiel_costos_envios_public_read" on public.jahdiel_costos_envios;
drop policy if exists "jahdiel_costos_envios_public_write" on public.jahdiel_costos_envios;
drop policy if exists "jahdiel_abonos_public_read" on public.jahdiel_abonos;
drop policy if exists "jahdiel_abonos_public_write" on public.jahdiel_abonos;

create policy "jahdiel_productos_public_read"
on public.jahdiel_productos
for select
to anon
using (true);

create policy "jahdiel_productos_public_write"
on public.jahdiel_productos
for all
to anon
using (true)
with check (true);

create policy "jahdiel_facturas_public_read"
on public.jahdiel_facturas
for select
to anon
using (true);

create policy "jahdiel_facturas_public_write"
on public.jahdiel_facturas
for all
to anon
using (true)
with check (true);

create policy "jahdiel_costos_envios_public_read"
on public.jahdiel_costos_envios
for select
to anon
using (true);

create policy "jahdiel_costos_envios_public_write"
on public.jahdiel_costos_envios
for all
to anon
using (true)
with check (true);

create policy "jahdiel_abonos_public_read"
on public.jahdiel_abonos
for select
to anon
using (true);

create policy "jahdiel_abonos_public_write"
on public.jahdiel_abonos
for all
to anon
using (true)
with check (true);

grant select, insert, update, delete on public.jahdiel_productos to anon;
grant select, insert, update, delete on public.jahdiel_facturas to anon;
grant select, insert, update, delete on public.jahdiel_costos_envios to anon;
grant select, insert, update, delete on public.jahdiel_abonos to anon;
