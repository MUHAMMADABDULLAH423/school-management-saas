import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { requireRoles } from "@/lib/guard";
import { getDictionary, isValidLocale, type Locale } from "@/lib/i18n";
import { createExam, toggleExamPublished } from "@/lib/actions";
import { Badge, Button, Card, CardTitle, DataTable, EmptyState, Field, Select, TextInput } from "@/components/ui";
import MarksEntry from "@/components/MarksEntry";

export default async function ResultsPage({
  params,
  searchParams,
}: {
  params: { locale: string };
  searchParams: { new?: string; exam?: string; class?: string };
}) {
  const locale: Locale = isValidLocale(params.locale) ? params.locale : "en";
  const user = await requireRoles(["school_admin"], locale);
  const dict = await getDictionary(locale);
  const supabase = createClient();
  const schoolId = user.school_id!;

  const { data: exams } = await supabase
    .from("exams")
    .select("*")
    .eq("school_id", schoolId)
    .order("created_at", { ascending: false });

  const { data: classes } = await supabase
    .from("classes")
    .select("id,name,section")
    .eq("school_id", schoolId)
    .order("name");

  const activeExam = searchParams.exam ? (exams ?? []).find((e) => e.id === searchParams.exam) ?? null : null;

  let markStudents: { id: string; name: string; admission_no: string }[] = [];
  let subjects: string[] = [];
  let existing: Record<string, { obtained: number; total: number }> = {};
  if (activeExam && searchParams.class) {
    const { data: students } = await supabase
      .from("students")
      .select("id,name,admission_no")
      .eq("class_id", searchParams.class)
      .eq("status", "active")
      .order("name");
    markStudents = students ?? [];
    const { data: marks } = await supabase
      .from("marks")
      .select("student_id,subject,marks_obtained,total_marks")
      .eq("exam_id", activeExam.id);
    const subSet = new Set<string>();
    for (const m of marks ?? []) {
      subSet.add(m.subject);
      existing[`${m.student_id}|${m.subject}`] = {
        obtained: Number(m.marks_obtained),
        total: Number(m.total_marks),
      };
    }
    subjects = [...subSet];
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold text-slate-900">{dict.results.title}</h1>
        <Link href={`/${locale}/dashboard/results?new=1`}>
          <Button type="button">+ {dict.results.addExam}</Button>
        </Link>
      </div>

      {searchParams.new && (
        <Card className="p-4">
          <form action={createExam} className="grid gap-3 sm:grid-cols-4">
            <input type="hidden" name="locale" value={locale} />
            <Field label={dict.results.examName}>
              <TextInput name="name" required placeholder="First Term" />
            </Field>
            <Field label={dict.results.year}>
              <TextInput name="academic_year" required placeholder="2026-27" dir="ltr" />
            </Field>
            <Field label={dict.common.date}>
              <TextInput name="starts_on" type="date" />
            </Field>
            <div className="flex items-end gap-2">
              <Button>{dict.common.save}</Button>
              <Link href={`/${locale}/dashboard/results`}>
                <Button type="button" variant="secondary">{dict.common.cancel}</Button>
              </Link>
            </div>
          </form>
        </Card>
      )}

      <Card className="pb-2">
        {!exams?.length ? (
          <EmptyState text={dict.common.noData} />
        ) : (
          <DataTable head={[dict.results.examName, dict.results.year, dict.results.published, dict.common.actions]}>
            {exams.map((e) => (
              <tr key={e.id} className="border-b border-slate-100 last:border-0">
                <td className="px-4 py-2.5 font-medium">{e.name}</td>
                <td className="px-4 py-2.5" dir="ltr">{e.academic_year}</td>
                <td className="px-4 py-2.5">
                  <Badge tone={e.result_published ? "green" : "slate"}>
                    {e.result_published ? dict.common.yes : dict.common.no}
                  </Badge>
                </td>
                <td className="px-4 py-2.5">
                  <div className="flex items-center gap-3">
                    <form action={toggleExamPublished}>
                      <input type="hidden" name="locale" value={locale} />
                      <input type="hidden" name="id" value={e.id} />
                      <input type="hidden" name="published" value={e.result_published ? "false" : "true"} />
                      <button type="submit" className="text-sm font-semibold text-brand-600">
                        {e.result_published ? dict.results.unpublish : dict.results.publish}
                      </button>
                    </form>
                    <Link
                      href={`/${locale}/dashboard/results?exam=${e.id}`}
                      className="text-sm font-semibold text-slate-700"
                    >
                      {dict.results.enterMarks}
                    </Link>
                  </div>
                </td>
              </tr>
            ))}
          </DataTable>
        )}
      </Card>

      {activeExam && (
        <Card className="p-4">
          <h2 className="mb-3 font-semibold">
            {dict.results.enterMarks} — {activeExam.name}
          </h2>
          <form method="GET" className="mb-3 flex flex-col gap-2 sm:flex-row">
            <input type="hidden" name="exam" value={activeExam.id} />
            <Select name="class" defaultValue={searchParams.class ?? ""} className="sm:max-w-xs">
              <option value="">{dict.common.selectClass}</option>
              {(classes ?? []).map((c) => (
                <option key={c.id} value={c.id}>{c.name}-{c.section}</option>
              ))}
            </Select>
            <Button>{dict.common.view}</Button>
          </form>
          {searchParams.class ? (
            <MarksEntry
              locale={locale}
              dict={dict}
              examId={activeExam.id}
              students={markStudents}
              subjects={subjects}
              existing={existing}
            />
          ) : (
            <EmptyState text={dict.common.selectClass} />
          )}
        </Card>
      )}
    </div>
  );
}
