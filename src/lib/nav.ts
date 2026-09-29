import type { Dictionary, Locale } from "@/lib/i18n";
import type { Role } from "@/lib/types";

export interface NavItem {
  href: string;
  label: string;
  icon: string;
}

/** Role-based navigation items. Server-safe: no "use client" here. */
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
