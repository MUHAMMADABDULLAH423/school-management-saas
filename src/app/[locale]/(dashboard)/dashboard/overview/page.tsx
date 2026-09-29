import { createClient } from "@/lib/supabase/server";
import { requireRoles } from "@/lib/guard";
import { getDictionary, isValidLocale, type Locale } from "@/lib/i18n";
import { BarChart, DonutChart } from "@/components/Charts";
import { Card, CardTitle, EmptyState, StatCard } from "@/components/ui";

function isoDaysBack(n: number): string[] {
  const out: string[] = [];
  const d = new Date();
  for (let i = n - 1; i >= 0; i--) {
    const t = new Date(d);
    t.setDate(d.getDate() - i);
    out.push(t.toISOString().slice(0, 10));
  }
  return out;
}

export default async function PrincipalDashboard({ params }: { params: { locale: string } }) {
  const locale: Locale = isValidLocale(params.locale) ? params.locale : "en";
  const user = await requireRoles(["school_admin"], locale);
  const dict = await getDictionary(locale);
  const supabase = createClient();
  const schoolId = user.school_id!;

  const [{ count: studentCount }, { count: teacherCount }, { count: classCount }] = await Promise.all([
    supabase.from("students").select("id", { count: "exact", head: true }).eq("school_id", schoolId).eq("status", "active"),
    supabase.from("staff").select("id", { count: "exact", head: true }).eq("school_id", schoolId),
    supabase.from("classes").select("id", { count: "exact", head: true }).eq("school_id", schoolId),
  ]);

  // Attendance: today + last 14 days trend
  const days = isoDaysBack(14);
  const today = days[days.length - 1];
  const { data: attRows } = await supabase
    .from("attendance")
    .select("date,status")
    .eq("school_id", schoolId)
    .gte("date", days[0])
    .lte("date", today);

  const byDay = new Map<string, { present: number; total: number }>();
  for (const d of days) byDay.set(d, { present: 0, total: 0 });
  for (const r of attRows ?? []) {
    const e = byDay.get(r.date);
    if (!e) continue;
    e.total += 1;
    if (r.status === "present" || r.status === "late") e.present += 1;
  }
  const trend = days.map((d) => {
    const e = byDay.get(d)!;
    return { label: d.slice(5), value: e.total ? (e.present / e.total) * 100 : 0 };
  });
  const todayEntry = byDay.get(today)!;
  const todayPct = todayEntry.total ? Math.round((todayEntry.present / todayEntry.total) * 100) : 0;

  // Fees: current month collected vs outstanding
  const monthStart = today.slice(0, 7) + "-01";
  const { data: vouchers } = await supabase
    .from("fee_vouchers")
    .select("id,amount,discount")
    .eq("school_id", schoolId)
    .eq("month", monthStart);
  const voucherIds = (vouchers ?? []).map((v) => v.id);
  let collected = 0;
  if (voucherIds.length) {
    const { data: payments } = await supabase
      .from("fee_payments")
      .select("amount")
      .in("voucher_id", voucherIds);
    collected = (payments ?? []).reduce((s, p) => s + Number(p.amount), 0);
  }
  const billed = (vouchers ?? []).reduce((s, v) => s + (Number(v.amount) - Number(v.discount)), 0);
  const outstanding = Math.max(0, billed - collected);

  const { data: notices } = await supabase
    .from("notices")
    .select("id,title,published_at")
    .eq("school_id", schoolId)
    .order("published_at", { ascending: false })
    .limit(5);

  return (
    <div className="space-y-4">
      <h1 className="text-xl font-bold text-slate-900">
        {dict.dashboard.welcome}, {user.full_name.split(" ")[0]}
      </h1>

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <StatCard label={dict.dashboard.students} value={studentCount ?? 0} />
        <StatCard label={dict.dashboard.teachers} value={teacherCount ?? 0} />
        <StatCard label={dict.dashboard.classes} value={classCount ?? 0} />
        <StatCard
          label={dict.dashboard.attendanceToday}
          value={`${todayPct}%`}
          sub={`${todayEntry.present}/${todayEntry.total} ${dict.dashboard.presentPct}`}
        />
      </div>

      <Card className="p-4">
        <h2 className="mb-2 text-base font-semibold text-slate-800">{dict.dashboard.trend14}</h2>
        <BarChart data={trend} />
      </Card>

      <Card className="p-4">
        <h2 className="mb-2 text-base font-semibold text-slate-800">{dict.dashboard.feeRecovery}</h2>
        <DonutChart
          parts={[
            { value: Math.round(collected), color: "#16a34a", label: dict.dashboard.collected },
            { value: Math.round(outstanding), color: "#f59e0b", label: dict.dashboard.outstanding },
          ]}
          label={`${billed > 0 ? Math.round((collected / billed) * 100) : 0}%`}
        />
      </Card>

      <Card className="pb-2">
        <CardTitle>{dict.dashboard.recentNotices}</CardTitle>
        {(notices ?? []).length === 0 ? (
          <EmptyState text={dict.common.noData} />
        ) : (
          <ul className="divide-y divide-slate-100">
            {(notices ?? []).map((n) => (
              <li key={n.id} className="flex items-center justify-between px-4 py-2.5 text-sm">
                <span className="font-medium text-slate-800">{n.title}</span>
                <span className="text-xs text-slate-400">{n.published_at.slice(0, 10)}</span>
              </li>
            ))}
          </ul>
        )}
      </Card>
    </div>
  );
}
