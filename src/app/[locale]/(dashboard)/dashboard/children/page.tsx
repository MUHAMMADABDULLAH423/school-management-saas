import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { requireRoles } from "@/lib/guard";
import { getDictionary, isValidLocale, type Locale } from "@/lib/i18n";
import { Badge, Card, CardTitle, DataTable, EmptyState } from "@/components/ui";

function gradeOf(pct: number): string {
  if (pct >= 90) return "A+";
  if (pct >= 80) return "A";
  if (pct >= 70) return "B";
  if (pct >= 60) return "C";
  if (pct >= 50) return "D";
  return "F";
}

export default async function ChildrenPage({
  params,
  searchParams,
}: {
  params: { locale: string };
  searchParams: { child?: string };
}) {
  const locale: Locale = isValidLocale(params.locale) ? params.locale : "en";
  const user = await requireRoles(["parent"], locale);
  const dict = await getDictionary(locale);
  const supabase = createClient();

  // Children mapped to this parent (RLS: sms_psm_self_read)
  const { data: mappings } = await supabase
    .from("parent_student_map")
    .select("student_id, students(id,name,admission_no,class_id, classes(name,section))");

  interface ChildRow {
    id: string;
    name: string;
    admission_no: string;
    class_id: string;
    classes: { name: string; section: string } | null;
  }
  const children: ChildRow[] = (mappings ?? [])
    .map((m) => m.students as unknown as ChildRow | null)
    .filter((c): c is ChildRow => c !== null);

  const activeChild = children.find((c) => c.id === searchParams.child) ?? children[0] ?? null;

  let attPct: number | null = null;
  let vouchers: {
    id: string; voucher_no: string; title: string; month: string;
    amount: number; discount: number; due_date: string; status: string;
  }[] = [];
  let payments: { id: string; amount: number; receipt_no: number; paid_at: string; voucher_id: string }[] = [];
  let reportCards: { exam: string; rows: { subject: string; obtained: number; total: number }[] }[] = [];

  if (activeChild) {
    const since = new Date();
    since.setDate(since.getDate() - 30);
    const { data: att } = await supabase
      .from("attendance")
      .select("status")
      .eq("student_id", activeChild.id)
      .gte("date", since.toISOString().slice(0, 10));
    if (att?.length) {
      const present = att.filter((a) => a.status === "present" || a.status === "late").length;
      attPct = Math.round((present / att.length) * 100);
    }

    const { data: v } = await supabase
      .from("fee_vouchers")
      .select("id,voucher_no,title,month,amount,discount,due_date,status")
      .eq("student_id", activeChild.id)
      .order("month", { ascending: false })
      .limit(24);
    vouchers = v ?? [];
    const vIds = vouchers.map((x) => x.id);
    if (vIds.length) {
      const { data: p } = await supabase
        .from("fee_payments")
        .select("id,amount,receipt_no,paid_at,voucher_id")
        .in("voucher_id", vIds)
        .order("paid_at", { ascending: false });
      payments = p ?? [];
    }

    const { data: marks } = await supabase
      .from("marks")
      .select("subject,marks_obtained,total_marks, exams(id,name,result_published)")
      .eq("student_id", activeChild.id);
    const byExam = new Map<string, { exam: string; rows: { subject: string; obtained: number; total: number }[] }>();
    for (const m of marks ?? []) {
      const ex = m.exams as unknown as { id: string; name: string; result_published: boolean } | null;
      if (!ex?.result_published) continue;
      const e = byExam.get(ex.id) ?? { exam: ex.name, rows: [] };
      e.rows.push({ subject: m.subject, obtained: Number(m.marks_obtained), total: Number(m.total_marks) });
      byExam.set(ex.id, e);
    }
    reportCards = [...byExam.values()];
  }

  const { data: notices } = await supabase
    .from("notices")
    .select("id,title,content,published_at")
    .eq("school_id", user.school_id!)
    .order("published_at", { ascending: false })
    .limit(10);

  const statusTone: Record<string, "green" | "amber" | "red" | "slate" | "blue"> = {
    paid: "green", partial: "amber", unpaid: "red", overdue: "red", waived: "blue",
  };

  return (
    <div className="space-y-4">
      <h1 className="text-xl font-bold text-slate-900">{dict.parent.title}</h1>

      {children.length > 1 && (
        <div className="flex gap-2 overflow-x-auto">
          {children.map((c) => (
            <Link
              key={c.id}
              href={`/${locale}/dashboard/children?child=${c.id}`}
              className={`whitespace-nowrap rounded-xl px-4 py-2 text-sm font-semibold ${
                activeChild?.id === c.id ? "bg-brand-600 text-white" : "bg-white text-slate-700 ring-1 ring-slate-200"
              }`}
            >
              {c.name}
            </Link>
          ))}
        </div>
      )}

      {!activeChild ? (
        <Card><EmptyState text={dict.common.noData} /></Card>
      ) : (
        <>
          <Card className="p-4">
            <h2 className="text-lg font-bold">{activeChild.name}</h2>
            <p className="text-sm text-slate-500">
              {activeChild.classes ? `${activeChild.classes.name}-${activeChild.classes.section}` : ""} ·{" "}
              <span className="font-mono text-xs" dir="ltr">{activeChild.admission_no}</span>
            </p>
            <div className="mt-3 grid grid-cols-2 gap-3">
              <div className="rounded-xl bg-slate-50 p-3">
                <p className="text-xs text-slate-500">{dict.parent.attendance} ({dict.parent.last30})</p>
                <p className="text-xl font-bold">{attPct === null ? "—" : `${attPct}%`}</p>
              </div>
              <div className="rounded-xl bg-slate-50 p-3">
                <p className="text-xs text-slate-500">{dict.parent.fees}</p>
                <p className="text-xl font-bold">
                  {vouchers.filter((v) => v.status === "unpaid" || v.status === "partial" || v.status === "overdue").length}{" "}
                  <span className="text-xs font-medium text-slate-400">{dict.fees.unpaid}/{dict.fees.partial}</span>
                </p>
              </div>
            </div>
          </Card>

          <Card className="pb-2">
            <CardTitle>{dict.parent.vouchers}</CardTitle>
            {!vouchers.length ? (
              <EmptyState text={dict.common.noData} />
            ) : (
              <DataTable head={[dict.fees.voucherNo, dict.fees.month, dict.fees.amount, dict.common.status]}>
                {vouchers.map((v) => (
                  <tr key={v.id} className="border-b border-slate-100 last:border-0">
                    <td className="px-4 py-2.5">
                      <span className="font-mono text-xs" dir="ltr">{v.voucher_no}</span>
                      <br /><span className="text-xs text-slate-500">{v.title}</span>
                    </td>
                    <td className="px-4 py-2.5 text-xs" dir="ltr">{v.month.slice(0, 7)}</td>
                    <td className="px-4 py-2.5 text-sm" dir="ltr">
                      {(Number(v.amount) - Number(v.discount)).toLocaleString()}
                    </td>
                    <td className="px-4 py-2.5">
                      <Badge tone={statusTone[v.status] ?? "slate"}>
                        {(dict.fees as Record<string, string>)[v.status] ?? v.status}
                      </Badge>
                    </td>
                  </tr>
                ))}
              </DataTable>
            )}
          </Card>

          {payments.length > 0 && (
            <Card className="pb-2">
              <CardTitle>{dict.parent.payments}</CardTitle>
              <DataTable head={[dict.fees.receipt, dict.fees.payAmount, dict.common.date]}>
                {payments.map((p) => (
                  <tr key={p.id} className="border-b border-slate-100 last:border-0">
                    <td className="px-4 py-2.5 font-mono text-xs" dir="ltr">#{p.receipt_no}</td>
                    <td className="px-4 py-2.5" dir="ltr">{Number(p.amount).toLocaleString()}</td>
                    <td className="px-4 py-2.5 text-xs">{p.paid_at.slice(0, 10)}</td>
                  </tr>
                ))}
              </DataTable>
            </Card>
          )}

          <Card className="pb-2">
            <CardTitle>{dict.results.reportCard}</CardTitle>
            {!reportCards.length ? (
              <EmptyState text={dict.parent.noPublished} />
            ) : (
              <div className="space-y-4 px-4 pb-4">
                {reportCards.map((rc, i) => {
                  const obt = rc.rows.reduce((s, r) => s + r.obtained, 0);
                  const tot = rc.rows.reduce((s, r) => s + r.total, 0);
                  const pct = tot ? (obt / tot) * 100 : 0;
                  return (
                    <div key={i} className="rounded-xl bg-slate-50 p-3">
                      <div className="flex items-center justify-between">
                        <h3 className="font-semibold">{rc.exam}</h3>
                        <Badge tone="green">
                          {obt}/{tot} · {Math.round(pct)}% · {gradeOf(pct)}
                        </Badge>
                      </div>
                      <DataTable head={[dict.results.subject, dict.results.obtained, dict.results.totalMarks]}>
                        {rc.rows.map((r, j) => (
                          <tr key={j} className="border-b border-slate-100 last:border-0">
                            <td className="px-4 py-1.5 text-sm">{r.subject}</td>
                            <td className="px-4 py-1.5 text-sm" dir="ltr">{r.obtained}</td>
                            <td className="px-4 py-1.5 text-sm" dir="ltr">{r.total}</td>
                          </tr>
                        ))}
                      </DataTable>
                    </div>
                  );
                })}
              </div>
            )}
          </Card>
        </>
      )}

      <Card className="pb-2">
        <CardTitle>{dict.parent.notices}</CardTitle>
        {!notices?.length ? (
          <EmptyState text={dict.common.noData} />
        ) : (
          <ul className="divide-y divide-slate-100">
            {notices.map((n) => (
              <li key={n.id} className="px-4 py-2.5">
                <p className="text-sm font-semibold">{n.title}</p>
                <p className="text-xs text-slate-500 line-clamp-2">{n.content}</p>
              </li>
            ))}
          </ul>
        )}
      </Card>
    </div>
  );
}
