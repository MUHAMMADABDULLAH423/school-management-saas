import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "School Management SaaS",
  description: "Multi-tenant school management portal",
};

// The [locale] layout renders <html>/<body> so it can set lang + dir per locale.
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return children;
}
