import { createClient } from "@/lib/supabase/server";
import type { Role, SessionUser } from "@/lib/types";

/** Logged-in user's profile row (role + school_id). Null when signed out. */
export async function getSessionUser(): Promise<SessionUser | null> {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data: profile } = await supabase
    .from("users")
    .select("id, school_id, email, full_name, role, status")
    .eq("id", user.id)
    .maybeSingle();

  if (!profile || profile.status !== "active") return null;
  return {
    id: profile.id,
    email: profile.email,
    full_name: profile.full_name,
    role: profile.role as Role,
    school_id: profile.school_id,
  };
}

/** Returns the staff row id for the logged-in teacher (needed for marked_by / entered_by). */
export async function getMyStaffId(): Promise<string | null> {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;
  const { data } = await supabase
    .from("staff")
    .select("id")
    .eq("user_id", user.id)
    .maybeSingle();
  return data?.id ?? null;
}
