import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { requireRoles } from "@/lib/guard";
import { getDictionary, isValidLocale, type Locale } from "@/lib/i18n";
import { createNotice, deleteNotice } from "@/lib/actions";
import { Badge, Button, Card, EmptyState, Field, Select, TextInput, TextArea } from "@/components/ui";
import DeleteButton from "@/components/DeleteButton";

export default async function NoticesPage({
  params,
  searchParams,
}: {
  params: { locale: string };
  searchParams: { new?: string };
}) {
  const locale: Locale = isValidLocale(params.locale) ? params.locale : "en";
  const user = await requireRoles(["school_admin", "teacher"], locale);
  const dict = await getDictionary(locale);
  const supabase = createClient();
  const isAdmin = user.role === "school_admin";

  const { data: notices } = await supabase
    .from("notices")
    .select("id,title,content,audience,published_at,expires_at")
    .eq("school_id", user.school_id!)
    .order("published_at", { ascending: false })
    .limit(50);

  const { data: classes } = isAdmin
    ? await supabase.from("classes").select("id,name,section").eq("school_id", user.school_id!).order("name")
    : { data: [] };

  const audienceLabel = (a: string) =>
    a === "school_wide" ? dict.notices.schoolWide
    : a === "teachers" ? dict.notices.teachersOnly
    : a === "parents" ? dict.notices.parentsOnly
    : dict.notices.classSpecific;

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold text-slate-900">{dict.notices.title}</h1>
        {isAdmin && (
          <Link href={`/${locale}/dashboard/notices?new=1`}>
            <Button type="button">+ {dict.notices.addNotice}</Button>
          </Link>
        )}
      </div>

      {isAdmin && searchParams.new && (
        <Card className="p-4">
          <form action={createNotice} className="grid gap-3 sm:grid-cols-2">
            <input type="hidden" name="locale" value={locale} />
            <Field label={dict.notices.content + " — " + dict.common.name}>
              <TextInput name="title" required />
            </Field>
            <Field label={dict.notices.audience}>
              <Select name="audience" defaultValue="school_wide">
                <option value="school_wide">{dict.notices.schoolWide}</option>
                <option value="teachers">{dict.notices.teachersOnly}</option>
                <option value="parents">{dict.notices.parentsOnly}</option>
                <option value="class_specific">{dict.notices.classSpecific}</option>
              </Select>
            </Field>
            <div className="sm:col-span-2">
              <Field label={dict.notices.content}>
                <TextArea name="content" required rows={4} />
              </Field>
            </div>
            <Field label={dict.students.class + ` (${dict.common.optional})`}>
              <Select name="class_id" defaultValue="">
                <option value="">—</option>
                {(classes ?? []).map((c) => (
                  <option key={c.id} value={c.id}>{c.name}-{c.section}</option>
                ))}
              </Select>
            </Field>
            <Field label={`${dict.notices.expires} (${dict.common.optional})`}>
              <TextInput name="expires_at" type="date" />
            </Field>
            <div className="flex items-end gap-2 sm:col-span-2">
              <Button>{dict.common.save}</Button>
              <Link href={`/${locale}/dashboard/notices`}>
                <Button type="button" variant="secondary">{dict.common.cancel}</Button>
              </Link>
            </div>
          </form>
        </Card>
      )}

      <div className="space-y-3">
        {!notices?.length ? (
          <Card><EmptyState text={dict.common.noData} /></Card>
        ) : (
          notices.map((n) => (
            <Card key={n.id} className="p-4">
              <div className="flex items-start justify-between gap-2">
                <div>
                  <h3 className="font-semibold text-slate-900">{n.title}</h3>
                  <p className="mt-1 whitespace-pre-wrap text-sm text-slate-600">{n.content}</p>
                  <div className="mt-2 flex items-center gap-2">
                    <Badge tone="blue">{audienceLabel(n.audience)}</Badge>
                    <span className="text-xs text-slate-400">{n.published_at.slice(0, 10)}</span>
                  </div>
                </div>
                {isAdmin && (
                  <form action={deleteNotice}>
                    <input type="hidden" name="locale" value={locale} />
                    <input type="hidden" name="id" value={n.id} />
                    <DeleteButton label={dict.common.delete} confirmText={dict.common.confirmDelete} />
                  </form>
                )}
              </div>
            </Card>
          ))
        )}
      </div>
    </div>
  );
}
