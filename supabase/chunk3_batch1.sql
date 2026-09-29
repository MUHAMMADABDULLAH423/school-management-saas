-- ================= RLS =================

alter table public.schools enable row level security;
alter table public.users enable row level security;
alter table public.classes enable row level security;
alter table public.students enable row level security;
alter table public.staff enable row level security;
alter table public.teacher_class_map enable row level security;
alter table public.parent_student_map enable row level security;
alter table public.attendance enable row level security;
alter table public.exams enable row level security;
alter table public.marks enable row level security;
alter table public.fee_vouchers enable row level security;
alter table public.fee_payments enable row level security;
alter table public.notices enable row level security;
alter table public.audit_logs enable row level security;

-- Broad API grants; RLS policies are the enforcement layer.
revoke all on all tables in schema public from anon;
grant select, insert, update, delete on
  public.schools, public.users, public.classes, public.students, public.staff,
  public.teacher_class_map, public.parent_student_map, public.attendance,
  public.exams, public.marks, public.fee_vouchers, public.fee_payments,
  public.notices
  to authenticated;
grant select on public.audit_logs to authenticated;

-- Rerunnable: drop our own policies first.
do $policy_cleanup$
declare r record;
begin
  for r in
    select schemaname, tablename, policyname from pg_policies
    where schemaname = 'public' and policyname like 'sms\_%' escape '\'
  loop
    execute format('drop policy %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $policy_cleanup$;

-- ---------- SCHOOLS ----------
create policy sms_schools_super_all on public.schools
for all to authenticated
using (app_private.is_super_admin()) with check (app_private.is_super_admin());

create policy sms_schools_own_read on public.schools
for select to authenticated
using (id = app_private.current_school_id());

create policy sms_schools_own_update on public.schools
for update to authenticated
using (id = app_private.current_school_id() and app_private.is_school_admin())
with check (id = app_private.current_school_id() and app_private.is_school_admin());
-- (protect_school_billing trigger keeps plan/status super-admin-only)

-- ---------- USERS ----------
create policy sms_users_super_all on public.users
for all to authenticated
using (app_private.is_super_admin()) with check (app_private.is_super_admin());

create policy sms_users_school_admin_all on public.users
for all to authenticated
using (app_private.is_school_admin()
       and school_id = app_private.current_school_id()
       and role <> 'super_admin')
with check (app_private.is_school_admin()
       and school_id = app_private.current_school_id()
       and role <> 'super_admin');

create policy sms_users_self_read on public.users
for select to authenticated
using (id = auth.uid() and status = 'active');

-- ---------- CLASSES ----------
create policy sms_classes_super_all on public.classes
for all to authenticated
using (app_private.is_super_admin()) with check (app_private.is_super_admin());

