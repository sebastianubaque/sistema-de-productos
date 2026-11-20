-- Historial de corridas para el panel Ticket: guarda la corrida ANTERIOR cuando "Generar QRs" sube una nueva.
-- Se ejecuta UNA vez en Supabase: SQL Editor > New query > pegar > Run. No cambia las tablas del generador.
--
-- Cómo funciona: el generador sube la corrida nueva y luego borra la vieja. Justo antes de que se borre,
-- este disparador copia la corrida vieja (con sus hojas, etiquetas y los checks de "pegada") a
-- corridas_historial. Solo copia si ya existe una corrida más nueva: así, si un envío falla a mitad y el
-- generador borra lo que alcanzó a subir, ese intento incompleto NO se guarda como "anterior".
-- Se conservan las 3 más recientes; la página muestra la última como "Anterior".

create table if not exists corridas_historial (
  id          bigserial primary key,
  corrida_id  text not null,
  creada      timestamptz,
  archivada   timestamptz not null default now(),
  total       integer not null default 0,
  data        jsonb not null                -- { corrida, hojas: [...], etiquetas: [...] }
);
create index if not exists corridas_historial_archivada_idx on corridas_historial (archivada desc);

create or replace function archivar_corrida() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from corridas c where c.id <> old.id and c.creada > old.creada) then
    insert into corridas_historial (corrida_id, creada, total, data)
    values (
      old.id, old.creada,
      (select count(*) from etiquetas e where e.corrida_id = old.id),
      jsonb_build_object(
        'corrida',   to_jsonb(old),
        'hojas',     coalesce((select jsonb_agg(to_jsonb(h) order by h.tipo, h.numero) from hojas h where h.corrida_id = old.id), '[]'::jsonb),
        'etiquetas', coalesce((select jsonb_agg(to_jsonb(e) order by e.tipo, e.orden) from etiquetas e where e.corrida_id = old.id), '[]'::jsonb)
      )
    );
    delete from corridas_historial where id not in (select id from corridas_historial order by archivada desc limit 3);
  end if;
  return old;
end;
$$;

drop trigger if exists corridas_archivar on corridas;
create trigger corridas_archivar before delete on corridas
for each row execute function archivar_corrida();

alter table corridas_historial enable row level security;
drop policy if exists "anon todo" on corridas_historial;
create policy "anon todo" on corridas_historial for all to anon using (true) with check (true);
grant select, insert, update, delete on corridas_historial to anon;
grant usage, select on sequence corridas_historial_id_seq to anon;
