import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { requireRoles } from "@/lib/guard";
import { getDictionary, isValidLocale, type Locale } from "@/lib/i18n";
import { createSchool, setSchoolStatus } from "@/lib/actions";
import { Badge, Button, Card, CardTitle, DataTable, EmptyState, Field, Select, TextInput } from "@/components/ui";

export default async function SchoolsPage({
  params,
  searchParams,
}: {
  params: { locale: string };
  searchParams: { new?: string };
}) {
  const locale: Locale = isValidLocale(params.locale) ? params.locale : "en";
  await requireRoles(["super_admin"], locale);
  const dict = await getDictionary(locale);
  const supabase = createClient();

  const { data: schools } = await supabase.from("schools").select("*").order("created_at", { ascending: false });

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold text-slate-900">{dict.schools.title}</h1>
        <Link href={`/${locale}/dashboard/schools?new=1`}>
          <Button type="button">+ {dict.schools.addSchool}</Button>
        </Link>
      </div>

      {searchParams.new && (
        <Card className="p-4">
          <form action={createSchool} className="grid gap-3 sm:grid-cols-2">
            <input type="hidden" name="locale" value={locale} />
            <Field label={dict.common.name}>
              <TextInput name="name" required />
            </Field>
            <Field label={`${dict.common.name} (اردو)`}>
              <TextInput name="name_ur" dir="rtl" />
            </Field>
            <Field label={dict.students.address}>
              <TextInput name="address" />
            </Field>
            <Field label={dict.students.phone}>
              <TextInput name="phone" dir="ltr" />
            </Field>
            <Field label={dict.auth.email}>
              <TextInput name="email" type="email" dir="ltr" />
            </Field>
            <Field label={dict.schools.plan}>
              <Select name="plan" defaultValue="trial">
                {["trial", "basic", "standard", "premium"].map((p) => (
                  <option key={p} value={p}>{p}</option>
                ))}
              </Select>
            </Field>
            <div className="flex items-end gap-2 sm:col-span-2">
              <Button>{dict.common.save}</Button>
              <Link href={`/${locale}/dashboard/schools`}>
                <Button type="button" variant="secondary">{dict.common.cancel}</Button>
              </Link>
            </div>
          </form>
        </Card>
      )}

      <Card className="pb-2">
        <CardTitle>
          {dict.common.total}: {schools?.length ?? 0}
        </CardTitle>
        {!schools?.length ? (
          <EmptyState text={dict.common.noData} />
        ) : (
          <DataTable head={[dict.common.name, dict.schools.plan, dict.common.status, dict.common.actions]}>
            {schools.map((s) => (
              <tr key={s.id} className="border-b border-slate-100 last:border-0">
                <td className="px-4 py-2.5 font-medium">{s.name}</td>
                <td className="px-4 py-2.5">{s.plan}</td>
                <td className="px-4 py-2.5">
                  <Badge tone={s.status === "active" ? "green" : s.status === "suspended" ? "amber" : "slate"}>
                    {s.status}
                  </Badge>
                </td>
                <td className="px-4 py-2.5">
                  <form action={setSchoolStatus} className="inline">
                    <input type="hidden" name="locale" value={locale} />
                    <input type="hidden" name="id" value={s.id} />
                    <input type="hidden" name="status" value={s.status === "active" ? "suspended" : "active"} />
                    <Button type="submit" variant="secondary" className="!px-3 !py-1.5 text-xs">
                      {s.status === "active" ? dict.schools.suspend : dict.schools.activate}
                    </Button>
                  </form>
                </td>
              </tr>
            ))}
          </DataTable>
        )}
      </Card>
    </div>
  );
}
