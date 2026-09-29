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

