"use client";

import { useState, useTransition } from "react";
import { saveMarks, type MarkInput } from "@/lib/actions";
import { Button, Card, DataTable, EmptyState, TextInput } from "@/components/ui";
import type { Dictionary, Locale } from "@/lib/i18n";

interface RowMark {
  obtained: string;
  total: string;
}

export default function MarksEntry({
  locale,
  dict,
  examId,
  students,
  subjects,
  existing,
}: {
  locale: Locale;
  dict: Dictionary;
  examId: string;
  students: { id: string; name: string; admission_no: string }[];
  subjects: string[];
  existing: Record<string, { obtained: number; total: number }>; // key: studentId|subject
}) {
  const [subject, setSubject] = useState(subjects[0] ?? "");
  const [newSubject, setNewSubject] = useState("");
  const [rows, setRows] = useState<Record<string, RowMark>>(() => {
    const init: Record<string, RowMark> = {};
    for (const s of students) {
      const e = existing[`${s.id}|${subject}`];
      init[s.id] = { obtained: e ? String(e.obtained) : "", total: e ? String(e.total) : "" };
    }
    return init;
  });
  const [pending, startTransition] = useTransition();
  const [msg, setMsg] = useState<string | null>(null);

  function switchSubject(sub: string) {
    setSubject(sub);
    setRows((prev) => {
      const next: Record<string, RowMark> = {};
      for (const s of students) {
        const e = existing[`${s.id}|${sub}`];
        next[s.id] = prev[s.id] && sub === subject ? prev[s.id] : { obtained: e ? String(e.obtained) : "", total: e ? String(e.total) : "" };
      }
      return next;
    });
    setMsg(null);
  }

  function addSubject() {
    const s = newSubject.trim();
    if (!s) return;
    setNewSubject("");
    switchSubject(s);
  }

  function save() {
    const marks: MarkInput[] = students.map((s) => ({
      student_id: s.id,
      subject,
      obtained: Number(rows[s.id]?.obtained || 0),
      total: Number(rows[s.id]?.total || 0),
    }));
    setMsg(null);
    startTransition(async () => {
      try {
        await saveMarks({ locale, exam_id: examId, marks });
        setMsg(dict.common.saved);
      } catch (e) {
        setMsg(e instanceof Error ? e.message : "Error");
      }
    });
  }

  const allSubjects = [...new Set([...subjects, ...(subject && !subjects.includes(subject) ? [subject] : [])])];

  return (
    <Card className="p-4">
      <div className="mb-3 flex flex-wrap items-end gap-2">
        <div className="flex gap-1 overflow-x-auto">
          {allSubjects.map((s) => (
            <button
              key={s}
              type="button"
              onClick={() => switchSubject(s)}
              className={`rounded-lg px-3 py-1.5 text-sm font-semibold ${subject === s ? "bg-brand-600 text-white" : "bg-slate-100 text-slate-700"}`}
            >
              {s}
            </button>
          ))}
        </div>
        <div className="flex gap-2">
          <TextInput value={newSubject} onChange={(e) => setNewSubject(e.target.value)} placeholder={dict.results.subject} className="!w-36" />
          <Button type="button" variant="secondary" onClick={addSubject}>+</Button>
        </div>
      </div>

      {!students.length ? (
        <EmptyState text={dict.common.noData} />
      ) : (
        <>
          <DataTable head={[dict.common.name, dict.results.obtained, dict.results.totalMarks]}>
            {students.map((s) => (
              <tr key={s.id} className="border-b border-slate-100 last:border-0">
                <td className="px-4 py-2 text-sm font-medium">
                  {s.name} <span className="font-mono text-xs text-slate-400" dir="ltr">{s.admission_no}</span>
                </td>
                <td className="px-4 py-2">
                  <TextInput
                    type="number" min={0} step="0.5" dir="ltr" className="!w-24"
                    value={rows[s.id]?.obtained ?? ""}
                    onChange={(e) => setRows({ ...rows, [s.id]: { ...rows[s.id], obtained: e.target.value } })}
                  />
                </td>
                <td className="px-4 py-2">
                  <TextInput
                    type="number" min={1} step="1" dir="ltr" className="!w-24"
                    value={rows[s.id]?.total ?? ""}
                    onChange={(e) => setRows({ ...rows, [s.id]: { ...rows[s.id], total: e.target.value } })}
                  />
                </td>
              </tr>
            ))}
          </DataTable>
          <div className="mt-3 flex items-center gap-3">
            <Button type="button" onClick={save} disabled={pending || !subject}>
              {pending ? dict.common.loading : dict.results.enterMarks}
            </Button>
            {msg && <span className="text-sm font-medium text-slate-600">{msg}</span>}
          </div>
        </>
      )}
    </Card>
  );
}
