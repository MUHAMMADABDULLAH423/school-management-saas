import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { requireRoles } from "@/lib/guard";
import { getDictionary, isValidLocale, type Locale } from "@/lib/i18n";
import { deleteClass, upsertClass } from "@/lib/actions";
import { Button, Card, DataTable, EmptyState, Field, TextInput } from "@/components/ui";
import DeleteButton from "@/components/DeleteButton";

export default async function ClassesPage({
  params,
  searchParams,
}: {
  params: { locale: string };
  searchParams: { new?: string; edit?: string };
}) {
  const locale: Locale = isValidLocale(params.locale) ? params.locale : "en";
  const user = await requireRoles(["school_admin"], locale);
  const dict = await getDictionary(locale);
  const supabase = createClient();

  const { data: classes } = await supabase
    .from("classes")
    .select("id,name,section,academic_year")
    .eq("school_id", user.school_id!)
    .order("name")
    .order("section");

  // student counts per class
  const { data: counts } = await supabase
    .from("students")
    .select("class_id")
    .eq("school_id", user.school_id!)
    .eq("status", "active");
  const countByClass = new Map<string, number>();
  for (const r of counts ?? []) countByClass.set(r.class_id, (countByClass.get(r.class_id) ?? 0) + 1);

  const editing = searchParams.edit ? (classes ?? []).find((c) => c.id === searchParams.edit) ?? null : null;
  const showForm = Boolean(searchParams.new) || Boolean(editing);

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold text-slate-900">{dict.classes.title}</h1>
        <Link href={`/${locale}/dashboard/classes?new=1`}>
          <Button type="button">+ {dict.classes.addClass}</Button>
        </Link>
      </div>

      {showForm && (
        <Card className="p-4">
          <form action={upsertClass} className="grid gap-3 sm:grid-cols-3">
            <input type="hidden" name="locale" value={locale} />
            {editing && <input type="hidden" name="id" value={editing.id} />}
            <Field label={dict.classes.name}>
              <TextInput name="name" required placeholder={dict.classes.nameHint} defaultValue={editing?.name ?? ""} />
            </Field>
            <Field label={dict.classes.section}>
              <TextInput name="section" defaultValue={editing?.section ?? "A"} maxLength={4} />
            </Field>
            <Field label={dict.classes.year}>
              <TextInput name="academic_year" required placeholder="2026-27" defaultValue={editing?.academic_year ?? ""} dir="ltr" />
            </Field>
            <div className="flex items-end gap-2 sm:col-span-3">
              <Button>{dict.common.save}</Button>
              <Link href={`/${locale}/dashboard/classes`}>
                <Button type="button" variant="secondary">{dict.common.cancel}</Button>
              </Link>
            </div>
          </form>
        </Card>
      )}

      <Card className="pb-2">
        {!classes?.length ? (
          <EmptyState text={dict.common.noData} />
        ) : (
          <DataTable head={[dict.classes.name, dict.classes.section, dict.classes.year, dict.dashboard.students, dict.common.actions]}>
            {classes.map((c) => (
              <tr key={c.id} className="border-b border-slate-100 last:border-0">
                <td className="px-4 py-2.5 font-medium">{c.name}</td>
                <td className="px-4 py-2.5">{c.section}</td>
                <td className="px-4 py-2.5" dir="ltr">{c.academic_year}</td>
                <td className="px-4 py-2.5">{countByClass.get(c.id) ?? 0}</td>
                <td className="px-4 py-2.5">
                  <div className="flex gap-3">
                    <Link href={`/${locale}/dashboard/classes?edit=${c.id}`} className="text-sm font-semibold text-brand-600">
                      {dict.common.edit}
                    </Link>
                    <form action={deleteClass}>
                      <input type="hidden" name="locale" value={locale} />
                      <input type="hidden" name="id" value={c.id} />
                      <DeleteButton label={dict.common.delete} confirmText={dict.common.confirmDelete} />
                    </form>
                  </div>
                </td>
              </tr>
            ))}
          </DataTable>
        )}
      </Card>
    </div>
  );
}
