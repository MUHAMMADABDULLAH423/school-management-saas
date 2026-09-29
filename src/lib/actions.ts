"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getMyStaffId, getSessionUser } from "@/lib/auth";
import type { AttendanceStatus } from "@/lib/types";

function monthStart(ym: string): string {
  // ym = "2026-10"
  return `${ym}-01`;
}

async function requireSchoolAdmin() {
  const u = await getSessionUser();
  if (!u || u.role !== "school_admin" || !u.school_id) throw new Error("Forbidden");
  return u;
}

async function requireSuperAdmin() {
  const u = await getSessionUser();
  if (!u || u.role !== "super_admin") throw new Error("Forbidden");
  return u;
}

/* ---------------- Schools (super_admin) ---------------- */

export async function createSchool(formData: FormData) {
  await requireSuperAdmin();
  const supabase = createClient();
  const { error } = await supabase.from("schools").insert({
    name: String(formData.get("name") ?? "").trim(),
    name_ur: String(formData.get("name_ur") ?? "").trim() || null,
    address: String(formData.get("address") ?? "").trim() || null,
    phone: String(formData.get("phone") ?? "").trim() || null,
    email: String(formData.get("email") ?? "").trim() || null,
    plan: String(formData.get("plan") ?? "trial"),
  });
  if (error) throw new Error(error.message);
  const locale = String(formData.get("locale") ?? "en");
  revalidatePath(`/${locale}/dashboard/schools`);
}

export async function setSchoolStatus(formData: FormData) {
  await requireSuperAdmin();
  const supabase = createClient();
  const { error } = await supabase
    .from("schools")
    .update({ status: String(formData.get("status")) })
    .eq("id", String(formData.get("id")));
  if (error) throw new Error(error.message);
  const locale = String(formData.get("locale") ?? "en");
  revalidatePath(`/${locale}/dashboard/schools`);
}

/* ---------------- Classes ---------------- */

export async function upsertClass(formData: FormData) {
  const u = await requireSchoolAdmin();
  const supabase = createClient();
  const payload = {
    school_id: u.school_id!,
    name: String(formData.get("name") ?? "").trim(),
    section: String(formData.get("section") ?? "A").trim() || "A",
    academic_year: String(formData.get("academic_year") ?? "").trim(),
  };
  const id = String(formData.get("id") ?? "");
  const { error } = id
    ? await supabase.from("classes").update(payload).eq("id", id)
    : await supabase.from("classes").insert(payload);
  if (error) throw new Error(error.message);
  const locale = String(formData.get("locale") ?? "en");
  revalidatePath(`/${locale}/dashboard/classes`);
  redirect(`/${locale}/dashboard/classes`);
}

export async function deleteClass(formData: FormData) {
  await requireSchoolAdmin();
  const supabase = createClient();
  const { error } = await supabase
    .from("classes")
    .delete()
    .eq("id", String(formData.get("id")));
  if (error) throw new Error(error.message);
  const locale = String(formData.get("locale") ?? "en");
  revalidatePath(`/${locale}/dashboard/classes`);
}

/* ---------------- Students ---------------- */

export async function upsertStudent(formData: FormData) {
  const u = await requireSchoolAdmin();
  const supabase = createClient();
  const payload = {
    school_id: u.school_id!,
    admission_no: String(formData.get("admission_no") ?? "").trim(),
    name: String(formData.get("name") ?? "").trim(),
    name_ur: String(formData.get("name_ur") ?? "").trim() || null,
    father_name: String(formData.get("father_name") ?? "").trim() || null,
    gender: String(formData.get("gender") ?? "") || null,
    date_of_birth: String(formData.get("date_of_birth") ?? "") || null,
    class_id: String(formData.get("class_id") ?? ""),
    phone: String(formData.get("phone") ?? "").trim() || null,
    address: String(formData.get("address") ?? "").trim() || null,
    status: String(formData.get("status") ?? "active"),
  };
  const id = String(formData.get("id") ?? "");
  const { error } = id
    ? await supabase.from("students").update(payload).eq("id", id)
    : await supabase.from("students").insert(payload);
  if (error) throw new Error(error.message);
  const locale = String(formData.get("locale") ?? "en");
  revalidatePath(`/${locale}/dashboard/students`);
  redirect(`/${locale}/dashboard/students`);
}

/* ---------------- Teachers / staff ---------------- */

export async function assignTeacherClass(formData: FormData) {
  const u = await requireSchoolAdmin();
  const supabase = createClient();
  const { error } = await supabase.from("teacher_class_map").insert({
    school_id: u.school_id!,
    staff_id: String(formData.get("staff_id")),
    class_id: String(formData.get("class_id")),
    subject: String(formData.get("subject") ?? "").trim(),
  });
  if (error) throw new Error(error.message);
  const locale = String(formData.get("locale") ?? "en");
  revalidatePath(`/${locale}/dashboard/teachers`);
}

export async function removeTeacherClass(formData: FormData) {
  await requireSchoolAdmin();
  const supabase = createClient();
  const { error } = await supabase
    .from("teacher_class_map")
    .delete()
    .eq("id", String(formData.get("id")));
  if (error) throw new Error(error.message);
  const locale = String(formData.get("locale") ?? "en");
  revalidatePath(`/${locale}/dashboard/teachers`);
}

/* ---------------- Attendance (teacher) ---------------- */

export interface AttendanceMark {
  student_id: string;
  status: AttendanceStatus;
}

export async function saveAttendance(input: {
  locale: string;
  class_id: string;
  date: string;
  marks: AttendanceMark[];
}) {
  const supabase = createClient();
  const u = await getSessionUser();
  if (!u || u.role !== "teacher" || !u.school_id) throw new Error("Forbidden");
  const staffId = await getMyStaffId();
  if (!staffId) throw new Error("No staff profile");

  const rows = input.marks.map((m) => ({
    school_id: u.school_id!,
    student_id: m.student_id,
    class_id: input.class_id,
    date: input.date,
    status: m.status,
    marked_by: staffId,
  }));

  // Upsert on the unique (school_id, student_id, date) key.
  const { error } = await supabase
    .from("attendance")
    .upsert(rows, { onConflict: "school_id,student_id,date" });
  if (error) throw new Error(error.message);
  revalidatePath(`/${input.locale}/dashboard/attendance`);
  return { ok: true };
}

/* ---------------- Fees ---------------- */

export async function generateVouchers(formData: FormData) {
  const u = await requireSchoolAdmin();
  const supabase = createClient();
  const classId = String(formData.get("class_id"));
  const month = monthStart(String(formData.get("month")));
  const amount = Number(formData.get("amount"));
  const dueDate = String(formData.get("due_date"));
  const title = String(formData.get("title") ?? "").trim() || `Fee ${month.slice(0, 7)}`;

  const { data: students, error: sErr } = await supabase
    .from("students")
    .select("id")
    .eq("class_id", classId)
    .eq("status", "active");
  if (sErr) throw new Error(sErr.message);
  if (!students?.length) throw new Error("No active students in this class");

  const rows = students.map((s) => ({
    school_id: u.school_id!,
    student_id: s.id,
    title,
    month,
    amount,
    due_date: dueDate,
    created_by: u.id,
  }));
  // voucher_no is assigned by the DB trigger.
  const { error } = await supabase.from("fee_vouchers").insert(rows);
  if (error) throw new Error(error.message);
  const locale = String(formData.get("locale") ?? "en");
  revalidatePath(`/${locale}/dashboard/fees`);
  redirect(`/${locale}/dashboard/fees`);
}

export async function recordPayment(formData: FormData) {
  const u = await requireSchoolAdmin();
  const supabase = createClient();
  // receipt_no + voucher status are maintained by DB triggers.
  const { error } = await supabase.from("fee_payments").insert({
    school_id: u.school_id!,
    voucher_id: String(formData.get("voucher_id")),
    amount: Number(formData.get("amount")),
    method: String(formData.get("method") ?? "cash"),
    notes: String(formData.get("notes") ?? "").trim() || null,
    collected_by: u.id,
  });
  if (error) throw new Error(error.message);
  const locale = String(formData.get("locale") ?? "en");
  revalidatePath(`/${locale}/dashboard/fees`);
}

/* ---------------- Exams & marks ---------------- */

export async function createExam(formData: FormData) {
  const u = await requireSchoolAdmin();
  const supabase = createClient();
  const { error } = await supabase.from("exams").insert({
    school_id: u.school_id!,
    name: String(formData.get("name") ?? "").trim(),
    academic_year: String(formData.get("academic_year") ?? "").trim(),
    starts_on: String(formData.get("starts_on") ?? "") || null,
    ends_on: String(formData.get("ends_on") ?? "") || null,
  });
  if (error) throw new Error(error.message);
  const locale = String(formData.get("locale") ?? "en");
  revalidatePath(`/${locale}/dashboard/results`);
  redirect(`/${locale}/dashboard/results`);
}

export async function toggleExamPublished(formData: FormData) {
  await requireSchoolAdmin();
  const supabase = createClient();
  const { error } = await supabase
    .from("exams")
    .update({ result_published: formData.get("published") === "true" })
    .eq("id", String(formData.get("id")));
  if (error) throw new Error(error.message);
  const locale = String(formData.get("locale") ?? "en");
  revalidatePath(`/${locale}/dashboard/results`);
}

export interface MarkInput {
  student_id: string;
  subject: string;
  obtained: number;
  total: number;
}

export async function saveMarks(input: {
  locale: string;
  exam_id: string;
  marks: MarkInput[];
}) {
  const supabase = createClient();
  const u = await getSessionUser();
  if (!u || (u.role !== "teacher" && u.role !== "school_admin") || !u.school_id)
    throw new Error("Forbidden");
  const staffId = u.role === "teacher" ? await getMyStaffId() : null;
  // school_admin marks entry still needs a staff id for entered_by; use own staff row if present.
  const enteredBy =
    staffId ??
    (await supabase.from("staff").select("id").eq("user_id", u.id).maybeSingle()).data?.id;
  if (!enteredBy) throw new Error("No staff profile for marks entry");

  const rows = input.marks
    .filter((m) => m.obtained >= 0 && m.total > 0)
    .map((m) => ({
      school_id: u.school_id!,
      student_id: m.student_id,
      exam_id: input.exam_id,
      subject: m.subject.trim(),
      marks_obtained: m.obtained,
      total_marks: m.total,
      entered_by: enteredBy,
    }));
  if (!rows.length) return { ok: true };
  const { error } = await supabase
    .from("marks")
    .upsert(rows, { onConflict: "school_id,student_id,exam_id,subject" });
  if (error) throw new Error(error.message);
  revalidatePath(`/${input.locale}/dashboard/results`);
  return { ok: true };
}

/* ---------------- Notices ---------------- */

export async function createNotice(formData: FormData) {
  const u = await requireSchoolAdmin();
  const supabase = createClient();
  const audience = String(formData.get("audience"));
  const { error } = await supabase.from("notices").insert({
    school_id: u.school_id!,
    title: String(formData.get("title") ?? "").trim(),
    content: String(formData.get("content") ?? "").trim(),
    audience,
    class_id: audience === "class_specific" ? String(formData.get("class_id")) : null,
    posted_by: u.id,
    expires_at: String(formData.get("expires_at") ?? "") || null,
  });
  if (error) throw new Error(error.message);
  const locale = String(formData.get("locale") ?? "en");
  revalidatePath(`/${locale}/dashboard/notices`);
  redirect(`/${locale}/dashboard/notices`);
}

export async function deleteNotice(formData: FormData) {
  await requireSchoolAdmin();
  const supabase = createClient();
  const { error } = await supabase
    .from("notices")
    .delete()
    .eq("id", String(formData.get("id")));
  if (error) throw new Error(error.message);
  const locale = String(formData.get("locale") ?? "en");
  revalidatePath(`/${locale}/dashboard/notices`);
}
