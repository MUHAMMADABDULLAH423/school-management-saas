// Shared row types matching supabase/schema.sql

export type Role = "super_admin" | "school_admin" | "teacher" | "parent";

export interface School {
  id: string;
  name: string;
  name_ur: string | null;
  address: string | null;
  phone: string | null;
  email: string | null;
  plan: "trial" | "basic" | "standard" | "premium";
  status: "active" | "suspended" | "archived";
  created_at: string;
}

export interface AppUser {
  id: string;
  school_id: string | null;
  email: string;
  full_name: string;
  role: Role;
  status: "active" | "inactive" | "suspended";
}

export interface ClassRow {
  id: string;
  school_id: string;
  name: string;
  section: string;
  academic_year: string;
  class_teacher_id: string | null;
}

export interface Student {
  id: string;
  school_id: string;
  admission_no: string;
  name: string;
  name_ur: string | null;
  father_name: string | null;
  gender: "male" | "female" | "other" | null;
  date_of_birth: string | null;
  class_id: string;
  phone: string | null;
  address: string | null;
  status: string;
  admitted_on: string;
}

export interface Staff {
  id: string;
  school_id: string;
  user_id: string;
  employee_no: string | null;
  name: string;
  designation: string;
  subjects: string[];
  phone: string | null;
}

export interface TeacherClassMap {
  id: string;
  school_id: string;
  staff_id: string;
  class_id: string;
  subject: string;
}

export type AttendanceStatus = "present" | "absent" | "late" | "leave" | "holiday";

export interface AttendanceRow {
  id: string;
  school_id: string;
  student_id: string;
  class_id: string;
  date: string;
  status: AttendanceStatus;
  marked_by: string;
}

export interface Exam {
  id: string;
  school_id: string;
  name: string;
  name_ur: string | null;
  academic_year: string;
  starts_on: string | null;
  ends_on: string | null;
  result_published: boolean;
}

export interface Mark {
  id: string;
  school_id: string;
  student_id: string;
  exam_id: string;
  subject: string;
  marks_obtained: number;
  total_marks: number;
}

export interface FeeVoucher {
  id: string;
  school_id: string;
  student_id: string;
  voucher_no: string;
  title: string;
  month: string; // YYYY-MM-01
  amount: number;
  discount: number;
  due_date: string;
  status: "unpaid" | "partial" | "paid" | "waived" | "overdue";
}

export interface FeePayment {
  id: string;
  school_id: string;
  voucher_id: string;
  amount: number;
  method: "cash" | "bank" | "online" | "other";
  receipt_no: number;
  paid_at: string;
}

export interface Notice {
  id: string;
  school_id: string;
  title: string;
  title_ur: string | null;
  content: string;
  content_ur: string | null;
  audience: "school_wide" | "teachers" | "parents" | "class_specific";
  class_id: string | null;
  published_at: string;
  expires_at: string | null;
}

export interface SessionUser {
  id: string;
  email: string;
  full_name: string;
  role: Role;
  school_id: string | null;
}
