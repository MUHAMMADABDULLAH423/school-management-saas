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

