import { createClient } from "@/lib/supabase/server";
import { requireRoles } from "@/lib/guard";
import { getDictionary, isValidLocale, type Locale } from "@/lib/i18n";
import { generateVouchers, recordPayment } from "@/lib/actions";
import { Badge, Button, Card, CardTitle, DataTable, EmptyState, Field, Select, TextInput } from "@/components/ui";

const statusTone: Record<string, "green" | "amber" | "red" | "slate" | "blue"> = {
  paid: "green",
  partial: "amber",
  unpaid: "red",
  overdue: "red",
  waived: "blue",
};

export default async function FeesPage({
  params,
  searchParams,
}: {
  params: { locale: string };
  searchParams: { class?: string; status?: string; pay?: string };
}) {
  const locale: Locale = isValidLocale(params.locale) ? params.locale : "en";
  const user = await requireRoles(["school_admin"], locale);
  const dict = await getDictionary(locale);
  const supabase = createClient();
  const schoolId = user.school_id!;

  const { data: classes } = await supabase
    .from("classes")
    .select("id,name,section")
    .eq("school_id", schoolId)
    .order("name");

  let query = supabase
    .from("fee_vouchers")
    .select("id,voucher_no,title,month,amount,discount,due_date,status,student_id")
    .eq("school_id", schoolId)
    .order("created_at", { ascending: false })
    .limit(150);
  if (searchParams.status) query = query.eq("status", searchParams.status);
  const { data: vouchers } = await query;

  // Enrich with student + class names
  const studentIds = [...new Set((vouchers ?? []).map((v) => v.student_id))];
  const { data: students } = studentIds.length
    ? await supabase.from("students").select("id,name,admission_no,class_id").in("id", studentIds)
    : { data: [] };
  const sMap = new Map((students ?? []).map((s) => [s.id, s]));
  const cName = (id: string) => {
    const c = (classes ?? []).find((x) => x.id === id);
    return c ? `${c.name}-${c.section}` : "";
  };

  let filtered = vouchers ?? [];
  if (searchParams.class) {
    filtered = filtered.filter((v) => sMap.get(v.student_id)?.class_id === searchParams.class);
  }

  const paying = searchParams.pay ? filtered.find((v) => v.id === searchParams.pay) ?? null : null;
  const thisMonth = new Date().toISOString().slice(0, 7);

  return (
    <div className="space-y-4">
      <h1 className="text-xl font-bold text-slate-900">{dict.fees.title}</h1>

      <Card className="p-4">
        <h2 className="mb-3 font-semibold">{dict.fees.generate}</h2>
        <form action={generateVouchers} className="grid gap-3 sm:grid-cols-3">
          <input type="hidden" name="locale" value={locale} />
          <Field label={dict.students.class}>
            <Select name="class_id" required>
              <option value="">{dict.common.selectClass}</option>
              {(classes ?? []).map((c) => (
                <option key={c.id} value={c.id}>{c.name}-{c.section}</option>
              ))}
            </Select>
          </Field>
          <Field label={dict.fees.month}>
            <TextInput name="month" type="month" required defaultValue={thisMonth} dir="ltr" />
          </Field>
          <Field label={dict.fees.amount}>
            <TextInput name="amount" type="number" min={0} step="0.01" required dir="ltr" />
          </Field>
          <Field label={dict.fees.dueDate}>
            <TextInput name="due_date" type="date" required />
          </Field>
          <Field label={dict.common.title}>
            <TextInput name="title" placeholder={`Fee ${thisMonth}`} />
          </Field>
          <div className="flex items-end">
            <Button>{dict.fees.generate}</Button>
          </div>
        </form>
      </Card>

      {paying && (
        <Card className="border-brand-200 p-4 ring-2 ring-brand-100">
          <h2 className="mb-3 font-semibold">
            {dict.fees.recordPayment} — <span className="font-mono text-sm" dir="ltr">{paying.voucher_no}</span>
          </h2>
          <form action={recordPayment} className="grid gap-3 sm:grid-cols-3">
            <input type="hidden" name="locale" value={locale} />
            <input type="hidden" name="voucher_id" value={paying.id} />
            <Field label={`${dict.fees.payAmount} (${dict.fees.balance}: ${(Number(paying.amount) - Number(paying.discount)).toLocaleString()})`}>
              <TextInput name="amount" type="number" min={1} step="0.01" required dir="ltr" />
            </Field>
            <Field label={dict.fees.method}>
              <Select name="method" defaultValue="cash">
                <option value="cash">{dict.fees.cash}</option>
                <option value="bank">{dict.fees.bank}</option>
                <option value="online">{dict.fees.online}</option>
                <option value="other">{dict.fees.other}</option>
              </Select>
            </Field>
            <div className="flex items-end gap-2">
              <Button>{dict.common.save}</Button>
              <a href={`/${locale}/dashboard/fees`}>
                <Button type="button" variant="secondary">{dict.common.cancel}</Button>
              </a>
            </div>
          </form>
        </Card>
      )}

      <Card className="p-3">
        <form method="GET" className="flex flex-col gap-2 sm:flex-row">
          <Select name="class" defaultValue={searchParams.class ?? ""}>
            <option value="">{dict.common.all} — {dict.students.class}</option>
            {(classes ?? []).map((c) => (
              <option key={c.id} value={c.id}>{c.name}-{c.section}</option>
            ))}
          </Select>
          <Select name="status" defaultValue={searchParams.status ?? ""}>
            <option value="">{dict.common.all} — {dict.common.status}</option>
            {["unpaid", "partial", "paid", "overdue", "waived"].map((s) => (
              <option key={s} value={s}>{(dict.fees as Record<string, string>)[s] ?? s}</option>
            ))}
          </Select>
          <Button>{dict.common.search}</Button>
        </form>
      </Card>

      <Card className="pb-2">
        <CardTitle>{dict.fees.vouchers} ({filtered.length})</CardTitle>
        {!filtered.length ? (
          <EmptyState text={dict.common.noData} />
        ) : (
          <DataTable head={[dict.fees.voucherNo, dict.fees.student, dict.fees.month, dict.fees.amount, dict.common.status, dict.common.actions]}>
            {filtered.map((v) => {
              const s = sMap.get(v.student_id);
              const bal = Number(v.amount) - Number(v.discount);
              return (
                <tr key={v.id} className="border-b border-slate-100 last:border-0">
                  <td className="px-4 py-2.5 font-mono text-xs" dir="ltr">{v.voucher_no}</td>
                  <td className="px-4 py-2.5">{s?.name ?? "—"} <span className="text-xs text-slate-400">{cName(s?.class_id ?? "")}</span></td>
                  <td className="px-4 py-2.5" dir="ltr">{v.month.slice(0, 7)}</td>
                  <td className="px-4 py-2.5" dir="ltr">{bal.toLocaleString()}</td>
                  <td className="px-4 py-2.5">
                    <Badge tone={statusTone[v.status] ?? "slate"}>{(dict.fees as Record<string, string>)[v.status] ?? v.status}</Badge>
                  </td>
                  <td className="px-4 py-2.5">
                    {v.status !== "paid" && v.status !== "waived" && (
                      <a href={`/${locale}/dashboard/fees?pay=${v.id}`} className="text-sm font-semibold text-brand-600">
                        {dict.fees.recordPayment}
                      </a>
                    )}
                  </td>
                </tr>
              );
            })}
          </DataTable>
        )}
      </Card>
    </div>
  );
}
