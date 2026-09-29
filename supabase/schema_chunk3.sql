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
