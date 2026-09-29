"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { Button, Card, Field, TextInput } from "@/components/ui";
import type { Dictionary, Locale } from "@/lib/i18n";

export default function LoginForm({ locale, dict }: { locale: Locale; dict: Dictionary }) {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    const supabase = createClient();
    const { error: signInError } = await supabase.auth.signInWithPassword({ email, password });
    if (signInError) {
      setError(dict.auth.invalid);
      setBusy(false);
      return;
    }
    // The dashboard route reads public.users and routes by role.
    router.push(`/${locale}/dashboard`);
    router.refresh();
  }

  return (
    <Card className="w-full max-w-sm p-6">
      <h1 className="text-xl font-bold text-slate-900">{dict.auth.title}</h1>
      <p className="mt-1 text-sm text-slate-500">{dict.auth.subtitle}</p>
      <form onSubmit={onSubmit} className="mt-6 space-y-4">
        <Field label={dict.auth.email}>
          <TextInput
            type="email"
            required
            autoComplete="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            dir="ltr"
          />
        </Field>
        <Field label={dict.auth.password}>
          <TextInput
            type="password"
            required
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            dir="ltr"
          />
        </Field>
        {error && <p className="text-sm font-medium text-red-600">{error}</p>}
        <Button className="w-full" disabled={busy}>
          {busy ? dict.auth.signingIn : dict.auth.signIn}
        </Button>
      </form>
    </Card>
  );
}
