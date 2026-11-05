-- ════════════════════════════════════════════════════════════════════
-- 2026-11-05  My Rentals (owner record-keeping) + internal investor-interest tag
-- ════════════════════════════════════════════════════════════════════
-- Applied to the live project as migration: landlord_toolkit_tables
-- Requires: public.saved_properties, public.set_updated_at(), public.is_admin().
--
-- Design rules (keep these when extending):
--   * Owner-only rows. A row can only be linked to a property/lease the same user owns.
--   * Records only. Nothing here collects, holds or moves rent, or contacts tenants.
--   * No admin read access to tenant data (names/emails/phones): admins see counts, not tenants.
--   * investor_interest is admin-only and invisible to ordinary users.
--   * No fee fields and no percentage-of-rent columns.

create table public.rental_leases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  property_id uuid not null references public.saved_properties(id) on delete cascade,
  tenant_name text not null,
  tenant_email text,
  tenant_phone text,
  monthly_rent numeric not null check (monthly_rent >= 0),
  security_deposit numeric default 0,
  lease_start date,
  lease_end date,
  rent_due_day int not null default 1 check (rent_due_day between 1 and 28),
  status text not null default 'active' check (status in ('upcoming','active','ended')),
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table public.rent_payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  lease_id uuid not null references public.rental_leases(id) on delete cascade,
  period date not null,                       -- first day of the rent month
  amount_due numeric not null check (amount_due >= 0),
  amount_received numeric not null default 0 check (amount_received >= 0),
  received_on date,
  status text not null default 'pending' check (status in ('pending','paid','partial','late')),
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (lease_id, period)
);

create table public.maintenance_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  property_id uuid not null references public.saved_properties(id) on delete cascade,
  title text not null,
  description text,
  status text not null default 'open' check (status in ('open','in_progress','done')),
  reported_on date default current_date,
  completed_on date,
  vendor text,
  cost numeric check (cost is null or cost >= 0),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table public.reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  property_id uuid references public.saved_properties(id) on delete cascade,
  lease_id uuid references public.rental_leases(id) on delete cascade,
  kind text not null check (kind in ('rent_due','late_rent','lease_expiring','insurance','tax','custom')),
  title text not null,
  due_date date not null,
  done boolean not null default false,
  done_at timestamptz,
  created_at timestamptz default now()
);

create table public.investor_interest (
  user_id uuid primary key references auth.users(id) on delete cascade,
  level text not null default 'none' check (level in ('none','curious','serious')),
  notes text,
  updated_at timestamptz default now()
);

create index on public.rental_leases (user_id);
create index on public.rental_leases (property_id);
create index on public.rent_payments (user_id);
create index on public.rent_payments (lease_id);
create index on public.maintenance_log (user_id);
create index on public.maintenance_log (property_id);
create index on public.reminders (user_id, due_date);
create index on public.reminders (property_id);
create index on public.reminders (lease_id);

create trigger set_rental_leases_updated_at before update on public.rental_leases for each row execute function public.set_updated_at();
create trigger set_rent_payments_updated_at before update on public.rent_payments for each row execute function public.set_updated_at();
create trigger set_maintenance_log_updated_at before update on public.maintenance_log for each row execute function public.set_updated_at();
create trigger set_investor_interest_updated_at before update on public.investor_interest for each row execute function public.set_updated_at();

alter table public.rental_leases enable row level security;
alter table public.rent_payments enable row level security;
alter table public.maintenance_log enable row level security;
alter table public.reminders enable row level security;
alter table public.investor_interest enable row level security;

create policy "owner manages leases" on public.rental_leases for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid())
    and exists (select 1 from public.saved_properties p where p.id = property_id and p.user_id = (select auth.uid())));

create policy "owner manages rent payments" on public.rent_payments for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid())
    and exists (select 1 from public.rental_leases l where l.id = lease_id and l.user_id = (select auth.uid())));

create policy "owner manages maintenance" on public.maintenance_log for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid())
    and exists (select 1 from public.saved_properties p where p.id = property_id and p.user_id = (select auth.uid())));

create policy "owner manages reminders" on public.reminders for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "admin manages investor interest" on public.investor_interest for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

revoke all on public.rental_leases, public.rent_payments, public.maintenance_log,
  public.reminders, public.investor_interest from anon;
