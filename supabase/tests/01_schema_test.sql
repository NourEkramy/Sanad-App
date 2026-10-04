-- Business-rule, RLS and import tests for the Sanad schema.
-- Each block raises an exception on failure; run via tests/run.sh.

\o /dev/null
\set admin_id '11111111-1111-1111-1111-111111111111'
\set staff_id '22222222-2222-2222-2222-222222222222'

insert into auth.users (id, email, raw_user_meta_data) values
  (:'admin_id', 'admin@sanad.test', '{"full_name":"Admin"}'),
  (:'staff_id', 'staff@sanad.test', '{"full_name":"Staff"}');
update public.profiles set role = 'admin' where id = :'admin_id';

create or replace function pg_temp.act_as(uid uuid) returns void language sql as $$
  select set_config('request.jwt.claim.sub', uid::text, false);
$$;

create or replace function pg_temp.expect_error(sql text, expected_state text) returns void
language plpgsql as $$
begin
  execute sql;
  raise exception 'Expected SQLSTATE % but statement succeeded: %', expected_state, sql;
exception when others then
  if sqlstate <> expected_state then
    raise exception 'Expected SQLSTATE %, got % (%) for: %', expected_state, sqlstate, sqlerrm, sql;
  end if;
end;
$$;
grant execute on function pg_temp.expect_error(text, text) to authenticated;
grant execute on function pg_temp.act_as(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Normalisation helpers
-- ---------------------------------------------------------------------------
do $$ begin
  assert public.sanad_normalize('  أسماء   منصور ') = public.sanad_normalize('اسماء منصور'), 'alef variants';
  assert public.sanad_normalize('غيار عادى') = public.sanad_normalize('غيار عادي'), 'yaa variants';
  assert public.sanad_normalize('تركيب كانيولا  + محلول') = public.sanad_normalize('تركيب كانيولا + محلول'), 'whitespace';
  assert public.sanad_normalize('   ') is null, 'blank → null';
  assert public.sanad_is_valid_phone('01012345678'), 'mobile';
  assert public.sanad_is_valid_phone('034567890'), 'alexandria landline';
  assert not public.sanad_is_valid_phone('0101234567'), 'short mobile';
  assert not public.sanad_is_valid_phone('01312345678'), 'bad operator';
  assert not public.sanad_is_valid_phone('**'), 'placeholder';
end $$;

-- ---------------------------------------------------------------------------
-- Staff workflow
-- ---------------------------------------------------------------------------
select pg_temp.act_as(:'staff_id');
set role authenticated;

insert into public.areas (id, name) values ('aaaaaaaa-0000-0000-0000-000000000001', 'الهانوفيل');
-- Duplicate area (different spelling of the same name) is rejected.
select pg_temp.expect_error($$insert into public.areas (name) values ('  الهانوفيل ')$$, '23505');

insert into public.nurses (id, name) values ('bbbbbbbb-0000-0000-0000-000000000001', 'سلطان');
insert into public.services (id, name, default_price)
  values ('cccccccc-0000-0000-0000-000000000001', 'تركيب كانيولا', 100);

insert into public.customers (id, full_name, phone, address, area_id)
values ('dddddddd-0000-0000-0000-000000000001', 'Ahmed Mohamed', '01012345678', 'Street 1',
        'aaaaaaaa-0000-0000-0000-000000000001');

-- Duplicate phone rejected; invalid phone rejected; staff cannot create flagged customers.
select pg_temp.expect_error($$insert into public.customers (full_name, phone, area_id)
  values ('Other', '01012345678', 'aaaaaaaa-0000-0000-0000-000000000001')$$, '23505');
select pg_temp.expect_error($$insert into public.customers (full_name, phone, area_id)
  values ('Other', '12345', 'aaaaaaaa-0000-0000-0000-000000000001')$$, '23514');
select pg_temp.expect_error($$insert into public.customers (full_name, phone, area_id, needs_review)
  values ('Other', null, 'aaaaaaaa-0000-0000-0000-000000000001', true)$$, '42501');

-- Record: actual price is stored, snapshots captured.
insert into public.service_records (id, customer_id, nurse_id, service_id, price, payment_method,
                                    service_date, service_time)
values ('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-000000000001',
        'bbbbbbbb-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000001',
        500, 'cash', '2026-09-12', '19:30');

do $$
declare r record;
begin
  select * into r from public.service_record_details where id = 'eeeeeeee-0000-0000-0000-000000000001';
  assert r.price = 500, 'actual price kept';
  assert r.nurse_name = 'سلطان', 'nurse snapshot';
  assert r.service_name = 'تركيب كانيولا', 'service snapshot';
  assert r.area_name = 'الهانوفيل', 'area snapshot';
  assert r.customer_address = 'Street 1', 'address snapshot';
  assert r.customer_phone = '01012345678', 'phone via join';
end $$;

-- Required fields / legacy-only values are rejected for normal records.
select pg_temp.expect_error($$insert into public.service_records (customer_id, nurse_id, service_id, price,
  payment_method, service_date, service_time) values ('dddddddd-0000-0000-0000-000000000001',
  'bbbbbbbb-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000001', 100, 'unspecified',
  '2026-09-12', '10:00')$$, '23514');
select pg_temp.expect_error($$insert into public.service_records (customer_id, nurse_id, service_id, price,
  payment_method, service_date) values ('dddddddd-0000-0000-0000-000000000001',
  'bbbbbbbb-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000001', 100, 'cash',
  '2026-09-12')$$, '23514');
select pg_temp.expect_error($$insert into public.service_records (customer_id, nurse_id, service_id, price,
  payment_method, service_date, service_time) values ('dddddddd-0000-0000-0000-000000000001',
  'bbbbbbbb-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000001', -5, 'cash',
  '2026-09-12', '10:00')$$, '23514');

-- Staff cannot edit reference data, customers or records, and can never DELETE.
do $$
declare n int;
begin
  update public.services set default_price = 999 where id = 'cccccccc-0000-0000-0000-000000000001';
  get diagnostics n = row_count;
  assert n = 0, 'staff must not update services';
  update public.customers set address = 'x' where id = 'dddddddd-0000-0000-0000-000000000001';
  get diagnostics n = row_count;
  assert n = 0, 'staff must not update customers';
end $$;
select pg_temp.expect_error($$delete from public.service_records$$, '42501');
select pg_temp.expect_error($$delete from public.customers$$, '42501');
select pg_temp.expect_error($$update public.profiles set role = 'admin' where id = auth.uid()$$, '42501');
select pg_temp.expect_error($$select public.archive_service_record('eeeeeeee-0000-0000-0000-000000000001')$$, '42501');
select pg_temp.expect_error($$select public.import_legacy_batch('{}'::jsonb)$$, '42501');

-- Search: exact, prefix, contains (≥4 digits), Arabic-Indic digits, +20 prefix, name.
do $$ begin
  assert (select count(*) from public.search_customers('01012345678')) = 1, 'exact phone';
  assert (select count(*) from public.search_customers('01012')) = 1, 'prefix';
  assert (select count(*) from public.search_customers('5678')) = 1, 'contains';
  assert (select count(*) from public.search_customers('567')) = 0, 'contains needs ≥4 digits';
  assert (select count(*) from public.search_customers('٠١٠١٢٣٤٥٦٧٨')) = 1, 'arabic digits';
  assert (select count(*) from public.search_customers('+20 101 234 5678')) = 1, 'country code';
  assert (select count(*) from public.search_customers('ahmed')) = 1, 'name';
  assert (select count(*) from public.search_customers('')) = 0, 'empty';
  assert (select record_count from public.search_customers('01012345678')) = 1, 'record count';
end $$;

-- Record filtering and totals (shared by list, totals and export).
insert into public.service_records (customer_id, nurse_id, service_id, price, payment_method,
                                    service_date, service_time, patient_name)
values ('dddddddd-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001',
        'cccccccc-0000-0000-0000-000000000001', 250.50, 'electronic', '2026-09-20', '08:15', 'Mona');

do $$ begin
  assert (select count(*) from public.filter_service_records()) = 2, 'all records';
  assert (select count(*) from public.filter_service_records(p_from => '2026-09-13')) = 1, 'from';
  assert (select count(*) from public.filter_service_records(p_to => '2026-09-12')) = 1, 'to';
  assert (select count(*) from public.filter_service_records(p_payment_method => 'cash')) = 1, 'payment';
  assert (select count(*) from public.filter_service_records(p_query => '5678')) = 2, 'phone query';
  assert (select count(*) from public.filter_service_records(p_query => '٥٦٧٨')) = 2, 'arabic digits';
  assert (select count(*) from public.filter_service_records(p_query => 'ahmed')) = 2, 'name query';
  assert (select count(*) from public.filter_service_records(p_query => 'mona')) = 1, 'patient query';
  assert (select count(*) from public.filter_service_records(p_area_id => 'aaaaaaaa-0000-0000-0000-000000000001')) = 2,
    'area snapshot id';
  assert (select (public.record_totals() ->> 'revenue')::numeric) = 750.50, 'revenue';
  assert (select (public.record_totals() ->> 'cash')::numeric) = 500, 'cash';
  assert (select (public.record_totals() ->> 'electronic')::numeric) = 250.50, 'electronic';
  assert (select (public.record_totals(p_query => 'nobody') ->> 'count')::int) = 0, 'no match';
end $$;

reset role;

-- ---------------------------------------------------------------------------
-- Admin: history is immune to reference-data changes
-- ---------------------------------------------------------------------------
select pg_temp.act_as(:'admin_id');
set role authenticated;

update public.services set default_price = 150, name = 'تركيب كانيولا (جديد)'
 where id = 'cccccccc-0000-0000-0000-000000000001';
update public.nurses set name = 'سلطان أحمد' where id = 'bbbbbbbb-0000-0000-0000-000000000001';
update public.areas set name = 'Hannoville' where id = 'aaaaaaaa-0000-0000-0000-000000000001';
update public.customers set address = 'New street' where id = 'dddddddd-0000-0000-0000-000000000001';

do $$
declare r record;
begin
  select * into r from public.service_record_details where id = 'eeeeeeee-0000-0000-0000-000000000001';
  assert r.price = 500, 'price unchanged by default price change';
  assert r.service_name = 'تركيب كانيولا', 'service name frozen';
  assert r.nurse_name = 'سلطان', 'nurse name frozen';
  assert r.area_name = 'الهانوفيل', 'area name frozen';
  assert r.customer_address = 'Street 1', 'address frozen';
end $$;

-- Inactive nurse cannot be used for new records.
update public.nurses set is_active = false where id = 'bbbbbbbb-0000-0000-0000-000000000001';
select pg_temp.expect_error($$insert into public.service_records (customer_id, nurse_id, service_id, price,
  payment_method, service_date, service_time) values ('dddddddd-0000-0000-0000-000000000001',
  'bbbbbbbb-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000001', 100, 'cash',
  '2026-09-13', '10:00')$$, 'P0001');
update public.nurses set is_active = true where id = 'bbbbbbbb-0000-0000-0000-000000000001';

-- Soft delete keeps the row and writes the audit log.
select public.archive_service_record('eeeeeeee-0000-0000-0000-000000000001');
do $$ begin
  assert (select deleted_at is not null from public.service_records
           where id = 'eeeeeeee-0000-0000-0000-000000000001'), 'soft deleted';
  assert (select count(*) from public.audit_log
           where row_id = 'eeeeeeee-0000-0000-0000-000000000001') >= 1, 'audited';
  assert (select (public.dashboard_stats('2026-09-12') ->> 'today_records')::int) = 0, 'archived excluded';
end $$;
-- Admin cannot demote themselves.
select pg_temp.expect_error($$update public.profiles set role = 'staff' where id = auth.uid()$$, '42501');

-- ---------------------------------------------------------------------------
-- Import: matches existing data, creates missing, is atomic and reversible
-- ---------------------------------------------------------------------------
do $$
declare
  result jsonb;
  batch uuid;
  payload jsonb := $json${
    "file_name": "sanad.xlsx", "file_sha256": "abc123", "sheet_name": "سجل الزيارات",
    "summary": {"rows": 4},
    "areas": [{"key": "a1", "name": "Hannoville"}, {"key": "a2", "name": "أكتوبر"}],
    "nurses": [{"key": "n1", "name": "سلطان أحمد"}, {"key": "n2", "name": "يوسف"}],
    "services": [{"key": "s1", "name": "غيار عادى", "default_price": 150}],
    "customers": [
      {"key": "c1", "full_name": "Ahmed (excel)", "phone": "01012345678", "address": "x", "area_key": "a1"},
      {"key": "c2", "full_name": "ماريا", "phone": "01550000000", "address": "ش 19", "area_key": "a2"},
      {"key": "c3", "full_name": "حالة", "phone": null, "address": null, "area_key": "a1", "needs_review": true}
    ],
    "records": [
      {"row_number": 4, "customer_key": "c1", "nurse_key": "n1", "service_key": "s1", "price": 120,
       "payment_method": "unspecified", "service_date": "2026-06-20", "service_time": "21:00",
       "legacy_ref": "3", "address": "old address", "area_key": "a1", "area_name": "الهانوفيل", "raw": {"A": "3"}},
      {"row_number": 5, "customer_key": "c2", "nurse_key": "n2", "service_key": "s1", "price": 155,
       "payment_method": "unspecified", "service_date": "2026-06-22", "service_time": null,
       "legacy_ref": "4", "address": "ش 19", "area_key": "a2", "area_name": "أكتوبر", "raw": {"A": "4"},
       "messages": ["time_missing"]},
      {"row_number": 6, "customer_key": "c3", "nurse_key": "n2", "service_key": "s1", "price": 50,
       "payment_method": "unspecified", "service_date": "2026-08-05", "service_time": "15:00",
       "legacy_ref": "116", "address": null, "area_key": "a1", "area_name": "الهانوفيل", "raw": {"A": "116"}}
    ],
    "skipped": [{"row_number": 7, "raw": {"A": "x"}, "messages": ["date_invalid"]}]
  }$json$::jsonb;
begin
  result := public.import_legacy_batch(payload);
  batch := (result ->> 'batch_id')::uuid;
  assert (result -> 'created' ->> 'records')::int = 3, 'records created';
  assert (result -> 'created' ->> 'customers')::int = 2, 'existing phone matched, 2 new';
  assert (result ->> 'matched_customers')::int = 1, 'one matched';
  assert (result -> 'created' ->> 'areas')::int = 1, 'Hannoville matched, أكتوبر created';
  assert (result -> 'created' ->> 'nurses')::int = 1, 'renamed nurse matched';
  assert (select full_name from public.customers where phone = '01012345678') = 'Ahmed Mohamed',
    'existing customer not overwritten';
  assert (select area_name from public.service_record_details where legacy_ref = '3') = 'الهانوفيل',
    'legacy area name kept';
  assert (select area_id from public.service_record_details where legacy_ref = '4') =
         (select id from public.areas where name = 'أكتوبر'), 'legacy area id resolved';
  assert (select customer_address from public.service_record_details where legacy_ref = '3') = 'old address',
    'legacy address kept';
  assert (select count(*) from public.import_rows where batch_id = batch) = 4, 'every row logged';

  -- Same file twice is refused.
  begin
    perform public.import_legacy_batch(payload);
    raise exception 'duplicate import should fail';
  exception when sqlstate 'P0001' then null;
  end;

  -- Staff adds a record to an imported customer, then the batch is rolled back.
  perform set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
  insert into public.service_records (customer_id, nurse_id, service_id, price, payment_method,
                                      service_date, service_time)
  select id, 'bbbbbbbb-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000001',
         200, 'electronic', '2026-10-01', '12:00'
    from public.customers where phone = '01550000000';
  perform set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);

  result := public.rollback_import_batch(batch);
  assert (result ->> 'records')::int = 3, 'imported records removed';
  assert (result ->> 'customers')::int = 1, 'customer with new record kept';
  assert exists (select 1 from public.customers where phone = '01550000000' and import_batch_id is null),
    'kept customer detached from batch';
  assert exists (select 1 from public.customers where phone = '01012345678'), 'pre-existing untouched';
  assert (select status from public.import_batches where id = batch) = 'rolled_back', 'batch marked';
  assert (select count(*) from public.service_records where import_batch_id is not null) = 0, 'clean';

  -- After rollback the same file may be imported again.
  result := public.import_legacy_batch(payload);
  assert (result -> 'created' ->> 'records')::int = 3, 're-import works';
end $$;

reset role;
\o
\echo 'schema tests passed'
