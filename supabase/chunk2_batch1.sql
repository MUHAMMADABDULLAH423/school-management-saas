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

