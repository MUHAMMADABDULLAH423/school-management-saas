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

