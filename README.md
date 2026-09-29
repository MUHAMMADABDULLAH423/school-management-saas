# School Management SaaS

Multi-tenant school management portal built with **Next.js 14 (App Router) + TypeScript + Tailwind CSS + Supabase** (Postgres + Auth).

Every table carries `school_id` and tenant isolation is enforced by **Supabase Row Level Security** — the app never uses the `service_role` key; all queries run as the logged-in user.

## Roles

| Role | Landing | Can do |
|---|---|---|
| `super_admin` | `/dashboard/schools` | Create / suspend / activate schools (cross-tenant) |
| `school_admin` | `/dashboard/overview` | Principal dashboard, students, classes, teachers, fees, results, notices |
| `teacher` | `/dashboard/attendance` | Mark attendance for assigned classes, view own classes & notices |
| `parent` | `/dashboard/children` | **Read-only:** children, attendance %, fee vouchers, payments, published report cards, notices |

## Bilingual UI

Routes are prefixed with a locale segment: `/en/...` or `/ur/...`. Urdu renders with full RTL (`<html dir="rtl" lang="ur">`). Dictionaries live in `src/lib/i18n/en.ts` and `src/lib/i18n/ur.ts`. The header language switcher swaps the locale segment.

## Setup

### 1. Create a Supabase project
At [supabase.com](https://supabase.com) → New project. Copy the project URL and **anon** key (Project Settings → API).

### 2. Run the database schema
Supabase Dashboard → SQL Editor → paste and run **`supabase/schema.sql`**. This creates all tables, triggers (voucher/receipt numbering, status sync, audit logs) and RLS policies.

### 3. Create auth users
Authentication → Users → Add user (email + password) for each demo login below. Copy each user's UUID.

### 4. Seed demo data
Open **`supabase/seed.sql`**, replace the four UUID placeholders with the real Auth UUIDs (uncomment the `users` insert), then run it. You get: Green Wood School, 3 classes, 10 students, an exam, October fee vouchers, a notice.

### 5. Run the app
```bash
cp .env.example .env.local
# fill in NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY
npm install
npm run dev
```
Open http://localhost:3000 → redirects to `/en/login`.

## Demo logins

| Email | Password (set in Auth dashboard) | Role |
|---|---|---|
| `superadmin@demo.pk` | your choice | super_admin |
| `admin@greenwood.demo.pk` | your choice | school_admin |
| `teacher@greenwood.demo.pk` | your choice | teacher |
| `parent@greenwood.demo.pk` | your choice | parent |

> The `public.users` row must exist with the same UUID as the Auth user, with the correct `role` (and `school_id` for non-super-admins) and `status = 'active'`, otherwise login redirects but pages stay guarded.

## Project structure

```
src/app/[locale]/
  layout.tsx            # sets <html lang dir> per locale
  page.tsx              # redirects to /login or /dashboard
  (auth)/login/         # email/password sign-in
  (dashboard)/
    layout.tsx          # role-guarded shell: header, sidebar, bottom nav
    dashboard/page.tsx  # role-based landing redirects
    dashboard/overview  # principal dashboard (charts: 14-day attendance, fee recovery)
    dashboard/schools   # super_admin: school CRUD + suspend/activate
    dashboard/students  # search, class filter, add/edit
    dashboard/classes   # CRUD + headcounts
    dashboard/teachers  # staff list + class/subject assignments
    dashboard/fees      # generate monthly vouchers, record payments
    dashboard/results   # exams, publish toggle, marks entry grid
    dashboard/notices   # CRUD (admin), read (teacher)
    dashboard/attendance# teacher: mark present/absent/late/leave
    dashboard/my-classes# teacher: assigned classes
    dashboard/children  # parent read-only portal
src/components/        # ui primitives, Header, Nav, SVG Charts, forms
src/lib/
  i18n/                 # en.ts / ur.ts dictionaries
  supabase/             # browser + server clients (@supabase/ssr)
  auth.ts / guard.ts    # session user + role guards
  actions.ts            # Server Actions (mutations via RLS)
middleware.ts           # locale prefix + session refresh + dashboard guard
```

## Deployment (Vercel)

1. Push to GitHub, import in Vercel.
2. Set env vars `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY`.
3. Deploy — no build config needed (`npm run build`).

## Notes

- Fee voucher numbers (`FV-xxxxxxxx-1001…`) and receipt numbers are assigned by Postgres triggers/sequences — the app never generates them.
- Voucher `status` auto-syncs (`unpaid`/`partial`/`paid`) when payments are inserted.
- All writes go through RLS as the authenticated user; there is no service-role usage anywhere in the codebase.
- Audit logs are written by DB triggers on every insert/update/delete.
