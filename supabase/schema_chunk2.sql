-- ================= Authorization helpers =================
-- SECURITY DEFINER helpers avoid recursive RLS. Revoked from anon/public;
-- granted to authenticated only.

create or replace function app_private.current_role()
returns text language sql stable security definer
set search_path = pg_catalog, public as $$
  select u.role from public.users u
  where u.id = auth.uid() and u.status = 'active'
$$;

create or replace function app_private.current_school_id()
returns uuid language sql stable security definer
set search_path = pg_catalog, public as $$
  select u.school_id from public.users u
  where u.id = auth.uid() and u.status = 'active'
$$;

create or replace function app_private.is_super_admin()
returns boolean language sql stable security definer
set search_path = pg_catalog, public as $$
  select coalesce(app_private.current_role() = 'super_admin', false)
$$;

create or replace function app_private.is_school_admin()
returns boolean language sql stable security definer
set search_path = pg_catalog, public as $$
  select coalesce(app_private.current_role() = 'school_admin', false)
$$;

create or replace function app_private.current_staff_id()
returns uuid language sql stable security definer
set search_path = pg_catalog, public as $$
  select s.id from public.staff s
  join public.users u on u.id = s.user_id
  where s.user_id = auth.uid()
    and u.status = 'active' and u.role = 'teacher'
$$;

create or replace function app_private.is_parent_of_student(p_student_id uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public as $$
  select exists (
    select 1 from public.parent_student_map psm
    join public.users u on u.id = psm.parent_user_id
    where psm.parent_user_id = auth.uid()
      and psm.student_id = p_student_id
      and u.status = 'active' and u.role = 'parent'
  )
$$;

create or replace function app_private.is_teacher_for_class(p_class_id uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public as $$
  select exists (
    select 1 from public.teacher_class_map tcm
    where tcm.staff_id = app_private.current_staff_id()
      and tcm.class_id = p_class_id
  )
$$;

create or replace function app_private.is_teacher_for_student(p_student_id uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public as $$
  select exists (
    select 1 from public.students s
    join public.teacher_class_map tcm on tcm.class_id = s.class_id
    where s.id = p_student_id
      and tcm.staff_id = app_private.current_staff_id()
  )
$$;

create or replace function app_private.is_teacher_for_subject(
  p_student_id uuid, p_subject text)
returns boolean language sql stable security definer
set search_path = pg_catalog, public as $$
  select exists (
    select 1 from public.students s
    join public.teacher_class_map tcm on tcm.class_id = s.class_id
    where s.id = p_student_id
      and tcm.staff_id = app_private.current_staff_id()
      and lower(btrim(tcm.subject)) = lower(btrim(p_subject))
  )
$$;

create or replace function app_private.is_parent_of_class(p_class_id uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public as $$
  select exists (
    select 1 from public.parent_student_map psm
    join public.students s on s.id = psm.student_id
    join public.users u on u.id = psm.parent_user_id
    where psm.parent_user_id = auth.uid()
      and s.class_id = p_class_id
      and u.status = 'active' and u.role = 'parent'
  )
$$;

revoke all on all functions in schema app_private from public, anon;
grant usage on schema app_private to authenticated;
grant execute on all functions in schema app_private to authenticated;

-- ================= Triggers =================

create or replace function app_private.set_updated_at()
returns trigger language plpgsql
set search_path = pg_catalog, public as $$
begin new.updated_at := now(); return new; end;
$$;

-- Voucher numbers: FV-<school short id>-<sequence>, immutable afterwards.
create or replace function app_private.assign_fee_voucher_no()
returns trigger language plpgsql security definer
set search_path = pg_catalog, public as $$
begin
  if tg_op = 'INSERT' then
    new.voucher_no := 'FV-' || substr(new.school_id::text, 1, 8)
                      || '-' || nextval('public.fee_voucher_no_seq')::text;
  elsif new.voucher_no is distinct from old.voucher_no then
    raise exception 'voucher_no is immutable';
  end if;
  return new;
end;
$$;

create or replace function app_private.assign_fee_receipt_no()
returns trigger language plpgsql security definer
set search_path = pg_catalog, public as $$
begin
  if tg_op = 'INSERT' then
    new.receipt_no := nextval('public.fee_receipt_no_seq');
  elsif new.receipt_no is distinct from old.receipt_no then
    raise exception 'receipt_no is immutable';
  end if;
  return new;
end;
$$;

-- Keep voucher status in sync whenever payments change.
create or replace function app_private.sync_voucher_status()
returns trigger language plpgsql security definer
set search_path = pg_catalog, public as $$
declare
  v_voucher_id uuid;
  v_total numeric(12,2);
  v_paid numeric(12,2);
begin
  v_voucher_id := coalesce(new.voucher_id, old.voucher_id);
  select (amount - discount) into v_total
    from public.fee_vouchers where id = v_voucher_id;
  select coalesce(sum(amount), 0) into v_paid
    from public.fee_payments where voucher_id = v_voucher_id;
  update public.fee_vouchers
     set status = case
                    when v_paid <= 0 then 'unpaid'
                    when v_paid >= v_total then 'paid'
                    else 'partial'
                  end,
         updated_at = now()
   where id = v_voucher_id;
  return coalesce(new, old);
end;
$$;

-- Non-super-admins cannot touch plan/status of a school.
create or replace function app_private.protect_school_billing()
returns trigger language plpgsql
set search_path = pg_catalog, public as $$
begin
  if not app_private.is_super_admin() then
    new.plan := old.plan;
    new.status := old.status;
  end if;
  return new;
end;
$$;

-- Non-school-admins cannot change their own role/school/status.
create or replace function app_private.protect_user_identity()
returns trigger language plpgsql
set search_path = pg_catalog, public as $$
begin
  if not app_private.is_super_admin() and not app_private.is_school_admin() then
    new.role := old.role;
    new.school_id := old.school_id;
    new.status := old.status;
  end if;
  return new;
end;
$$;

create or replace function app_private.write_audit_log()
returns trigger language plpgsql security definer
set search_path = pg_catalog, public as $$
declare v_old jsonb; v_new jsonb; v_record_id uuid; v_school uuid;
begin
  if tg_op = 'INSERT' then v_new := to_jsonb(new); v_record_id := new.id;
  elsif tg_op = 'UPDATE' then v_old := to_jsonb(old); v_new := to_jsonb(new); v_record_id := new.id;
  else v_old := to_jsonb(old); v_record_id := old.id; end if;
  begin
    v_school := coalesce(
      (case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end)->>'school_id'
    )::uuid;
  exception when others then v_school := null; end;
  insert into public.audit_logs (school_id, actor_id, action, table_name, record_id, old_data, new_data)
  values (v_school, auth.uid(), tg_op, tg_table_schema || '.' || tg_table_name, v_record_id, v_old, v_new);
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

revoke all on function app_private.assign_fee_voucher_no() from public, anon, authenticated;
revoke all on function app_private.assign_fee_receipt_no() from public, anon, authenticated;
revoke all on function app_private.sync_voucher_status() from public, anon, authenticated;
revoke all on function app_private.write_audit_log() from public, anon, authenticated;

-- updated_at triggers
do $$
declare t text;
begin
  foreach t in array array[
    'schools','users','classes','students','staff',
    'exams','marks','fee_vouchers','notices','attendance']
  loop
    execute format(
      'create or replace trigger %I_updated_at before update on public.%I
       for each row execute function app_private.set_updated_at()', t||'_ts', t);
  end loop;
end $$;

create or replace trigger fee_vouchers_assign_no
before insert or update of voucher_no on public.fee_vouchers
for each row execute function app_private.assign_fee_voucher_no();

create or replace trigger fee_payments_assign_receipt
before insert or update of receipt_no on public.fee_payments
for each row execute function app_private.assign_fee_receipt_no();

create or replace trigger fee_payments_sync_status
after insert or update or delete on public.fee_payments
for each row execute function app_private.sync_voucher_status();

create or replace trigger schools_protect_billing
before update on public.schools
for each row execute function app_private.protect_school_billing();

create or replace trigger users_protect_identity
before update on public.users
for each row execute function app_private.protect_user_identity();

-- audit on business tables
do $$
declare t text;
begin
  foreach t in array array[
    'schools','users','classes','students','staff','teacher_class_map',
    'parent_student_map','attendance','exams','marks',
    'fee_vouchers','fee_payments','notices']
  loop
    execute format(
      'create or replace trigger audit_%I after insert or update or delete
       on public.%I for each row execute function app_private.write_audit_log()',
      t, t);
  end loop;
end $$;

