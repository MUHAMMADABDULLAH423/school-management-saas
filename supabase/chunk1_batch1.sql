/*
  School Management SaaS — Multi-tenant Supabase/PostgreSQL schema
  =================================================================
  Stack: Next.js (App Router) + Tailwind + Supabase (Postgres + Auth)

  Tenancy model
  -------------
  • public.schools is the tenant table.
  • EVERY application table carries school_id (NOT NULL, except users where
    super_admin rows have school_id = NULL).
  • Tenant isolation is enforced by Row Level Security on every table —
    no application query can ever read or write another school's rows.

  Roles
  -----
  • super_admin  — manages schools; school_id IS NULL; full cross-tenant read.
  • school_admin — full control inside their own school (principal/admin).
  • teacher      — scoped to assigned classes (attendance, marks for own subjects).
  • parent       — READ-ONLY access to their mapped children.

  Auth notes
  ----------
  • Supabase Auth stores passwords (bcrypt) + recovery flow; this schema never
    stores passwords.
  • Authorization uses the server-maintained public.users.role / status, never
    the user-editable raw_user_meta_data.
  • Provision Auth users first (Supabase dashboard or Admin API), then insert
    the matching public.users row with the same UUID.

  Run this in a fresh Supabase project's SQL Editor as the database owner.
*/

create extension if not exists pgcrypto;
create schema if not exists app_private;
revoke all on schema app_private from public;

-- ================= Tenant table =================

create table if not exists public.schools (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  name_ur text,
  address text,
  phone text,
  email text,
  logo_url text,
  plan text not null default 'trial'
    check (plan in ('trial', 'basic', 'standard', 'premium')),
  status text not null default 'active'
    check (status in ('active', 'suspended', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ================= Users & roles =================

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  school_id uuid references public.schools(id) on delete restrict,
  email text not null,
  full_name text not null,
  role text not null
    check (role in ('super_admin', 'school_admin', 'teacher', 'parent')),
  status text not null default 'active'
    check (status in ('active', 'inactive', 'suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint users_school_role_ck check (
    (role = 'super_admin' and school_id is null)
    or (role <> 'super_admin' and school_id is not null)
  )
);

create unique index if not exists users_email_lower_uq
  on public.users (lower(email));
create index if not exists users_school_id_idx on public.users(school_id);
create index if not exists users_role_idx on public.users(role);

-- ================= School structure =================

