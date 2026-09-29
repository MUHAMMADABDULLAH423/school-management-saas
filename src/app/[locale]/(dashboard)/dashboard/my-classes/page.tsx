import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { requireRoles } from "@/lib/guard";
import { getDictionary, isValidLocale, type Locale } from "@/lib/i18n";
import { Card, EmptyState } from "@/components/ui";

export default async function MyClassesPage({ params }: { params: { locale: string } }) {
  const locale: Locale = isValidLocale(params.locale) ? params.locale : "en";
  await requireRoles(["teacher"], locale);
  const dict = await getDictionary(locale);
  const supabase = createClient();

  const { data: maps } = await supabase
    .from("teacher_class_map")
    .select("subject, classes(id,name,section,academic_year)");

  const byClass = new Map<string, { name: string; section: string; year: string; subjects: string[] }>();
  for (const m of maps ?? []) {
    const c = m.classes as unknown as { id: string; name: string; section: string; academic_year: string } | null;
    if (!c) continue;
    const e = byClass.get(c.id) ?? { name: c.name, section: c.section, year: c.academic_year, subjects: [] };
    if (!e.subjects.includes(m.subject)) e.subjects.push(m.subject);
    byClass.set(c.id, e);
  }

  return (
    <div className="space-y-4">
      <h1 className="text-xl font-bold text-slate-900">{dict.nav.myClasses}</h1>
      {!byClass.size ? (
        <Card><EmptyState text={dict.common.noData} /></Card>
      ) : (
        <div className="grid gap-3 sm:grid-cols-2">
          {[...byClass.entries()].map(([id, c]) => (
            <Card key={id} className="p-4">
              <h2 className="text-lg font-bold">{c.name}-{c.section}</h2>
              <p className="text-xs text-slate-400" dir="ltr">{c.year}</p>
              <p className="mt-2 text-sm text-slate-600">
                {dict.teachers.subjects}: {c.subjects.join(", ")}
              </p>
              <Link
                href={`/${locale}/dashboard/attendance?class=${id}`}
                className="mt-3 inline-block text-sm font-semibold text-brand-600"
              >
                {dict.nav.attendance} →
              </Link>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
