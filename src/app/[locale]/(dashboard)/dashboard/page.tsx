import { redirect } from "next/navigation";
import { getSessionUser } from "@/lib/auth";
import { isValidLocale, type Locale } from "@/lib/i18n";

/** Role-based landing: send each role to its home screen. */
export default async function DashboardHome({ params }: { params: { locale: string } }) {
  const locale: Locale = isValidLocale(params.locale) ? params.locale : "en";
  const user = await getSessionUser();
  if (!user) redirect(`/${locale}/login`);

  const base = `/${locale}/dashboard`;
  switch (user.role) {
    case "super_admin":
      redirect(`${base}/schools`);
    case "school_admin":
      redirect(`${base}/overview`);
    case "teacher":
      redirect(`${base}/attendance`);
    case "parent":
      redirect(`${base}/children`);
  }
}
