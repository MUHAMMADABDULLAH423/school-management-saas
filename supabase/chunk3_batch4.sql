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


