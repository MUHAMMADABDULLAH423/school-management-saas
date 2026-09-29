import { getDictionary, isValidLocale, type Locale } from "@/lib/i18n";
import LoginForm from "./LoginForm";

export default async function LoginPage({ params }: { params: { locale: string } }) {
  const locale: Locale = isValidLocale(params.locale) ? params.locale : "en";
  const dict = await getDictionary(locale);
  return (
    <main className="flex min-h-screen items-center justify-center bg-gradient-to-b from-brand-50 to-slate-100 px-4">
      <LoginForm locale={locale} dict={dict} />
    </main>
  );
}
