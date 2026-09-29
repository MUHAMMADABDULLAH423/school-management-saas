"use client";

import { useState, useTransition } from "react";
import { saveAttendance, type AttendanceMark } from "@/lib/actions";
import { Badge, Button, DataTable, EmptyState } from "@/components/ui";
import type { AttendanceStatus } from "@/lib/types";
import type { Dictionary, Locale } from "@/lib/i18n";

const STATUS_ORDER: AttendanceStatus[] = ["present", "absent", "late", "leave"];

export default function AttendanceMarker({
  locale,
  dict,
  classId,
  date,
  students,
  existing,
}: {
  locale: Locale;
  dict: Dictionary;
  classId: string;
  date: string;
  students: { id: string; name: string; admission_no: string }[];
  existing: Record<string, AttendanceStatus>;
}) {
  const [marks, setMarks] = useState<Record<string, AttendanceStatus>>(() => {
    const init: Record<string, AttendanceStatus> = {};
    for (const s of students) init[s.id] = existing[s.id] ?? "present";
    return init;
  });
  const [pending, startTransition] = useTransition();
  const [msg, setMsg] = useState<string | null>(null);

  const label = (s: AttendanceStatus) =>
    s === "present" ? dict.attendance.present
    : s === "absent" ? dict.attendance.absent
    : s === "late" ? dict.attendance.late
    : dict.attendance.leave;

  const tone = (s: AttendanceStatus) =>
    s === "present" ? "green" : s === "absent" ? "red" : s === "late" ? "amber" : "blue";

  function setAll(status: AttendanceStatus) {
    const next: Record<string, AttendanceStatus> = {};
    for (const s of students) next[s.id] = status;
    setMarks(next);
  }

  function cycle(id: string) {
    const cur = marks[id];
    const next = STATUS_ORDER[(STATUS_ORDER.indexOf(cur) + 1) % STATUS_ORDER.length];
    setMarks({ ...marks, [id]: next });
  }

  function save() {
    const list: AttendanceMark[] = students.map((s) => ({ student_id: s.id, status: marks[s.id] }));
    setMsg(null);
    startTransition(async () => {
      try {
        await saveAttendance({ locale, class_id: classId, date, marks: list });
        setMsg(dict.attendance.marked);
      } catch (e) {
        setMsg(e instanceof Error ? e.message : "Error");
      }
    });
  }

  if (!students.length) return <EmptyState text={dict.common.noData} />;

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap gap-2">
        <Button type="button" variant="secondary" onClick={() => setAll("present")}>
          {dict.attendance.markAll}
        </Button>
        <Button type="button" onClick={save} disabled={pending}>
          {pending ? dict.common.loading : dict.attendance.saveAttendance}
        </Button>
        {msg && <span className="self-center text-sm font-medium text-slate-600">{msg}</span>}
      </div>
      <DataTable head={[dict.common.name, dict.common.status]}>
        {students.map((s) => (
          <tr key={s.id} className="border-b border-slate-100 last:border-0">
            <td className="px-4 py-2.5 text-sm font-medium">
              {s.name} <span className="font-mono text-xs text-slate-400" dir="ltr">{s.admission_no}</span>
            </td>
            <td className="px-4 py-2.5">
              <button type="button" onClick={() => cycle(s.id)} title={dict.common.edit}>
                <Badge tone={tone(marks[s.id]) as "green" | "red" | "amber" | "blue"}>{label(marks[s.id])}</Badge>
              </button>
            </td>
          </tr>
        ))}
      </DataTable>
      <p className="text-xs text-slate-400">Tap a status badge to cycle: present → absent → late → leave.</p>
    </div>
  );
}
