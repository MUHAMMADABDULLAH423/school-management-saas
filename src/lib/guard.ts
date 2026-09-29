import { redirect } from "next/navigation";
import { getSessionUser } from "./auth";
import type { Role, SessionUser } from "./types";
import type { Locale } from "./i18n";

/** Server-side role guard for dashboard pages. Redirects if not allowed. */
export async function requireRoles(roles: Role[], locale: Locale): Promise<SessionUser> {
  const user = await getSessionUser();
  if (!user) redirect(`/${locale}/login`);
  if (!roles.includes(user.role)) redirect(`/${locale}/dashboard`);
  return user;
}
