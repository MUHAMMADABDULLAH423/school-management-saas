import { notFound } from "next/navigation";
import { getDictionary, isValidLocale, rtlLocales, type Locale } from "@/lib/i18n";

export default async function LocaleLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: { locale: string };
}) {
  if (!isValidLocale(params.locale)) notFound();
  const locale = params.locale as Locale;
  await getDictionary(locale); // validate availability
  const dir = rtlLocales.includes(locale) ? "rtl" : "ltr";
  return (
    <html lang={locale} dir={dir} suppressHydrationWarning>
      <body className="min-h-screen">{children}</body>
    </html>
  );
}
