/*
  School Management SaaS — Multi-tenant Supabase/PostgreSQL schema
  =================================================================
  Stack: Next.js (App Router) + Tailwind + Supabase (Postgres + Auth)

  Tenancy model
  -------------
  • public.schools is the tenant table.
  • EVERY application table carries school_id (NOT NULL, except users where
    super_admin rows have school_id = NULL).
  • Tenant isolation is enforced by Row Level Security on every table —
    no application query can ever read or write another school's rows.

  Roles
  -----
  • super_admin  — manages schools; school_id IS NULL; full cross-tenant read.
  • school_admin — full control inside their own school (principal/admin).
  • teacher      — scoped to assigned classes (attendance, marks for own subjects).
  • parent       — READ-ONLY access to their mapped children.

  Auth notes
  ----------
  • Supabase Auth stores passwords (bcrypt) + recovery flow; this schema never
    stores passwords.
  • Authorization uses the server-maintained public.users.role / status, never
    the user-editable raw_user_meta_data.
  • Provision Auth users first (Supabase dashboard or Admin API), then insert
    the matching public.users row with the same UUID.

  Run this in a fresh Supabase project's SQL Editor as the database owner.
*/

begin;

create extension if not exists pgcrypto;
create schema if not exists app_private;
revoke all on schema app_private from public;

-- ================= Tenant table =================

create table if not exists public.schools (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  name_ur text,
  address text,
  phone text,
  email text,
  logo_url text,
  plan text not null default 'trial'
    check (plan in ('trial', 'basic', 'standard', 'premium')),
  status text not null default 'active'
    check (status in ('active', 'suspended', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ================= Users & roles =================

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  school_id uuid references public.schools(id) on delete restrict,
  email text not null,
  full_name text not null,
  role text not null
    check (role in ('super_admin', 'school_admin', 'teacher', 'parent')),
  status text not null default 'active'
    check (status in ('active', 'inactive', 'suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint users_school_role_ck check (
    (role = 'super_admin' and school_id is null)
    or (role <> 'super_admin' and school_id is not null)
  )
);

create unique index if not exists users_email_lower_uq
  on public.users (lower(email));
create index if not exists users_school_id_idx on public.users(school_id);
create index if not exists users_role_idx on public.users(role);

-- ================= School structure =================

create table if not exists public.classes (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  name text not null,                       -- e.g. "Grade 5" / "Class 8"
  section text not null default 'A',
  academic_year text not null,               -- e.g. "2026-27"
  class_teacher_id uuid,                    -- set after staff exists
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, name, section, academic_year)
);
create index if not exists classes_school_id_idx on public.classes(school_id);

create table if not exists public.students (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  admission_no text not null,
  name text not null,
  name_ur text,
  father_name text,
  gender text check (gender in ('male', 'female', 'other')),
  date_of_birth date,
  class_id uuid not null references public.classes(id) on delete restrict,
  phone text,
  address text,
  status text not null default 'active'
    check (status in ('active', 'inactive', 'graduated', 'withdrawn', 'struck_off')),
  admitted_on date not null default current_date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, admission_no)
);
create index if not exists students_school_id_idx on public.students(school_id);
create index if not exists students_class_id_idx on public.students(class_id);
create index if not exists students_status_idx on public.students(school_id, status);

create table if not exists public.staff (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  user_id uuid not null unique references public.users(id) on delete cascade,
  employee_no text,
  name text not null,
  designation text not null default 'teacher',
  subjects text[] not null default '{}',
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, employee_no)
);
create index if not exists staff_school_id_idx on public.staff(school_id);
create index if not exists staff_user_id_idx on public.staff(user_id);

alter table public.classes
  add constraint classes_class_teacher_fk
  foreign key (class_teacher_id) references public.staff(id) on delete set null;

create table if not exists public.teacher_class_map (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  staff_id uuid not null references public.staff(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete cascade,
  subject text not null,
  created_at timestamptz not null default now(),
  unique (school_id, staff_id, class_id, subject)
);
create index if not exists teacher_class_map_school_idx
  on public.teacher_class_map(school_id);
create index if not exists teacher_class_map_staff_idx
  on public.teacher_class_map(staff_id);

create table if not exists public.parent_student_map (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  parent_user_id uuid not null references public.users(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  relation text not null
    check (relation in ('father', 'mother', 'guardian', 'other')),
  created_at timestamptz not null default now(),
  unique (school_id, parent_user_id, student_id)
);
create index if not exists parent_student_map_school_idx
  on public.parent_student_map(school_id);
create index if not exists parent_student_map_parent_idx
  on public.parent_student_map(parent_user_id);
create index if not exists parent_student_map_student_idx
  on public.parent_student_map(student_id);

-- ================= Attendance =================

create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete cascade,
  date date not null,
  status text not null
    check (status in ('present', 'absent', 'late', 'leave', 'holiday')),
  marked_by uuid not null references public.staff(id) on delete restrict,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, student_id, date)
);
create index if not exists attendance_school_date_idx
  on public.attendance(school_id, date desc);
create index if not exists attendance_student_date_idx
  on public.attendance(student_id, date desc);
create index if not exists attendance_class_date_idx
  on public.attendance(class_id, date desc);

-- ================= Exams & results =================

create table if not exists public.exams (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  name text not null,                        -- "First Term", "Annual"
  name_ur text,
  academic_year text not null,
  starts_on date,
  ends_on date,
  result_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, name, academic_year)
);
create index if not exists exams_school_id_idx on public.exams(school_id);

create table if not exists public.marks (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  exam_id uuid not null references public.exams(id) on delete cascade,
  subject text not null,
  marks_obtained numeric(7,2) not null check (marks_obtained >= 0),
  total_marks numeric(7,2) not null check (total_marks > 0),
  entered_by uuid not null references public.staff(id) on delete restrict,
  entered_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint marks_not_over_total check (marks_obtained <= total_marks),
  unique (school_id, student_id, exam_id, subject)
);
create index if not exists marks_school_student_idx
  on public.marks(school_id, student_id);
create index if not exists marks_exam_idx on public.marks(exam_id);

-- ================= Fees =================

create sequence if not exists public.fee_voucher_no_seq
  as bigint start with 1001 increment by 1 minvalue 1 no maxvalue no cycle;
create sequence if not exists public.fee_receipt_no_seq
  as bigint start with 1 increment by 1 minvalue 1 no maxvalue no cycle;

create table if not exists public.fee_vouchers (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete restrict,
  voucher_no text not null unique,
  title text not null,                       -- "October 2026 Fee"
  month date not null check (month = date_trunc('month', month)::date),
  amount numeric(12,2) not null check (amount >= 0),
  discount numeric(12,2) not null default 0 check (discount >= 0),
  due_date date not null,
  status text not null default 'unpaid'
    check (status in ('unpaid', 'partial', 'paid', 'waived', 'overdue')),
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, student_id, month)
);
create index if not exists fee_vouchers_school_idx
  on public.fee_vouchers(school_id);
create index if not exists fee_vouchers_student_month_idx
  on public.fee_vouchers(student_id, month desc);
create index if not exists fee_vouchers_status_idx
  on public.fee_vouchers(school_id, status);

create table if not exists public.fee_payments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  voucher_id uuid not null references public.fee_vouchers(id) on delete restrict,
  amount numeric(12,2) not null check (amount > 0),
  method text not null default 'cash'
    check (method in ('cash', 'bank', 'online', 'other')),
  receipt_no bigint not null unique,
  paid_at timestamptz not null default now(),
  collected_by uuid references public.users(id) on delete set null,
  notes text,
  created_at timestamptz not null default now()
);
create index if not exists fee_payments_school_idx
  on public.fee_payments(school_id);
create index if not exists fee_payments_voucher_idx
  on public.fee_payments(voucher_id);

alter sequence public.fee_voucher_no_seq owned by public.fee_vouchers.voucher_no;
alter sequence public.fee_receipt_no_seq owned by public.fee_payments.receipt_no;
revoke all on sequence public.fee_voucher_no_seq, public.fee_receipt_no_seq
  from public, anon, authenticated;

-- ================= Notices =================

create table if not exists public.notices (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  title text not null,
  title_ur text,
  content text not null,
  content_ur text,
  audience text not null
    check (audience in ('school_wide', 'teachers', 'parents', 'class_specific')),
  class_id uuid references public.classes(id) on delete cascade,
  posted_by uuid not null references public.users(id) on delete restrict,
  published_at timestamptz not null default now(),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint notices_audience_class_ck check (
    (audience = 'class_specific' and class_id is not null)
    or (audience <> 'class_specific' and class_id is null)
  ),
  constraint notices_expiry_ck check (expires_at is null or expires_at > published_at)
);
create index if not exists notices_school_idx
  on public.notices(school_id, published_at desc);

-- ================= Audit =================

create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  school_id uuid references public.schools(id) on delete set null,
  actor_id uuid references public.users(id) on delete set null,
  action text not null check (action in ('INSERT', 'UPDATE', 'DELETE')),
  table_name text not null,
  record_id uuid,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);
create index if not exists audit_logs_school_created_idx
  on public.audit_logs(school_id, created_at desc);

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

create policy sms_classes_school_admin_all on public.classes
for all to authenticated
using (app_private.is_school_admin() and school_id = app_private.current_school_id())
with check (app_private.is_school_admin() and school_id = app_private.current_school_id());

create policy sms_classes_related_read on public.classes
for select to authenticated
using (school_id = app_private.current_school_id()
  and (app_private.is_teacher_for_class(id) or app_private.is_parent_of_class(id)));

-- ---------- STUDENTS ----------
create policy sms_students_super_all on public.students
for all to authenticated
using (app_private.is_super_admin()) with check (app_private.is_super_admin());

create policy sms_students_school_admin_all on public.students
for all to authenticated
using (app_private.is_school_admin() and school_id = app_private.current_school_id())
with check (app_private.is_school_admin() and school_id = app_private.current_school_id());

create policy sms_students_teacher_read on public.students
for select to authenticated
using (school_id = app_private.current_school_id()
  and app_private.is_teacher_for_student(id));

create policy sms_students_parent_read on public.students
for select to authenticated
using (school_id = app_private.current_school_id()
  and app_private.is_parent_of_student(id));

-- ---------- STAFF ----------
create policy sms_staff_super_all on public.staff
for all to authenticated
using (app_private.is_super_admin()) with check (app_private.is_super_admin());

create policy sms_staff_school_admin_all on public.staff
for all to authenticated
using (app_private.is_school_admin() and school_id = app_private.current_school_id())
with check (app_private.is_school_admin() and school_id = app_private.current_school_id());

create policy sms_staff_self_read on public.staff
for select to authenticated
using (user_id = auth.uid());

-- ---------- TEACHER_CLASS_MAP ----------
create policy sms_tcm_super_all on public.teacher_class_map
for all to authenticated
using (app_private.is_super_admin()) with check (app_private.is_super_admin());

create policy sms_tcm_school_admin_all on public.teacher_class_map
for all to authenticated
using (app_private.is_school_admin() and school_id = app_private.current_school_id())
with check (app_private.is_school_admin() and school_id = app_private.current_school_id());

create policy sms_tcm_self_read on public.teacher_class_map
for select to authenticated
using (staff_id = app_private.current_staff_id());

-- ---------- PARENT_STUDENT_MAP ----------
create policy sms_psm_super_all on public.parent_student_map
for all to authenticated
using (app_private.is_super_admin()) with check (app_private.is_super_admin());

create policy sms_psm_school_admin_all on public.parent_student_map
for all to authenticated
using (app_private.is_school_admin() and school_id = app_private.current_school_id())
with check (app_private.is_school_admin() and school_id = app_private.current_school_id());

create policy sms_psm_self_read on public.parent_student_map
for select to authenticated
using (parent_user_id = auth.uid());

-- ---------- ATTENDANCE ----------
create policy sms_attendance_super_all on public.attendance
for all to authenticated
using (app_private.is_super_admin()) with check (app_private.is_super_admin());

create policy sms_attendance_school_admin_all on public.attendance
for all to authenticated
using (app_private.is_school_admin() and school_id = app_private.current_school_id())
with check (app_private.is_school_admin() and school_id = app_private.current_school_id());

create policy sms_attendance_teacher_read on public.attendance
for select to authenticated
using (school_id = app_private.current_school_id()
  and app_private.is_teacher_for_student(student_id));

create policy sms_attendance_teacher_write on public.attendance
for insert to authenticated
with check (school_id = app_private.current_school_id()
  and marked_by = app_private.current_staff_id()
  and app_private.is_teacher_for_student(student_id));

create policy sms_attendance_teacher_update on public.attendance
for update to authenticated
using (school_id = app_private.current_school_id()
  and app_private.is_teacher_for_student(student_id))
with check (school_id = app_private.current_school_id()
  and marked_by = app_private.current_staff_id()
  and app_private.is_teacher_for_student(student_id));

create policy sms_attendance_parent_read on public.attendance
for select to authenticated
using (school_id = app_private.current_school_id()
  and app_private.is_parent_of_student(student_id));

-- ---------- EXAMS ----------
create policy sms_exams_super_all on public.exams
for all to authenticated
using (app_private.is_super_admin()) with check (app_private.is_super_admin());

create policy sms_exams_school_admin_all on public.exams
for all to authenticated
using (app_private.is_school_admin() and school_id = app_private.current_school_id())
with check (app_private.is_school_admin() and school_id = app_private.current_school_id());

-- Teachers and parents see exams only when results are published.
create policy sms_exams_published_read on public.exams
for select to authenticated
using (school_id = app_private.current_school_id()
  and result_published = true);

-- ---------- MARKS ----------
create policy sms_marks_super_all on public.marks
for all to authenticated
using (app_private.is_super_admin()) with check (app_private.is_super_admin());

create policy sms_marks_school_admin_all on public.marks
for all to authenticated
using (app_private.is_school_admin() and school_id = app_private.current_school_id())
with check (app_private.is_school_admin() and school_id = app_private.current_school_id());

create policy sms_marks_teacher_rw on public.marks
for all to authenticated
using (school_id = app_private.current_school_id()
  and app_private.is_teacher_for_subject(student_id, subject)
  and entered_by = app_private.current_staff_id())
with check (school_id = app_private.current_school_id()
  and app_private.is_teacher_for_subject(student_id, subject)
  and entered_by = app_private.current_staff_id());

create policy sms_marks_teacher_read on public.marks
for select to authenticated
using (school_id = app_private.current_school_id()
  and app_private.is_teacher_for_student(student_id));

create policy sms_marks_parent_read on public.marks
for select to authenticated
using (school_id = app_private.current_school_id()
  and app_private.is_parent_of_student(student_id)
  and exists (select 1 from public.exams e
              where e.id = exam_id and e.result_published = true));

-- ---------- FEE VOUCHERS ----------
create policy sms_vouchers_super_all on public.fee_vouchers
for all to authenticated
using (app_private.is_super_admin()) with check (app_private.is_super_admin());

create policy sms_vouchers_school_admin_all on public.fee_vouchers
for all to authenticated
using (app_private.is_school_admin() and school_id = app_private.current_school_id())
with check (app_private.is_school_admin() and school_id = app_private.current_school_id());

create policy sms_vouchers_parent_read on public.fee_vouchers
for select to authenticated
using (school_id = app_private.current_school_id()
  and app_private.is_parent_of_student(student_id));

-- ---------- FEE PAYMENTS ----------
create policy sms_payments_super_all on public.fee_payments
for all to authenticated
using (app_private.is_super_admin()) with check (app_private.is_super_admin());

create policy sms_payments_school_admin_all on public.fee_payments
for all to authenticated
using (app_private.is_school_admin() and school_id = app_private.current_school_id())
with check (app_private.is_school_admin() and school_id = app_private.current_school_id());

create policy sms_payments_parent_read on public.fee_payments
for select to authenticated
using (school_id = app_private.current_school_id()
  and exists (select 1 from public.fee_vouchers v
              where v.id = voucher_id
                and app_private.is_parent_of_student(v.student_id)));

-- ---------- NOTICES ----------
create policy sms_notices_super_all on public.notices
for all to authenticated
using (app_private.is_super_admin()) with check (app_private.is_super_admin());

create policy sms_notices_school_admin_all on public.notices
for all to authenticated
using (app_private.is_school_admin() and school_id = app_private.current_school_id())
with check (app_private.is_school_admin() and school_id = app_private.current_school_id());

create policy sms_notices_relevant_read on public.notices
for select to authenticated
using (school_id = app_private.current_school_id()
  and (expires_at is null or expires_at > now())
  and (
    audience in ('school_wide', 'teachers', 'parents')
    or (audience = 'class_specific'
        and (app_private.is_teacher_for_class(class_id)
             or app_private.is_parent_of_class(class_id)))
  ));

-- ---------- AUDIT LOGS (read-only) ----------
create policy sms_audit_super_all on public.audit_logs
for select to authenticated
using (app_private.is_super_admin());

create policy sms_audit_school_admin_read on public.audit_logs
for select to authenticated
using (app_private.is_school_admin()
  and school_id = app_private.current_school_id());

commit;

-- ================= Bootstrap (run manually) =================
-- 1. Create the super-admin in Supabase Auth (dashboard or Admin API),
--    then insert the matching row — replace the UUID and email:
--
-- insert into public.users (id, email, full_name, role, status)
-- values ('00000000-0000-0000-0000-000000000000'::uuid,
--         'superadmin@example.com', 'Super Admin', 'super_admin', 'active');
--
-- 2. Never expose the service_role key in the browser. All writes above
--    go through RLS as the authenticated user.
