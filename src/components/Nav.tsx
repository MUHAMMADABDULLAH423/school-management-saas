"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { Dictionary, Locale } from "@/lib/i18n";
import type { Role } from "@/lib/types";

export interface NavItem {
  href: string;
  label: string;
  icon: string;
}

export function navItems(role: Role, dict: Dictionary, locale: Locale): NavItem[] {
  const base = `/${locale}/dashboard`;
  switch (role) {
    case "super_admin":
      return [{ href: `${base}/schools`, label: dict.nav.schools, icon: "🏫" }];
    case "school_admin":
      return [
        { href: `${base}/overview`, label: dict.nav.dashboard, icon: "📊" },
        { href: `${base}/students`, label: dict.nav.students, icon: "🎒" },
        { href: `${base}/classes`, label: dict.nav.classes, icon: "🏷️" },
        { href: `${base}/teachers`, label: dict.nav.teachers, icon: "👩‍🏫" },
        { href: `${base}/fees`, label: dict.nav.fees, icon: "💰" },
        { href: `${base}/results`, label: dict.nav.results, icon: "📝" },
        { href: `${base}/notices`, label: dict.nav.notices, icon: "📢" },
      ];
    case "teacher":
      return [
        { href: `${base}/attendance`, label: dict.nav.attendance, icon: "✅" },
        { href: `${base}/my-classes`, label: dict.nav.myClasses, icon: "🏷️" },
        { href: `${base}/notices`, label: dict.nav.notices, icon: "📢" },
      ];
    case "parent":
      return [{ href: `${base}/children`, label: dict.nav.children, icon: "👨‍👩‍👧" }];
  }
}

function isActive(pathname: string, href: string) {
  return pathname === href || pathname.startsWith(href + "/");
}

/** Desktop sidebar (hidden on small screens). */
export function Sidebar({ items }: { items: NavItem[] }) {
  const pathname = usePathname();
  return (
    <aside className="hidden w-60 shrink-0 md:block">
      <nav className="sticky top-[65px] space-y-1 p-3">
        {items.map((it) => {
          const on = isActive(pathname, it.href);
          return (
            <Link
              key={it.href}
              href={it.href}
              className={`flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium ${
                on ? "bg-brand-600 text-white" : "text-slate-700 hover:bg-slate-100"
              }`}
            >
              <span aria-hidden>{it.icon}</span>
              {it.label}
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}

/** Mobile bottom navigation. */
export function BottomNav({ items }: { items: NavItem[] }) {
  const pathname = usePathname();
  return (
    <nav className="fixed inset-x-0 bottom-0 z-20 border-t border-slate-200 bg-white/95 pb-[env(safe-area-inset-bottom)] backdrop-blur md:hidden">
      <div className="grid" style={{ gridTemplateColumns: `repeat(${items.length}, minmax(0,1fr))` }}>
        {items.map((it) => {
          const on = isActive(pathname, it.href);
          return (
            <Link
              key={it.href}
              href={it.href}
              className={`flex flex-col items-center gap-0.5 px-1 py-2 text-[11px] font-medium ${
                on ? "text-brand-600" : "text-slate-500"
              }`}
            >
              <span className="text-lg" aria-hidden>
                {it.icon}
              </span>
              <span className="truncate">{it.label}</span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
