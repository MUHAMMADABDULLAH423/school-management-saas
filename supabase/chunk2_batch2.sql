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

