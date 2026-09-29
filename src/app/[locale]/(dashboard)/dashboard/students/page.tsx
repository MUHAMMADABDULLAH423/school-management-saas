import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { requireRoles } from "@/lib/guard";
import { getDictionary, isValidLocale, type Locale } from "@/lib/i18n";
import { upsertStudent } from "@/lib/actions";
import { Badge, Button, Card, DataTable, EmptyState, Field, Select, TextInput } from "@/components/ui";

export default async function StudentsPage({
  params,
  searchParams,
}: {
  params: { locale: string };
  searchParams: { q?: string; class?: string; new?: string; edit?: string };
}) {
  const locale: Locale = isValidLocale(params.locale) ? params.locale : "en";
  const user = await requireRoles(["school_admin"], locale);
  const dict = await getDictionary(locale);
  const supabase = createClient();

  const { data: classes } = await supabase
    .from("classes")
    .select("id,name,section")
    .eq("school_id", user.school_id!)
    .order("name");

  let query = supabase
    .from("students")
    .select("id,admission_no,name,father_name,class_id,status")
    .eq("school_id", user.school_id!)
    .order("name")
    .limit(200);
  if (searchParams.class) query = query.eq("class_id", searchParams.class);
  if (searchParams.q) query = query.or(`name.ilike.%${searchParams.q}%,admission_no.ilike.%${searchParams.q}%`);
  const { data: students } = await query;
  const className = (id: string) => {
    const c = (classes ?? []).find((x) => x.id === id);
    return c ? `${c.name}-${c.section}` : "—";
  };

  const editing = searchParams.edit
    ? (students ?? []).find((s) => s.id === searchParams.edit) ?? null
    : null;
  const showForm = Boolean(searchParams.new) || Boolean(editing);

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold text-slate-900">{dict.students.title}</h1>
        <Link href={`/${locale}/dashboard/students?new=1`}>
          <Button type="button">+ {dict.students.addStudent}</Button>
        </Link>
      </div>

      <Card className="p-3">
        <form method="GET" className="flex flex-col gap-2 sm:flex-row">
          <TextInput
            name="q"
            defaultValue={searchParams.q ?? ""}
            placeholder={dict.students.searchPlaceholder}
            className="flex-1"
          />
          <Select name="class" defaultValue={searchParams.class ?? ""}>
            <option value="">{dict.common.all} — {dict.students.class}</option>
            {(classes ?? []).map((c) => (
              <option key={c.id} value={c.id}>{c.name}-{c.section}</option>
            ))}
          </Select>
          <Button>{dict.common.search}</Button>
        </form>
      </Card>

      {showForm && (
        <Card className="p-4">
          <h2 className="mb-3 font-semibold">{editing ? dict.students.editStudent : dict.students.addStudent}</h2>
          <StudentForm locale={locale} dict={dict} classes={classes ?? []} editing={editing} />
        </Card>
      )}

      <Card className="pb-2">
        {!students?.length ? (
          <EmptyState text={dict.common.noData} />
        ) : (
          <DataTable head={[dict.students.admissionNo, dict.common.name, dict.students.fatherName, dict.students.class, dict.common.status, dict.common.actions]}>
            {students.map((s) => (
              <tr key={s.id} className="border-b border-slate-100 last:border-0">
                <td className="px-4 py-2.5 font-mono text-xs" dir="ltr">{s.admission_no}</td>
                <td className="px-4 py-2.5 font-medium">{s.name}</td>
                <td className="px-4 py-2.5">{s.father_name ?? "—"}</td>
                <td className="px-4 py-2.5">{className(s.class_id)}</td>
                <td className="px-4 py-2.5">
                  <Badge tone={s.status === "active" ? "green" : "slate"}>{s.status}</Badge>
                </td>
                <td className="px-4 py-2.5">
                  <Link href={`/${locale}/dashboard/students?edit=${s.id}`} className="text-brand-600 text-sm font-semibold">
                    {dict.common.edit}
                  </Link>
                </td>
              </tr>
            ))}
          </DataTable>
        )}
      </Card>
    </div>
  );
}

function StudentForm({
  locale, dict, classes, editing,
}: {
  locale: Locale;
  dict: Awaited<ReturnType<typeof getDictionary>>;
  classes: { id: string; name: string; section: string }[];
  editing: { id: string; admission_no: string; name: string; father_name: string | null; class_id: string } | null;
}) {
  return (
    <form action={upsertStudent} className="grid gap-3 sm:grid-cols-2">
      <input type="hidden" name="locale" value={locale} />
      {editing && <input type="hidden" name="id" value={editing.id} />}
      <Field label={dict.students.admissionNo}>
        <TextInput name="admission_no" required defaultValue={editing?.admission_no ?? ""} dir="ltr" />
      </Field>
      <Field label={dict.common.name}>
        <TextInput name="name" required defaultValue={editing?.name ?? ""} />
      </Field>
      <Field label={dict.students.fatherName}>
        <TextInput name="father_name" defaultValue={editing?.father_name ?? ""} />
      </Field>
      <Field label={dict.students.class}>
        <Select name="class_id" required defaultValue={editing?.class_id ?? ""}>
          <option value="">{dict.common.selectClass}</option>
          {classes.map((c) => (
            <option key={c.id} value={c.id}>{c.name}-{c.section}</option>
          ))}
        </Select>
      </Field>
      <Field label={dict.students.gender}>
        <Select name="gender" defaultValue="">
          <option value="">—</option>
          <option value="male">{dict.students.male}</option>
          <option value="female">{dict.students.female}</option>
        </Select>
      </Field>
      <Field label={dict.students.dob}>
        <TextInput name="date_of_birth" type="date" />
      </Field>
      <Field label={dict.students.phone}>
        <TextInput name="phone" dir="ltr" />
      </Field>
      <Field label={dict.common.status}>
        <Select name="status" defaultValue="active">
          {["active", "inactive", "graduated", "withdrawn", "struck_off"].map((s) => (
            <option key={s} value={s}>{s}</option>
          ))}
        </Select>
      </Field>
      <div className="flex items-end gap-2 sm:col-span-2">
        <Button>{dict.common.save}</Button>
        <Link href={`/${locale}/dashboard/students`}>
          <Button type="button" variant="secondary">{dict.common.cancel}</Button>
        </Link>
      </div>
    </form>
  );
}
