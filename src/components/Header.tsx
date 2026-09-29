"use client";

import { usePathname, useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { Dictionary, Locale } from "@/lib/i18n";

export function Header({
  locale,
  dict,
  userName,
  schoolName,
}: {
  locale: Locale;
  dict: Dictionary;
  userName: string;
  schoolName?: string | null;
}) {
  const router = useRouter();
  const pathname = usePathname();
  const supabase = createClient();

  function switchLocale(next: Locale) {
    const segs = pathname.split("/");
    segs[1] = next;
    router.push(segs.join("/"));
    router.refresh();
  }

  async function logout() {
    await supabase.auth.signOut();
    router.push(`/${locale}/login`);
    router.refresh();
  }

  return (
    <header className="sticky top-0 z-20 border-b border-slate-200 bg-white/95 backdrop-blur">
      <div className="mx-auto flex max-w-6xl items-center justify-between gap-2 px-4 py-3">
        <div className="min-w-0">
          <p className="truncate text-sm font-bold text-slate-900">
            {schoolName ?? dict.auth.title}
          </p>
          <p className="truncate text-xs text-slate-500">{userName}</p>
        </div>
        <div className="flex items-center gap-2">
          <div className="flex overflow-hidden rounded-xl border border-slate-200 text-xs font-semibold">
            {(["en", "ur"] as Locale[]).map((l) => (
              <button
                key={l}
                onClick={() => switchLocale(l)}
                className={`px-3 py-1.5 ${locale === l ? "bg-brand-600 text-white" : "bg-white text-slate-600"}`}
              >
                {l === "en" ? "EN" : "اردو"}
              </button>
            ))}
          </div>
          <button
            onClick={logout}
            className="rounded-xl bg-slate-100 px-3 py-1.5 text-xs font-semibold text-slate-700 hover:bg-slate-200"
          >
            {dict.nav.logout}
          </button>
        </div>
      </div>
    </header>
  );
}
