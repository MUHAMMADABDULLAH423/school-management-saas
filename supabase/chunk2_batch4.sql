-- audit on business tables
do $$
declare t text;
begin
  foreach t in array array[
    'schools','users','classes','students','staff','teacher_class_map',
    'parent_student_map','attendance','exams','marks',
    'fee_vouchers','fee_payments','notices']
  loop
    execute format(
      'create or replace trigger audit_%I after insert or update or delete
       on public.%I for each row execute function app_private.write_audit_log()',
      t, t);
  end loop;
end $$;

