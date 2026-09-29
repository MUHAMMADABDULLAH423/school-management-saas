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

