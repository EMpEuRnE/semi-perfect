begin;

create table public.user_missions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete restrict,
  mission_id uuid not null references public.missions (id) on delete restrict,
  status text not null default 'joined'
    check (status in ('joined', 'in_progress', 'completed', 'cancelled', 'expired')),
  progress_value numeric(14, 3) not null default 0 check (progress_value >= 0),
  joined_at timestamptz not null default now(),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_missions_user_mission_unique unique (user_id, mission_id),
  constraint user_missions_id_user_unique unique (id, user_id),
  constraint user_missions_completion_consistent check (
    (status = 'completed') = (completed_at is not null)
  )
);

create table public.challenge_participants (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges (id) on delete restrict,
  user_id uuid not null references public.profiles (id) on delete restrict,
  status text not null default 'joined'
    check (status in ('joined', 'in_progress', 'completed', 'cancelled', 'disqualified')),
  progress_value numeric(14, 3) not null default 0 check (progress_value >= 0),
  joined_at timestamptz not null default now(),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint challenge_participants_challenge_user_unique unique (challenge_id, user_id),
  constraint challenge_participants_id_user_unique unique (id, user_id),
  constraint challenge_participants_completion_consistent check (
    (status = 'completed') = (completed_at is not null)
  )
);

create table public.activities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete restrict,
  user_mission_id uuid,
  challenge_participant_id uuid,
  activity_type text not null
    check (activity_type in ('steps', 'walk', 'run', 'cycle', 'swim', 'check_in', 'custom')),
  value numeric(14, 3) not null check (value > 0),
  unit text not null check (unit in ('steps', 'km', 'miles', 'minutes', 'sessions', 'count')),
  evidence_url text,
  evidence_notes text check (evidence_notes is null or char_length(evidence_notes) <= 2000),
  verification_status text not null default 'pending'
    check (verification_status in ('pending', 'approved', 'rejected')),
  reviewer_note text check (reviewer_note is null or char_length(reviewer_note) <= 1000),
  reviewed_by uuid references public.profiles (id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint activities_exactly_one_participation check (
    (user_mission_id is not null and challenge_participant_id is null)
    or (user_mission_id is null and challenge_participant_id is not null)
  ),
  constraint activities_review_consistent check (
    (verification_status = 'pending' and reviewed_by is null and reviewed_at is null)
    or (verification_status <> 'pending' and reviewed_at is not null)
  ),
  constraint activities_mission_user_fk
    foreign key (user_mission_id, user_id)
    references public.user_missions (id, user_id) on delete restrict,
  constraint activities_challenge_participant_user_fk
    foreign key (challenge_participant_id, user_id)
    references public.challenge_participants (id, user_id) on delete restrict
);

create table public.rewards (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid references public.brands (id) on delete restrict,
  title text not null check (char_length(btrim(title)) between 2 and 160),
  description text not null check (char_length(btrim(description)) between 2 and 4000),
  image_url text,
  category text not null check (char_length(btrim(category)) between 2 and 80),
  points_required integer not null check (points_required > 0),
  stock integer check (stock is null or stock >= 0),
  status text not null default 'draft'
    check (status in ('draft', 'active', 'paused', 'out_of_stock', 'expired', 'archived')),
  expires_at timestamptz,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.redemptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete restrict,
  reward_id uuid not null references public.rewards (id) on delete restrict,
  points_spent integer not null check (points_spent > 0),
  status text not null default 'requested'
    check (status in ('requested', 'fulfilled', 'cancelled', 'refunded')),
  redemption_code text,
  fulfilled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint redemptions_id_user_unique unique (id, user_id),
  constraint redemptions_fulfillment_consistent check (
    (status = 'fulfilled') = (fulfilled_at is not null)
  )
);

create table public.point_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete restrict,
  actor_id uuid references public.profiles (id) on delete set null,
  amount bigint not null check (amount <> 0),
  transaction_type text not null
    check (transaction_type in ('earn', 'spend', 'adjustment', 'refund')),
  source text not null
    check (source in ('mission', 'challenge', 'redemption', 'admin', 'system')),
  reference_id uuid,
  activity_id uuid references public.activities (id) on delete restrict,
  redemption_id uuid references public.redemptions (id) on delete restrict,
  description text not null check (char_length(btrim(description)) between 2 and 500),
  created_at timestamptz not null default now(),
  constraint point_transactions_source_reference_check check (
    (source in ('mission', 'challenge') and transaction_type = 'earn'
      and amount > 0 and activity_id is not null and redemption_id is null
      and reference_id = activity_id)
    or (source = 'redemption' and transaction_type = 'spend'
      and amount < 0 and activity_id is null and redemption_id is not null
      and reference_id = redemption_id)
    or (source = 'redemption' and transaction_type = 'refund'
      and amount > 0 and activity_id is null and redemption_id is not null
      and reference_id = redemption_id)
    or (source in ('admin', 'system') and transaction_type = 'adjustment'
      and activity_id is null and redemption_id is null and reference_id is null)
  )
);

create unique index point_transactions_activity_once_idx
  on public.point_transactions (activity_id) where activity_id is not null;
create unique index point_transactions_redemption_spend_once_idx
  on public.point_transactions (redemption_id)
  where source = 'redemption' and transaction_type = 'spend';
create unique index point_transactions_redemption_refund_once_idx
  on public.point_transactions (redemption_id)
  where source = 'redemption' and transaction_type = 'refund';
create unique index redemptions_code_unique_idx
  on public.redemptions (redemption_code) where redemption_code is not null;

create index user_missions_mission_status_idx on public.user_missions (mission_id, status);
create index user_missions_user_status_idx on public.user_missions (user_id, status, updated_at desc);
create index challenge_participants_challenge_status_idx
  on public.challenge_participants (challenge_id, status);
create index challenge_participants_user_status_idx
  on public.challenge_participants (user_id, status, updated_at desc);
create index activities_user_created_idx on public.activities (user_id, created_at desc);
create index activities_pending_created_idx on public.activities (created_at)
  where verification_status = 'pending';
create index activities_mission_created_idx on public.activities (user_mission_id, created_at desc)
  where user_mission_id is not null;
create index activities_challenge_created_idx
  on public.activities (challenge_participant_id, created_at desc)
  where challenge_participant_id is not null;
create index rewards_status_category_idx on public.rewards (status, category);
create index rewards_brand_status_idx on public.rewards (brand_id, status) where brand_id is not null;
create index redemptions_user_created_idx on public.redemptions (user_id, created_at desc);
create index redemptions_reward_status_idx on public.redemptions (reward_id, status, created_at desc);
create index point_transactions_user_created_idx
  on public.point_transactions (user_id, created_at desc);
create index point_transactions_source_created_idx
  on public.point_transactions (source, created_at desc);

commit;
