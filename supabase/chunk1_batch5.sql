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

