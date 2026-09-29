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

