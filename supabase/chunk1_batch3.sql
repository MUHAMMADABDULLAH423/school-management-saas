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

