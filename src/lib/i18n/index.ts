import en, { type Dictionary } from "./en";
import ur from "./ur";

export const locales = ["en", "ur"] as const;
export type Locale = (typeof locales)[number];

export const rtlLocales: Locale[] = ["ur"];

export function isValidLocale(l: string): l is Locale {
  return (locales as readonly string[]).includes(l);
}

export async function getDictionary(locale: Locale): Promise<Dictionary> {
  return locale === "ur" ? ur : en;
}

export type { Dictionary };
