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

