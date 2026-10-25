begin;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to anon, authenticated;

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text check (display_name is null or char_length(display_name) <= 80),
  avatar_url text,
  role text not null default 'user'
    check (role in ('user', 'brand', 'admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.brands (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 2 and 120),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  description text,
  logo_url text,
  status text not null default 'pending'
    check (status in ('pending', 'active', 'suspended')),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.brand_memberships (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references public.brands (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete restrict,
  membership_role text not null default 'member'
    check (membership_role in ('owner', 'manager', 'analyst', 'member')),
  status text not null default 'active'
    check (status in ('invited', 'active', 'suspended')),
  invited_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint brand_memberships_brand_profile_unique unique (brand_id, profile_id)
);

create table public.campaigns (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references public.brands (id) on delete restrict,
  name text not null check (char_length(btrim(name)) between 2 and 160),
  objective text not null check (char_length(btrim(objective)) between 2 and 2000),
  budget_amount numeric(14, 2) check (budget_amount is null or budget_amount >= 0),
  budget_currency char(3) not null default 'THB'
    check (budget_currency ~ '^[A-Z]{3}$'),
  status text not null default 'draft'
    check (status in ('draft', 'scheduled', 'active', 'paused', 'completed', 'archived')),
  starts_at timestamptz,
  ends_at timestamptz,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint campaigns_dates_valid check (starts_at is null or ends_at is null or starts_at < ends_at),
  constraint campaigns_id_brand_unique unique (id, brand_id)
);

create table public.missions (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(btrim(title)) between 2 and 160),
  description text not null check (char_length(btrim(description)) between 2 and 4000),
  mission_type text not null
    check (mission_type in ('steps', 'distance', 'duration', 'check_in', 'custom')),
  activity_type text not null
    check (activity_type in ('steps', 'walk', 'run', 'cycle', 'swim', 'check_in', 'custom')),
  target_value numeric(14, 3) not null check (target_value > 0),
  target_unit text not null
    check (target_unit in ('steps', 'km', 'miles', 'minutes', 'sessions', 'count')),
  points integer not null check (points > 0),
  requires_evidence boolean not null default false,
  status text not null default 'draft'
    check (status in ('draft', 'scheduled', 'active', 'paused', 'ended', 'archived')),
  starts_at timestamptz,
  ends_at timestamptz,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint missions_dates_valid check (starts_at is null or ends_at is null or starts_at < ends_at)
);

create table public.challenges (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null,
  brand_id uuid not null,
  title text not null check (char_length(btrim(title)) between 2 and 160),
  description text not null check (char_length(btrim(description)) between 2 and 4000),
  objective text not null check (char_length(btrim(objective)) between 2 and 2000),
  activity_type text not null
    check (activity_type in ('steps', 'walk', 'run', 'cycle', 'swim', 'check_in', 'custom')),
  target_value numeric(14, 3) not null check (target_value > 0),
  target_unit text not null
    check (target_unit in ('steps', 'km', 'miles', 'minutes', 'sessions', 'count')),
  reward_points integer not null check (reward_points > 0),
  requires_evidence boolean not null default false,
  participant_limit integer check (participant_limit is null or participant_limit > 0),
  status text not null default 'draft'
    check (status in ('draft', 'scheduled', 'active', 'paused', 'completed', 'cancelled')),
  starts_at timestamptz,
  ends_at timestamptz,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint challenges_dates_valid check (starts_at is null or ends_at is null or starts_at < ends_at),
  constraint challenges_campaign_brand_fk
    foreign key (campaign_id, brand_id)
    references public.campaigns (id, brand_id)
    on delete restrict
);

create index brands_status_idx on public.brands (status);
create index brand_memberships_profile_status_idx on public.brand_memberships (profile_id, status);
create index campaigns_brand_status_created_idx
  on public.campaigns (brand_id, status, created_at desc);
create index missions_status_dates_idx on public.missions (status, starts_at, ends_at);
create index challenges_campaign_status_idx on public.challenges (campaign_id, status);
create index challenges_brand_status_dates_idx on public.challenges (brand_id, status, starts_at, ends_at);

commit;
