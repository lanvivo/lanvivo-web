-- ════════════════════════════════════════════════════════════════════
-- LANVIVO PORTAL — Supabase Schema
-- ════════════════════════════════════════════════════════════════════
-- Run this entire file in: Supabase Dashboard → SQL Editor → New Query
-- It creates all tables, indexes, and Row Level Security (RLS) policies.
-- Safe to re-run: uses IF NOT EXISTS where possible.

-- ────────────────────────────────────────────────────────────────────
-- PROFILES — public-facing user metadata (auth.users handles auth itself)
-- ────────────────────────────────────────────────────────────────────
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text,
  primary_language text default 'en',
  visa_status text,                -- optional, only set if user discloses
  marketing_consent boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.profiles enable row level security;

-- Policies: users can read and update only their own profile
drop policy if exists "Users can view own profile" on public.profiles;
create policy "Users can view own profile" on public.profiles
  for select using (auth.uid() = id);

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile" on public.profiles
  for update using (auth.uid() = id);

drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can insert own profile" on public.profiles
  for insert with check (auth.uid() = id);

-- Auto-create a profile row whenever a new user signs up via auth.users
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, name)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', new.email));
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ────────────────────────────────────────────────────────────────────
-- SAVED_PROPERTIES — replaces 'lv_properties' in localStorage
-- ────────────────────────────────────────────────────────────────────
create table if not exists public.saved_properties (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  inputs jsonb not null,           -- 16 form input fields as JSON
  metrics jsonb not null,          -- cached computed metrics for fast list view
  notes text,                      -- room for future "Notes on this property" feature
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists saved_properties_user_id_idx on public.saved_properties(user_id);
create index if not exists saved_properties_updated_at_idx on public.saved_properties(updated_at desc);

alter table public.saved_properties enable row level security;

drop policy if exists "Users can view own properties" on public.saved_properties;
create policy "Users can view own properties" on public.saved_properties
  for select using (auth.uid() = user_id);

drop policy if exists "Users can insert own properties" on public.saved_properties;
create policy "Users can insert own properties" on public.saved_properties
  for insert with check (auth.uid() = user_id);

drop policy if exists "Users can update own properties" on public.saved_properties;
create policy "Users can update own properties" on public.saved_properties
  for update using (auth.uid() = user_id);

drop policy if exists "Users can delete own properties" on public.saved_properties;
create policy "Users can delete own properties" on public.saved_properties
  for delete using (auth.uid() = user_id);


-- ────────────────────────────────────────────────────────────────────
-- PARTNER_LEADS — replaces 'lv_leads' in localStorage
-- ────────────────────────────────────────────────────────────────────
-- Captures CTA form submissions. Service role bypasses RLS for your admin queries.
create table if not exists public.partner_leads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,  -- nullable for anonymous submissions
  category text not null,          -- lender, cpa, property-manager, agent
  cta_id text not null,
  name text,
  email text not null,
  phone text,
  note text,
  saved_property_count int default 0,
  status text default 'new',       -- new, contacted, closed
  created_at timestamptz default now()
);

create index if not exists partner_leads_user_id_idx on public.partner_leads(user_id);
create index if not exists partner_leads_status_idx on public.partner_leads(status);
create index if not exists partner_leads_created_at_idx on public.partner_leads(created_at desc);

alter table public.partner_leads enable row level security;

-- Users can insert their own leads (or anonymous if no auth)
drop policy if exists "Anyone can submit leads" on public.partner_leads;
create policy "Anyone can submit leads" on public.partner_leads
  for insert with check (true);

-- Users can read their OWN leads (not other users' leads). You as admin use the service role
-- key in Supabase Dashboard to see all leads. No "view all leads" policy for security.
drop policy if exists "Users can view own leads" on public.partner_leads;
create policy "Users can view own leads" on public.partner_leads
  for select using (auth.uid() = user_id);


-- ────────────────────────────────────────────────────────────────────
-- GPT_WAITLIST — replaces 'lv_gpt_waitlist' in localStorage
-- ────────────────────────────────────────────────────────────────────
create table if not exists public.gpt_waitlist (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,      -- one entry per email
  user_id uuid references auth.users(id) on delete set null,
  source text default 'gpt-page',
  created_at timestamptz default now()
);

create index if not exists gpt_waitlist_email_idx on public.gpt_waitlist(email);
create index if not exists gpt_waitlist_created_at_idx on public.gpt_waitlist(created_at desc);

alter table public.gpt_waitlist enable row level security;

-- Anyone (even logged-out) can sign up for the waitlist
drop policy if exists "Anyone can join waitlist" on public.gpt_waitlist;
create policy "Anyone can join waitlist" on public.gpt_waitlist
  for insert with check (true);

-- Users can see their own waitlist entry (so the UI can show "you're on the list")
drop policy if exists "Users can view own waitlist" on public.gpt_waitlist;
create policy "Users can view own waitlist" on public.gpt_waitlist
  for select using (auth.uid() = user_id or auth.email() = email);


-- ────────────────────────────────────────────────────────────────────
-- UPDATED_AT TRIGGER — keeps updated_at fresh on row updates
-- ────────────────────────────────────────────────────────────────────
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists set_saved_properties_updated_at on public.saved_properties;
create trigger set_saved_properties_updated_at
  before update on public.saved_properties
  for each row execute function public.set_updated_at();


-- ────────────────────────────────────────────────────────────────────
-- PARTNER_APPLICATIONS: structured applications from agents, lenders, CPAs
-- submitted via the landing page partner modal
-- ────────────────────────────────────────────────────────────────────
create table if not exists public.partner_applications (
  id uuid primary key default gen_random_uuid(),
  role text not null,              -- 'lender', 'agent', or 'cpa'
  name text not null,
  email text not null,
  phone text,
  company text,
  details jsonb not null,          -- role-specific fields as JSON (products, languages, specialties, etc.)
  status text default 'new',       -- 'new', 'reviewing', 'approved', 'rejected'
  notes_internal text,             -- your private notes about this applicant
  created_at timestamptz default now(),
  reviewed_at timestamptz
);

create index if not exists partner_applications_role_idx on public.partner_applications(role);
create index if not exists partner_applications_status_idx on public.partner_applications(status);
create index if not exists partner_applications_created_at_idx on public.partner_applications(created_at desc);
create index if not exists partner_applications_email_idx on public.partner_applications(email);

alter table public.partner_applications enable row level security;

-- Anyone can submit a partner application (anonymous-friendly).
drop policy if exists "Anyone can apply as a partner" on public.partner_applications;
create policy "Anyone can apply as a partner" on public.partner_applications
  for insert with check (true);

-- No public read policy. Reads are admin-only via Supabase Dashboard (service_role bypasses RLS).
-- This prevents applicants from enumerating other applicants' data.


-- ────────────────────────────────────────────────────────────────────
-- SURVEY_RESPONSES: research responses from the immigrant buyer survey
-- ────────────────────────────────────────────────────────────────────
create table if not exists public.survey_responses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,  -- nullable: anonymous responses allowed
  email text,                      -- optional: only if user provides it
  answers jsonb not null,          -- full set of survey question answers
  source text default 'survey-page',
  created_at timestamptz default now()
);

create index if not exists survey_responses_user_id_idx on public.survey_responses(user_id);
create index if not exists survey_responses_email_idx on public.survey_responses(email);
create index if not exists survey_responses_created_at_idx on public.survey_responses(created_at desc);

alter table public.survey_responses enable row level security;

-- Anyone (logged in or not) can submit a survey response.
drop policy if exists "Anyone can submit survey" on public.survey_responses;
create policy "Anyone can submit survey" on public.survey_responses
  for insert with check (true);

-- Users can see their own responses if they're logged in (lets you build "view my answers" later)
drop policy if exists "Users can view own survey responses" on public.survey_responses;
create policy "Users can view own survey responses" on public.survey_responses
  for select using (auth.uid() = user_id);


-- ════════════════════════════════════════════════════════════════════
-- Setup complete. Verify in Table Editor: profiles, saved_properties,
-- partner_leads, gpt_waitlist, partner_applications, survey_responses
-- should all be visible with RLS enabled.
-- ════════════════════════════════════════════════════════════════════
