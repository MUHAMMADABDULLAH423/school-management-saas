import { createClient } from "@/lib/supabase/server";
import { requireRoles } from "@/lib/guard";
import { getDictionary, isValidLocale, type Locale } from "@/lib/i18n";
import { assignTeacherClass, removeTeacherClass } from "@/lib/actions";
import { Badge, Button, Card, CardTitle, DataTable, EmptyState, Field, Select, TextInput } from "@/components/ui";

export default async function TeachersPage({ params }: { params: { locale: string } }) {
  const locale: Locale = isValidLocale(params.locale) ? params.locale : "en";
  const user = await requireRoles(["school_admin"], locale);
  const dict = await getDictionary(locale);
  const supabase = createClient();
  const schoolId = user.school_id!;

  const { data: staff } = await supabase
    .from("staff")
    .select("id,name,designation,employee_no,subjects,phone")
    .eq("school_id", schoolId)
    .order("name");

  const { data: classes } = await supabase
    .from("classes")
    .select("id,name,section")
    .eq("school_id", schoolId)
    .order("name");

  const { data: maps } = await supabase
    .from("teacher_class_map")
    .select("id,staff_id,class_id,subject")
    .eq("school_id", schoolId);

  const className = (id: string) => {
    const c = (classes ?? []).find((x) => x.id === id);
    return c ? `${c.name}-${c.section}` : "—";
  };

  return (
    <div className="space-y-4">
      <h1 className="text-xl font-bold text-slate-900">{dict.teachers.title}</h1>

      <Card className="p-4">
        <h2 className="mb-3 font-semibold">{dict.teachers.assign}</h2>
        <form action={assignTeacherClass} className="grid gap-3 sm:grid-cols-4">
          <input type="hidden" name="locale" value={locale} />
          <Field label={dict.nav.teachers}>
            <Select name="staff_id" required>
              <option value="">—</option>
              {(staff ?? []).map((s) => (
                <option key={s.id} value={s.id}>{s.name}</option>
              ))}
            </Select>
          </Field>
          <Field label={dict.students.class}>
            <Select name="class_id" required>
              <option value="">—</option>
              {(classes ?? []).map((c) => (
                <option key={c.id} value={c.id}>{c.name}-{c.section}</option>
              ))}
            </Select>
          </Field>
          <Field label={dict.teachers.subject}>
            <TextInput name="subject" required placeholder="Math" />
          </Field>
          <div className="flex items-end">
            <Button>{dict.common.add}</Button>
          </div>
        </form>
      </Card>

      <Card className="pb-2">
        <CardTitle>
          {dict.common.total}: {staff?.length ?? 0}
        </CardTitle>
        {!staff?.length ? (
          <EmptyState text={dict.common.noData} />
        ) : (
          <DataTable head={[dict.common.name, dict.teachers.employeeNo, dict.teachers.designation, dict.teachers.subjects, dict.teachers.assignedClasses]}>
            {staff.map((s) => {
              const mine = (maps ?? []).filter((m) => m.staff_id === s.id);
              return (
                <tr key={s.id} className="border-b border-slate-100 align-top last:border-0">
                  <td className="px-4 py-2.5 font-medium">{s.name}<br /><span className="text-xs text-slate-400" dir="ltr">{s.phone ?? ""}</span></td>
                  <td className="px-4 py-2.5 font-mono text-xs" dir="ltr">{s.employee_no ?? "—"}</td>
                  <td className="px-4 py-2.5">{s.designation}</td>
                  <td className="px-4 py-2.5 text-xs">{(s.subjects ?? []).join(", ") || "—"}</td>
                  <td className="px-4 py-2.5">
                    {mine.length === 0 ? (
                      <span className="text-xs text-slate-400">—</span>
                    ) : (
                      <ul className="space-y-1">
                        {mine.map((m) => (
                          <li key={m.id} className="flex items-center gap-2 text-xs">
                            <Badge tone="blue">{className(m.class_id)} · {m.subject}</Badge>
                            <form action={removeTeacherClass}>
                              <input type="hidden" name="locale" value={locale} />
                              <input type="hidden" name="id" value={m.id} />
                              <button type="submit" className="font-semibold text-red-600">✕</button>
                            </form>
                          </li>
                        ))}
                      </ul>
                    )}
                  </td>
                </tr>
              );
            })}
          </DataTable>
        )}
      </Card>

      <p className="text-xs text-slate-400">
        Note: teacher login accounts are created in Supabase Auth, then linked via the staff.user_id column (see README seed).
      </p>
    </div>
  );
}
