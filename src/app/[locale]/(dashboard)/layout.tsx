import { redirect } from "next/navigation";
import { getSessionUser } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { getDictionary, isValidLocale, type Locale } from "@/lib/i18n";
import { Header } from "@/components/Header";
import { BottomNav, Sidebar, navItems } from "@/components/Nav";

/** Role-guarded dashboard shell: sidebar on desktop, bottom nav on mobile. */
export default async function DashboardLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: { locale: string };
}) {
  const locale: Locale = isValidLocale(params.locale) ? params.locale : "en";
  const user = await getSessionUser();
  if (!user) redirect(`/${locale}/login`);

  const dict = await getDictionary(locale);
  const supabase = createClient();
  let schoolName: string | null = null;
  if (user.school_id) {
    const { data } = await supabase.from("schools").select("name").eq("id", user.school_id).maybeSingle();
    schoolName = data?.name ?? null;
  }

  const items = navItems(user.role, dict, locale);

  return (
    <div className="min-h-screen">
      <Header locale={locale} dict={dict} userName={user.full_name} schoolName={schoolName} />
      <div className="mx-auto flex max-w-6xl">
        <Sidebar items={items} />
        <main className="min-w-0 flex-1 px-4 pb-24 pt-4 md:pb-10">{children}</main>
      </div>
      <BottomNav items={items} />
    </div>
  );
}
