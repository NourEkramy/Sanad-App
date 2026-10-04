-- =============================================================================
-- Sanad — initial schema
--
-- Source of truth for customers, service records and reference data.
-- Every table has Row Level Security enabled; the API roles never receive a
-- table-level DELETE grant, so historical data can only be soft-deleted.
-- =============================================================================

-- Supabase keeps extensions in their own schema.
create schema if not exists extensions;
create extension if not exists pg_trgm with schema extensions;

-- -----------------------------------------------------------------------------
-- Types
-- -----------------------------------------------------------------------------

create type public.app_role as enum ('admin', 'staff');

-- 'unspecified' exists only for legacy rows imported from the Excel workbook,
-- which never recorded how a visit was paid. New records must be cash or
-- electronic (enforced by a check constraint on service_records).
create type public.payment_method as enum ('cash', 'electronic', 'unspecified');

create type public.import_status as enum ('committed', 'rolled_back');

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------

-- Normalises free text so that visually-identical Arabic/English names compare
-- equal: trims, collapses whitespace, lower-cases, unifies alef/yaa/taa-marbuta
-- variants and strips tatweel and diacritics. Mirrors
-- app/lib/core/utils/text_normalizer.dart — keep both in sync.
create or replace function public.sanad_normalize(input text)
returns text
language sql
immutable
parallel safe
as $$
  select nullif(
    regexp_replace(
      translate(
        lower(btrim(coalesce(input, ''))),
        'أإآٱىةـًٌٍَُِّْ',
        'اااايه'
      ),
      '\s+', ' ', 'g'
    ),
    ''
  );
$$;

-- Egyptian mobile (01[0125] + 8 digits) or landline (0 + area code, 9–10 digits).
create or replace function public.sanad_is_valid_phone(phone text)
returns boolean
language sql
immutable
parallel safe
as $$
  select phone ~ '^(01[0125][0-9]{8}|0[2-9][0-9]{7,8})$';
$$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- Users / profiles
-- -----------------------------------------------------------------------------

create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text not null check (char_length(btrim(full_name)) between 1 and 120),
  email       text not null,
  role        public.app_role not null default 'staff',
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

-- Every new auth user receives a 'staff' profile. Admins are promoted
-- explicitly (see docs/08-deployment.md), never by self sign-up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email)
  values (
    new.id,
    coalesce(nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''), split_part(new.email, '@', 1)),
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.current_role_name()
returns public.app_role
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid() and is_active;
$$;

create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.profiles where id = auth.uid() and is_active);
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles where id = auth.uid() and is_active and role = 'admin'
  );
$$;

-- Prevents a non-admin from changing their own role/is_active through the API.
-- Server-side contexts (SQL editor, service role) have no auth.uid() and are
-- trusted; that is how the first administrator is bootstrapped.
create or replace function public.guard_profile_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (new.role is distinct from old.role or new.is_active is distinct from old.is_active)
     and auth.uid() is not null and not public.is_admin() then
    raise exception 'Only administrators can change roles or activation'
      using errcode = '42501';
  end if;
  if new.id = auth.uid() and old.role = 'admin'
     and (new.role <> 'admin' or not new.is_active) then
    raise exception 'Administrators cannot demote or deactivate themselves'
      using errcode = '42501';
  end if;
  new.email := old.email;
  return new;
end;
$$;

create trigger profiles_guard before update on public.profiles
  for each row execute function public.guard_profile_update();

-- -----------------------------------------------------------------------------
-- Import batches (declared early: other tables reference them for rollback)
-- -----------------------------------------------------------------------------

create table public.import_batches (
  id              uuid primary key default gen_random_uuid(),
  file_name       text not null,
  file_sha256     text not null,
  sheet_name      text not null,
  status          public.import_status not null default 'committed',
  summary         jsonb not null default '{}'::jsonb,
  created_by      uuid references public.profiles (id) default auth.uid(),
  created_at      timestamptz not null default now(),
  rolled_back_at  timestamptz,
  rolled_back_by  uuid references public.profiles (id)
);

-- The same file may only be committed once at a time (prevents double imports).
create unique index import_batches_file_committed_key
  on public.import_batches (file_sha256) where status = 'committed';

-- -----------------------------------------------------------------------------
-- Reference data: areas, nurses, services
-- -----------------------------------------------------------------------------

create table public.areas (
  id               uuid primary key default gen_random_uuid(),
  name             text not null check (char_length(btrim(name)) between 1 and 80),
  name_normalized  text generated always as (public.sanad_normalize(name)) stored,
  is_active        boolean not null default true,
  import_batch_id  uuid references public.import_batches (id),
  created_by       uuid references public.profiles (id) default auth.uid(),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create unique index areas_name_normalized_key on public.areas (name_normalized);
create trigger areas_updated_at before update on public.areas
  for each row execute function public.set_updated_at();

create table public.nurses (
  id               uuid primary key default gen_random_uuid(),
  name             text not null check (char_length(btrim(name)) between 1 and 120),
  name_normalized  text generated always as (public.sanad_normalize(name)) stored,
  phone            text check (phone is null or public.sanad_is_valid_phone(phone)),
  is_active        boolean not null default true,
  notes            text check (notes is null or char_length(notes) <= 1000),
  import_batch_id  uuid references public.import_batches (id),
  created_by       uuid references public.profiles (id) default auth.uid(),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create unique index nurses_name_normalized_key on public.nurses (name_normalized);
create trigger nurses_updated_at before update on public.nurses
  for each row execute function public.set_updated_at();

create table public.services (
  id               uuid primary key default gen_random_uuid(),
  name             text not null check (char_length(btrim(name)) between 1 and 160),
  name_normalized  text generated always as (public.sanad_normalize(name)) stored,
  -- NULL = variable price (the workbook marks these as "**").
  default_price    numeric(12, 2) check (default_price is null or default_price >= 0),
  is_active        boolean not null default true,
  import_batch_id  uuid references public.import_batches (id),
  created_by       uuid references public.profiles (id) default auth.uid(),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create unique index services_name_normalized_key on public.services (name_normalized);
create trigger services_updated_at before update on public.services
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- Customers
-- -----------------------------------------------------------------------------

create table public.customers (
  id               uuid primary key default gen_random_uuid(),
  full_name        text not null check (char_length(btrim(full_name)) between 1 and 160),
  name_normalized  text generated always as (public.sanad_normalize(full_name)) stored,
  -- Stored normalised: digits only, local format (e.g. 01012345678).
  phone            text,
  address          text check (address is null or char_length(address) <= 500),
  area_id          uuid not null references public.areas (id) on delete restrict,
  notes            text check (notes is null or char_length(notes) <= 2000),
  -- Set for legacy customers whose phone was missing/invalid in Excel. They
  -- are kept (their visit history matters) but flagged for an admin to fix.
  needs_review     boolean not null default false,
  import_batch_id  uuid references public.import_batches (id),
  created_by       uuid references public.profiles (id) default auth.uid(),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  deleted_at       timestamptz,
  deleted_by       uuid references public.profiles (id),
  constraint customers_phone_valid check (
    (phone is not null and public.sanad_is_valid_phone(phone))
    or (phone is null and needs_review)
  )
);

-- Phone is THE customer identifier: unique across live and archived customers
-- so an archived customer is restored rather than duplicated.
create unique index customers_phone_key on public.customers (phone) where phone is not null;
-- Prefix search ("01012…") uses this b-tree; contains-search uses trigram.
create index customers_phone_prefix_idx on public.customers (phone text_pattern_ops);
create index customers_phone_trgm_idx on public.customers using gin (phone extensions.gin_trgm_ops);
create index customers_name_trgm_idx on public.customers using gin (name_normalized extensions.gin_trgm_ops);
create index customers_area_idx on public.customers (area_id);
create index customers_created_at_idx on public.customers (created_at desc);

create trigger customers_updated_at before update on public.customers
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- Service records
-- -----------------------------------------------------------------------------

create table public.service_records (
  -- Generated on the device so an offline/retried save is idempotent.
  id                     uuid primary key default gen_random_uuid(),
  customer_id            uuid not null references public.customers (id) on delete restrict,
  nurse_id               uuid not null references public.nurses (id) on delete restrict,
  service_id             uuid not null references public.services (id) on delete restrict,
  -- Person who actually received the service when it differs from the customer
  -- (family members often share one phone number).
  patient_name           text check (patient_name is null or char_length(patient_name) <= 160),
  price                  numeric(12, 2) not null check (price >= 0 and price <= 1000000),
  payment_method         public.payment_method not null,
  service_date           date not null,
  service_time           time,
  notes                  text check (notes is null or char_length(notes) <= 2000),

  -- Historical snapshot, written by trigger: a record must keep reading the
  -- same even if the customer moves, an area/nurse/service is renamed, or a
  -- service's default price changes.
  -- Area where the service was provided (customer's area at that time).
  area_id                uuid references public.areas (id) on delete restrict,
  customer_name_snapshot text not null default '',
  customer_phone_snapshot text,
  address_snapshot       text,
  area_name_snapshot     text not null default '',
  nurse_name_snapshot    text not null default '',
  service_name_snapshot  text not null default '',

  legacy_ref             text,
  import_batch_id        uuid references public.import_batches (id),
  created_by             uuid references public.profiles (id) default auth.uid(),
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  deleted_at             timestamptz,
  deleted_by             uuid references public.profiles (id),

  constraint service_records_time_required
    check (service_time is not null or import_batch_id is not null),
  constraint service_records_payment_known
    check (payment_method <> 'unspecified' or import_batch_id is not null)
);

create index service_records_customer_idx
  on public.service_records (customer_id, service_date desc, service_time desc nulls last)
  where deleted_at is null;
create index service_records_date_idx
  on public.service_records (service_date desc, service_time desc nulls last)
  where deleted_at is null;
create index service_records_nurse_idx on public.service_records (nurse_id);
create index service_records_area_idx on public.service_records (area_id);
create index service_records_service_idx on public.service_records (service_id);
create index service_records_batch_idx on public.service_records (import_batch_id)
  where import_batch_id is not null;

create trigger service_records_updated_at before update on public.service_records
  for each row execute function public.set_updated_at();

create or replace function public.snapshot_service_record()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  c record;
begin
  if tg_op = 'INSERT'
     or new.customer_id is distinct from old.customer_id
     or new.nurse_id is distinct from old.nurse_id
     or new.service_id is distinct from old.service_id then
    select cu.full_name, cu.phone, cu.address, cu.area_id, a.name as area_name
      into c
      from public.customers cu
      join public.areas a on a.id = cu.area_id
     where cu.id = new.customer_id;

    if tg_op = 'INSERT' or new.customer_id is distinct from old.customer_id then
      new.customer_name_snapshot  := c.full_name;
      new.customer_phone_snapshot := c.phone;
      -- Imports pass the address/area exactly as written on the legacy row.
      if new.import_batch_id is null or new.address_snapshot is null then
        new.address_snapshot := c.address;
      end if;
      if new.import_batch_id is null or new.area_id is null then
        new.area_id := c.area_id;
      end if;
      if new.import_batch_id is null or new.area_name_snapshot = '' then
        new.area_name_snapshot := (select name from public.areas where id = new.area_id);
      end if;
    end if;
    select name into new.nurse_name_snapshot from public.nurses where id = new.nurse_id;
    select name into new.service_name_snapshot from public.services where id = new.service_id;
  end if;
  return new;
end;
$$;

create trigger service_records_snapshot before insert or update on public.service_records
  for each row execute function public.snapshot_service_record();

-- New records may only reference active nurses/services/customers.
create or replace function public.guard_service_record_refs()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.import_batch_id is not null then
    return new;
  end if;
  if tg_op = 'INSERT' or new.nurse_id is distinct from old.nurse_id then
    if not exists (select 1 from public.nurses where id = new.nurse_id and is_active) then
      raise exception 'Nurse is inactive' using errcode = 'P0001', hint = 'nurse_inactive';
    end if;
  end if;
  if tg_op = 'INSERT' or new.service_id is distinct from old.service_id then
    if not exists (select 1 from public.services where id = new.service_id and is_active) then
      raise exception 'Service is inactive' using errcode = 'P0001', hint = 'service_inactive';
    end if;
  end if;
  if tg_op = 'INSERT' and exists (
    select 1 from public.customers where id = new.customer_id and deleted_at is not null
  ) then
    raise exception 'Customer is archived' using errcode = 'P0001', hint = 'customer_archived';
  end if;
  return new;
end;
$$;

create trigger service_records_guard_refs before insert or update on public.service_records
  for each row execute function public.guard_service_record_refs();

-- -----------------------------------------------------------------------------
-- Audit log (append-only)
-- -----------------------------------------------------------------------------

create table public.audit_log (
  id          bigint generated always as identity primary key,
  table_name  text not null,
  row_id      uuid not null,
  action      text not null,
  old_data    jsonb,
  new_data    jsonb,
  actor_id    uuid default auth.uid(),
  created_at  timestamptz not null default now()
);

create index audit_log_row_idx on public.audit_log (table_name, row_id, created_at desc);

create or replace function public.write_audit_log()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.audit_log (table_name, row_id, action, old_data, new_data)
  values (
    tg_table_name,
    coalesce(new.id, old.id),
    lower(tg_op),
    case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end,
    case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end
  );
  return coalesce(new, old);
end;
$$;

create trigger customers_audit after update or delete on public.customers
  for each row execute function public.write_audit_log();
create trigger service_records_audit after update or delete on public.service_records
  for each row execute function public.write_audit_log();

-- -----------------------------------------------------------------------------
-- Import rows (audit trail of every legacy row and what happened to it)
-- -----------------------------------------------------------------------------

create table public.import_rows (
  id          bigint generated always as identity primary key,
  batch_id    uuid not null references public.import_batches (id) on delete cascade,
  row_number  integer not null,
  outcome     text not null check (outcome in ('imported', 'skipped')),
  record_id   uuid references public.service_records (id) on delete set null,
  raw         jsonb not null,
  messages    text[] not null default '{}'
);

create index import_rows_batch_idx on public.import_rows (batch_id, row_number);

-- -----------------------------------------------------------------------------
-- Views (security_invoker: RLS of the caller applies)
-- -----------------------------------------------------------------------------

create view public.customer_overview
with (security_invoker = true) as
select
  c.id,
  c.full_name,
  c.name_normalized,
  c.phone,
  c.address,
  c.area_id,
  a.name as area_name,
  c.notes,
  c.needs_review,
  c.created_at,
  c.updated_at,
  c.deleted_at,
  coalesce(s.record_count, 0) as record_count,
  s.last_service_date
from public.customers c
join public.areas a on a.id = c.area_id
left join lateral (
  select count(*) as record_count, max(r.service_date) as last_service_date
  from public.service_records r
  where r.customer_id = c.id and r.deleted_at is null
) s on true;

create view public.service_record_details
with (security_invoker = true) as
select
  r.id,
  r.customer_id,
  c.full_name as customer_name,
  c.phone as customer_phone,
  r.address_snapshot as customer_address,
  r.area_name_snapshot as area_name,
  r.area_id,
  c.area_id as customer_area_id,
  r.patient_name,
  r.nurse_id,
  r.nurse_name_snapshot as nurse_name,
  r.service_id,
  r.service_name_snapshot as service_name,
  r.price,
  r.payment_method,
  r.service_date,
  r.service_time,
  r.notes,
  r.legacy_ref,
  r.import_batch_id,
  r.created_by,
  r.created_at,
  r.updated_at,
  r.deleted_at
from public.service_records r
join public.customers c on c.id = r.customer_id;

-- -----------------------------------------------------------------------------
-- RPC: search, dashboard, archive
-- -----------------------------------------------------------------------------

-- Phone-first customer search. Digits → phone prefix, then phone contains
-- (≥ 4 digits). Otherwise → normalised name contains.
create or replace function public.search_customers(query text, max_results integer default 20)
returns setof public.customer_overview
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  q text := btrim(coalesce(query, ''));
  digits text;
  lim integer := least(greatest(coalesce(max_results, 20), 1), 50);
begin
  if q = '' then
    return;
  end if;
  digits := translate(q, '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹', '01234567890123456789');
  digits := regexp_replace(digits, '[\s\-\(\)\.]', '', 'g');
  if digits ~ '^\+?[0-9]+$' then
    digits := regexp_replace(digits, '^(\+?20|0020)', '0');
    digits := ltrim(digits, '+');
    return query
      select o.* from public.customer_overview o
       where o.deleted_at is null
         and (o.phone like digits || '%'
              or (char_length(digits) >= 4 and o.phone like '%' || digits || '%'))
       order by (o.phone = digits) desc, (o.phone like digits || '%') desc, o.phone
       limit lim;
  else
    return query
      select o.* from public.customer_overview o
       where o.deleted_at is null
         and o.name_normalized like '%' || public.sanad_normalize(q) || '%'
       order by o.full_name
       limit lim;
  end if;
end;
$$;

create or replace function public.dashboard_stats(for_day date default current_date)
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select jsonb_build_object(
    'total_customers', (select count(*) from public.customers where deleted_at is null),
    'total_records', (select count(*) from public.service_records where deleted_at is null),
    'today_records', (select count(*) from public.service_records
                       where deleted_at is null and service_date = for_day),
    'today_revenue', (select coalesce(sum(price), 0) from public.service_records
                       where deleted_at is null and service_date = for_day),
    'today_cash', (select coalesce(sum(price), 0) from public.service_records
                    where deleted_at is null and service_date = for_day and payment_method = 'cash'),
    'today_electronic', (select coalesce(sum(price), 0) from public.service_records
                          where deleted_at is null and service_date = for_day and payment_method = 'electronic'),
    'month_revenue', (select coalesce(sum(price), 0) from public.service_records
                       where deleted_at is null
                         and service_date >= date_trunc('month', for_day)::date
                         and service_date <= for_day),
    'active_nurses', (select count(*) from public.nurses where is_active),
    'active_services', (select count(*) from public.services where is_active),
    'customers_needing_review', (select count(*) from public.customers
                                  where deleted_at is null and needs_review)
  );
$$;

-- Single source of truth for record filtering (list screen, totals, export).
-- A query made of digits matches the phone; anything else the customer or
-- patient name (normalised).
create or replace function public.filter_service_records(
  p_from date default null,
  p_to date default null,
  p_nurse_id uuid default null,
  p_service_id uuid default null,
  p_area_id uuid default null,
  p_payment_method public.payment_method default null,
  p_query text default null,
  p_customer_id uuid default null
)
returns setof public.service_record_details
language sql
stable
security invoker
set search_path = public
as $$
  with q as (
    select
      nullif(btrim(coalesce(p_query, '')), '') as text,
      regexp_replace(
        translate(coalesce(p_query, ''), '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹', '01234567890123456789'),
        '[\s\-\(\)\.\+]', '', 'g'
      ) as digits
  )
  select d.*
    from public.service_record_details d, q
   where d.deleted_at is null
     and (p_from is null or d.service_date >= p_from)
     and (p_to is null or d.service_date <= p_to)
     and (p_nurse_id is null or d.nurse_id = p_nurse_id)
     and (p_service_id is null or d.service_id = p_service_id)
     and (p_area_id is null or d.area_id = p_area_id)
     and (p_payment_method is null or d.payment_method = p_payment_method)
     and (p_customer_id is null or d.customer_id = p_customer_id)
     and (
       q.text is null
       or (q.digits ~ '^[0-9]+$' and d.customer_phone like '%' || q.digits || '%')
       or (q.digits !~ '^[0-9]+$' and (
             public.sanad_normalize(d.customer_name) like '%' || public.sanad_normalize(q.text) || '%'
             or public.sanad_normalize(d.patient_name) like '%' || public.sanad_normalize(q.text) || '%'))
     );
$$;

create or replace function public.record_totals(
  p_from date default null,
  p_to date default null,
  p_nurse_id uuid default null,
  p_service_id uuid default null,
  p_area_id uuid default null,
  p_payment_method public.payment_method default null,
  p_query text default null,
  p_customer_id uuid default null
)
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select jsonb_build_object(
    'count', count(*),
    'revenue', coalesce(sum(price), 0),
    'cash', coalesce(sum(price) filter (where payment_method = 'cash'), 0),
    'electronic', coalesce(sum(price) filter (where payment_method = 'electronic'), 0)
  )
  from public.filter_service_records(p_from, p_to, p_nurse_id, p_service_id, p_area_id,
                                     p_payment_method, p_query, p_customer_id);
$$;

create or replace function public.archive_service_record(record_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Only administrators can archive records' using errcode = '42501';
  end if;
  update public.service_records
     set deleted_at = now(), deleted_by = auth.uid()
   where id = record_id and deleted_at is null;
end;
$$;

create or replace function public.set_customer_archived(customer_id uuid, archived boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Only administrators can archive customers' using errcode = '42501';
  end if;
  update public.customers
     set deleted_at = case when archived then now() end,
         deleted_by = case when archived then auth.uid() end
   where id = customer_id;
end;
$$;

-- -----------------------------------------------------------------------------
-- RPC: legacy Excel import (atomic) and rollback
--
-- payload = {
--   file_name, file_sha256, sheet_name, summary,
--   areas:    [{key, name}],
--   nurses:   [{key, name}],
--   services: [{key, name, default_price}],
--   customers:[{key, full_name, phone, address, area_key, notes, needs_review}],
--   records:  [{row_number, customer_key, nurse_key, service_key, patient_name,
--               price, payment_method, service_date, service_time, notes,
--               legacy_ref, address, area_key, area_name, raw}],
--   skipped:  [{row_number, raw, messages}]
-- }
-- Entities are matched by normalised name / phone first; only missing ones are
-- created (and tagged with the batch so a rollback can remove them).
-- -----------------------------------------------------------------------------

create or replace function public.import_legacy_batch(payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  batch_id uuid;
  item jsonb;
  ref_id uuid;
  rec_id uuid;
  area_map jsonb := '{}'::jsonb;
  nurse_map jsonb := '{}'::jsonb;
  service_map jsonb := '{}'::jsonb;
  customer_map jsonb := '{}'::jsonb;
  created jsonb := jsonb_build_object('areas', 0, 'nurses', 0, 'services', 0, 'customers', 0, 'records', 0);
  matched_customers integer := 0;
begin
  if not public.is_admin() then
    raise exception 'Only administrators can import data' using errcode = '42501';
  end if;

  if exists (select 1 from public.import_batches
              where file_sha256 = payload ->> 'file_sha256' and status = 'committed') then
    raise exception 'This file has already been imported' using errcode = 'P0001', hint = 'already_imported';
  end if;

  insert into public.import_batches (file_name, file_sha256, sheet_name, summary)
  values (payload ->> 'file_name', payload ->> 'file_sha256', payload ->> 'sheet_name',
          coalesce(payload -> 'summary', '{}'::jsonb))
  returning id into batch_id;

  -- Areas
  for item in select * from jsonb_array_elements(coalesce(payload -> 'areas', '[]'::jsonb)) loop
    select id into ref_id from public.areas where name_normalized = public.sanad_normalize(item ->> 'name');
    if ref_id is null then
      insert into public.areas (name, import_batch_id) values (btrim(item ->> 'name'), batch_id)
      returning id into ref_id;
      created := jsonb_set(created, '{areas}', to_jsonb((created ->> 'areas')::int + 1));
    end if;
    area_map := area_map || jsonb_build_object(item ->> 'key', ref_id);
  end loop;

  -- Nurses
  for item in select * from jsonb_array_elements(coalesce(payload -> 'nurses', '[]'::jsonb)) loop
    select id into ref_id from public.nurses where name_normalized = public.sanad_normalize(item ->> 'name');
    if ref_id is null then
      insert into public.nurses (name, import_batch_id) values (btrim(item ->> 'name'), batch_id)
      returning id into ref_id;
      created := jsonb_set(created, '{nurses}', to_jsonb((created ->> 'nurses')::int + 1));
    end if;
    nurse_map := nurse_map || jsonb_build_object(item ->> 'key', ref_id);
  end loop;

  -- Services
  for item in select * from jsonb_array_elements(coalesce(payload -> 'services', '[]'::jsonb)) loop
    select id into ref_id from public.services where name_normalized = public.sanad_normalize(item ->> 'name');
    if ref_id is null then
      insert into public.services (name, default_price, import_batch_id)
      values (btrim(item ->> 'name'), (item ->> 'default_price')::numeric, batch_id)
      returning id into ref_id;
      created := jsonb_set(created, '{services}', to_jsonb((created ->> 'services')::int + 1));
    end if;
    service_map := service_map || jsonb_build_object(item ->> 'key', ref_id);
  end loop;

  -- Customers: phone is the identity; existing customers are never overwritten.
  for item in select * from jsonb_array_elements(coalesce(payload -> 'customers', '[]'::jsonb)) loop
    ref_id := null;
    if nullif(item ->> 'phone', '') is not null then
      select id into ref_id from public.customers where phone = item ->> 'phone';
    end if;
    if ref_id is null then
      insert into public.customers (full_name, phone, address, area_id, notes, needs_review, import_batch_id)
      values (
        btrim(item ->> 'full_name'),
        nullif(item ->> 'phone', ''),
        nullif(btrim(item ->> 'address'), ''),
        (area_map ->> (item ->> 'area_key'))::uuid,
        nullif(item ->> 'notes', ''),
        coalesce((item ->> 'needs_review')::boolean, false),
        batch_id
      )
      returning id into ref_id;
      created := jsonb_set(created, '{customers}', to_jsonb((created ->> 'customers')::int + 1));
    else
      matched_customers := matched_customers + 1;
    end if;
    customer_map := customer_map || jsonb_build_object(item ->> 'key', ref_id);
  end loop;

  -- Records
  for item in select * from jsonb_array_elements(coalesce(payload -> 'records', '[]'::jsonb)) loop
    insert into public.service_records (
      customer_id, nurse_id, service_id, patient_name, price, payment_method,
      service_date, service_time, notes, legacy_ref, import_batch_id,
      address_snapshot, area_id, area_name_snapshot
    ) values (
      (customer_map ->> (item ->> 'customer_key'))::uuid,
      (nurse_map ->> (item ->> 'nurse_key'))::uuid,
      (service_map ->> (item ->> 'service_key'))::uuid,
      nullif(btrim(item ->> 'patient_name'), ''),
      (item ->> 'price')::numeric,
      (item ->> 'payment_method')::public.payment_method,
      (item ->> 'service_date')::date,
      nullif(item ->> 'service_time', '')::time,
      nullif(item ->> 'notes', ''),
      item ->> 'legacy_ref',
      batch_id,
      nullif(btrim(item ->> 'address'), ''),
      (area_map ->> (item ->> 'area_key'))::uuid,
      coalesce(nullif(btrim(item ->> 'area_name'), ''), '')
    )
    returning id into rec_id;

    insert into public.import_rows (batch_id, row_number, outcome, record_id, raw, messages)
    values (batch_id, (item ->> 'row_number')::int, 'imported', rec_id,
            coalesce(item -> 'raw', '{}'::jsonb),
            coalesce(array(select jsonb_array_elements_text(item -> 'messages')), '{}'));
    created := jsonb_set(created, '{records}', to_jsonb((created ->> 'records')::int + 1));
  end loop;

  for item in select * from jsonb_array_elements(coalesce(payload -> 'skipped', '[]'::jsonb)) loop
    insert into public.import_rows (batch_id, row_number, outcome, raw, messages)
    values (batch_id, (item ->> 'row_number')::int, 'skipped',
            coalesce(item -> 'raw', '{}'::jsonb),
            coalesce(array(select jsonb_array_elements_text(item -> 'messages')), '{}'));
  end loop;

  update public.import_batches
     set summary = summary || jsonb_build_object('created', created, 'matched_customers', matched_customers)
   where id = batch_id;

  return jsonb_build_object('batch_id', batch_id, 'created', created, 'matched_customers', matched_customers);
end;
$$;

-- Removes everything a batch created, provided it has not since been reused.
-- Records added by staff after the import are never touched.
create or replace function public.rollback_import_batch(target_batch uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  removed jsonb;
  n_records integer;
  n_customers integer;
  n_areas integer;
  n_nurses integer;
  n_services integer;
begin
  if not public.is_admin() then
    raise exception 'Only administrators can roll back imports' using errcode = '42501';
  end if;
  if not exists (select 1 from public.import_batches where id = target_batch and status = 'committed') then
    raise exception 'Import batch not found or already rolled back' using errcode = 'P0001', hint = 'batch_not_found';
  end if;

  delete from public.service_records where import_batch_id = target_batch;
  get diagnostics n_records = row_count;

  delete from public.customers c
   where c.import_batch_id = target_batch
     and not exists (select 1 from public.service_records r where r.customer_id = c.id);
  get diagnostics n_customers = row_count;
  -- Customers kept because staff added records to them become regular customers.
  update public.customers set import_batch_id = null where import_batch_id = target_batch;

  delete from public.areas a
   where a.import_batch_id = target_batch
     and not exists (select 1 from public.customers c where c.area_id = a.id)
     and not exists (select 1 from public.service_records r where r.area_id = a.id);
  get diagnostics n_areas = row_count;
  update public.areas set import_batch_id = null where import_batch_id = target_batch;

  delete from public.nurses n
   where n.import_batch_id = target_batch
     and not exists (select 1 from public.service_records r where r.nurse_id = n.id);
  get diagnostics n_nurses = row_count;
  update public.nurses set import_batch_id = null where import_batch_id = target_batch;

  delete from public.services s
   where s.import_batch_id = target_batch
     and not exists (select 1 from public.service_records r where r.service_id = s.id);
  get diagnostics n_services = row_count;
  update public.services set import_batch_id = null where import_batch_id = target_batch;

  removed := jsonb_build_object('records', n_records, 'customers', n_customers,
                                'areas', n_areas, 'nurses', n_nurses, 'services', n_services);

  update public.import_batches
     set status = 'rolled_back', rolled_back_at = now(), rolled_back_by = auth.uid(),
         summary = summary || jsonb_build_object('rollback', removed)
   where id = target_batch;

  return removed;
end;
$$;

-- -----------------------------------------------------------------------------
-- Row Level Security
-- -----------------------------------------------------------------------------

alter table public.profiles        enable row level security;
alter table public.areas           enable row level security;
alter table public.nurses          enable row level security;
alter table public.services        enable row level security;
alter table public.customers       enable row level security;
alter table public.service_records enable row level security;
alter table public.import_batches  enable row level security;
alter table public.import_rows     enable row level security;
alter table public.audit_log       enable row level security;

-- profiles
create policy profiles_select on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_admin());
create policy profiles_update_self on public.profiles for update to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

-- areas: any staff member may add one while registering a customer.
create policy areas_select on public.areas for select to authenticated using (public.is_staff());
create policy areas_insert on public.areas for insert to authenticated with check (public.is_staff());
create policy areas_update on public.areas for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- nurses / services: staff may add, only admins edit or (de)activate.
create policy nurses_select on public.nurses for select to authenticated using (public.is_staff());
create policy nurses_insert on public.nurses for insert to authenticated with check (public.is_staff());
create policy nurses_update on public.nurses for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy services_select on public.services for select to authenticated using (public.is_staff());
create policy services_insert on public.services for insert to authenticated with check (public.is_staff());
create policy services_update on public.services for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- customers: staff create & read; admins edit.
create policy customers_select on public.customers for select to authenticated using (public.is_staff());
create policy customers_insert on public.customers for insert to authenticated
  with check (public.is_staff() and not needs_review and import_batch_id is null);
create policy customers_update on public.customers for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- service records: staff create & read; admins edit.
create policy records_select on public.service_records for select to authenticated using (public.is_staff());
create policy records_insert on public.service_records for insert to authenticated
  with check (public.is_staff() and import_batch_id is null and created_by = auth.uid());
create policy records_update on public.service_records for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- import / audit: admins read; writes only through security-definer RPCs.
create policy import_batches_select on public.import_batches for select to authenticated using (public.is_admin());
create policy import_rows_select on public.import_rows for select to authenticated using (public.is_admin());
create policy audit_log_select on public.audit_log for select to authenticated using (public.is_admin());

-- -----------------------------------------------------------------------------
-- Grants: least privilege. No DELETE for API roles; anon gets nothing.
-- -----------------------------------------------------------------------------

revoke all on all tables in schema public from anon, authenticated;
revoke all on all functions in schema public from anon, public;

grant select, update (full_name) on public.profiles to authenticated;
grant update (role, is_active) on public.profiles to authenticated;
grant select, insert, update on public.areas, public.nurses, public.services to authenticated;
grant select, insert, update on public.customers to authenticated;
grant select, insert, update on public.service_records to authenticated;
grant select on public.import_batches, public.import_rows, public.audit_log to authenticated;
grant select on public.customer_overview, public.service_record_details to authenticated;

grant execute on function
  public.sanad_normalize(text),
  public.sanad_is_valid_phone(text),
  public.current_role_name(),
  public.is_staff(),
  public.is_admin(),
  public.search_customers(text, integer),
  public.dashboard_stats(date),
  public.filter_service_records(date, date, uuid, uuid, uuid, public.payment_method, text, uuid),
  public.record_totals(date, date, uuid, uuid, uuid, public.payment_method, text, uuid),
  public.archive_service_record(uuid),
  public.set_customer_archived(uuid, boolean),
  public.import_legacy_batch(jsonb),
  public.rollback_import_batch(uuid)
to authenticated;
