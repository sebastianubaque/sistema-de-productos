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

alter table public.jahdiel_productos enable row level security;
alter table public.jahdiel_facturas enable row level security;

drop policy if exists "jahdiel_productos_public_read" on public.jahdiel_productos;
drop policy if exists "jahdiel_productos_public_write" on public.jahdiel_productos;
drop policy if exists "jahdiel_facturas_public_read" on public.jahdiel_facturas;
drop policy if exists "jahdiel_facturas_public_write" on public.jahdiel_facturas;

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

grant select, insert, update, delete on public.jahdiel_productos to anon;
grant select, insert, update, delete on public.jahdiel_facturas to anon;
