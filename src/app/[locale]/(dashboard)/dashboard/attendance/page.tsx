import { createClient } from "@/lib/supabase/server";
import { requireRoles } from "@/lib/guard";
import { getMyStaffId } from "@/lib/auth";
import { getDictionary, isValidLocale, type Locale } from "@/lib/i18n";
import { Button, Card, Field, Select, TextInput } from "@/components/ui";
import AttendanceMarker from "@/components/AttendanceMarker";
import type { AttendanceStatus } from "@/lib/types";

export default async function AttendancePage({
  params,
  searchParams,
}: {
  params: { locale: string };
  searchParams: { class?: string; date?: string };
}) {
  const locale: Locale = isValidLocale(params.locale) ? params.locale : "en";
  const user = await requireRoles(["teacher"], locale);
  const dict = await getDictionary(locale);
  const supabase = createClient();
  const staffId = await getMyStaffId();

  // Teacher's assigned classes (RLS: sms_tcm_self_read)
  const { data: maps } = await supabase
    .from("teacher_class_map")
    .select("class_id, classes(id,name,section)");
  const classes = (maps ?? [])
    .map((m) => m.classes as unknown as { id: string; name: string; section: string } | null)
    .filter(Boolean) as { id: string; name: string; section: string }[];
  const uniq = [...new Map(classes.map((c) => [c.id, c])).values()];

  const today = new Date().toISOString().slice(0, 10);
  const classId = searchParams.class ?? uniq[0]?.id ?? "";
  const date = searchParams.date ?? today;

  let students: { id: string; name: string; admission_no: string }[] = [];
  let existing: Record<string, AttendanceStatus> = {};
  if (classId) {
    const { data: st } = await supabase
      .from("students")
      .select("id,name,admission_no")
      .eq("class_id", classId)
      .eq("status", "active")
      .order("name");
    students = st ?? [];
    if (students.length) {
      const { data: att } = await supabase
        .from("attendance")
        .select("student_id,status")
        .eq("class_id", classId)
        .eq("date", date);
      for (const a of att ?? []) existing[a.student_id] = a.status as AttendanceStatus;
    }
  }

  return (
    <div className="space-y-4">
      <h1 className="text-xl font-bold text-slate-900">{dict.attendance.title}</h1>

      <Card className="p-4">
        <form method="GET" className="grid gap-3 sm:grid-cols-3">
          <Field label={dict.attendance.class}>
            <Select name="class" defaultValue={classId}>
              {uniq.map((c) => (
                <option key={c.id} value={c.id}>{c.name}-{c.section}</option>
              ))}
            </Select>
          </Field>
          <Field label={dict.attendance.date}>
            <TextInput name="date" type="date" defaultValue={date} max={today} />
          </Field>
          <div className="flex items-end">
            <Button>{dict.common.view}</Button>
          </div>
        </form>
      </Card>

      <Card className="p-4">
        {classId ? (
          <AttendanceMarker
            locale={locale}
            dict={dict}
            classId={classId}
            date={date}
            students={students}
            existing={existing}
          />
        ) : (
          <p className="text-sm text-slate-500">No classes assigned. Contact your school admin.</p>
        )}
      </Card>
    </div>
  );
}
