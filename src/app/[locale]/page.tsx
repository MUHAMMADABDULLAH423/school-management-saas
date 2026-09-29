import { redirect } from "next/navigation";
import { getSessionUser } from "@/lib/auth";
import { isValidLocale, type Locale } from "@/lib/i18n";

export default async function LocaleHome({ params }: { params: { locale: string } }) {
  const locale: Locale = isValidLocale(params.locale) ? params.locale : "en";
  const user = await getSessionUser();
  redirect(user ? `/${locale}/dashboard` : `/${locale}/login`);
}
