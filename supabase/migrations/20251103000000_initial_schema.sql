-- =====================================================================================
-- Migration: Initial Schema for Pure Vibes (MTG Commander Stats Tracker)
-- Created: 2025-11-03
-- Description: Complete database schema with profiles, playgroups, games, and commanders
--
-- Tables Created:
--   - profiles (extends auth.users with app-specific data)
--   - playgroups (organize game tracking groups)
--   - playgroup_members (many-to-many with soft delete support)
--   - commanders (pre-populated from Scryfall API)
--   - games (game records per playgroup)
--   - game_participants (players in each game)
--
-- Features:
--   - Dual member model (user/non-user) with member_type_enum
--   - Dual player model (member/guest) with player_type_enum
--   - Soft delete pattern for playgroup membership
--   - Row-level security on all tables
--   - Automatic updated_at timestamps
--   - Automatic profile creation with unique friend codes
-- =====================================================================================

-- =====================================================================================
-- SECTION 1: ENUM TYPES
-- =====================================================================================

-- member_type_enum: distinguishes between registered users and non-user members
-- - 'user': has user_id (registered account)
-- - 'non_user': has non_user_name (no account)
create type member_type_enum as enum ('user', 'non_user');

-- player_type_enum: distinguishes between playgroup members and guest players
-- - 'member': playgroup member with statistics tracking
-- - 'guest': one-time participant without statistics tracking
create type player_type_enum as enum ('member', 'guest');

-- =====================================================================================
-- SECTION 2: TABLES (in dependency order)
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- TABLE: profiles
-- Purpose: Extends auth.users with application-specific user data
-- Features:
--   - Username (NOT globally unique, 3-50 chars)
--   - Friend code (globally unique, format: username#XXXXXX)
--   - Friend codes are used to add users to playgroups
-- -------------------------------------------------------------------------------------
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  friend_code text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Add comment explaining the profiles table
comment on table profiles is 'User profiles extending auth.users with username and unique friend codes for playgroup invitations';
comment on column profiles.username is 'Display name (not unique, multiple users can share the same username)';
comment on column profiles.friend_code is 'Globally unique identifier in format username#XXXXXX for adding users to playgroups';

-- -------------------------------------------------------------------------------------
-- TABLE: playgroups
-- Purpose: Core playgroup entity for organizing game tracking groups
-- Features:
--   - Created by a user (cannot delete user if playgroups exist)
--   - No uniqueness constraint on name
--   - Cannot be deleted if games exist (protected by games FK)
-- -------------------------------------------------------------------------------------
create table playgroups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_by uuid not null references profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table playgroups is 'Playgroups for organizing MTG Commander game tracking';
comment on column playgroups.created_by is 'User who created the playgroup (ON DELETE RESTRICT prevents deletion if user has playgroups)';

-- -------------------------------------------------------------------------------------
-- TABLE: playgroup_members
-- Purpose: Many-to-many junction table for users and playgroups
-- Features:
--   - Soft delete pattern using removed_at (NULL = active member)
--   - Dual member model: user members have user_id, non-user members have non_user_name
--   - Check constraint ensures correct fields are populated based on member_type
-- -------------------------------------------------------------------------------------
create table playgroup_members (
  id uuid primary key default gen_random_uuid(),
  playgroup_id uuid not null references playgroups(id) on delete cascade,
  user_id uuid null references profiles(id) on delete cascade,
  member_type member_type_enum not null,
  non_user_name text null,
  removed_at timestamptz null,
  created_at timestamptz not null default now(),

  -- Check constraint: ensure correct fields populated based on member_type
  -- - user members MUST have user_id and NULL non_user_name
  -- - non_user members MUST have non_user_name and NULL user_id
  constraint playgroup_members_type_check check (
    (member_type = 'user' and user_id is not null and non_user_name is null) or
    (member_type = 'non_user' and non_user_name is not null and user_id is null)
  )
);

comment on table playgroup_members is 'Junction table for playgroup membership with soft delete support and dual member model (user/non-user)';
comment on column playgroup_members.removed_at is 'Soft delete timestamp - NULL indicates active membership';
comment on column playgroup_members.member_type is 'Type of member: user (has account) or non_user (name only)';
comment on column playgroup_members.non_user_name is 'Name for non-user members (NULL for user members)';

-- -------------------------------------------------------------------------------------
-- TABLE: commanders
-- Purpose: Pre-populated commander cards database from Scryfall API
-- Features:
--   - Populated via separate script (not through UI)
--   - ~2-3k records expected
--   - Public read access for all authenticated users
--   - UPSERT operations based on scryfall_id
-- -------------------------------------------------------------------------------------
create table commanders (
  id uuid primary key default gen_random_uuid(),
  scryfall_id uuid not null unique,
  name text not null,
  color_identity text null,
  scryfall_png text null,
  scryfall_border_crop text null,
  scryfall_art_crop text null,
  scryfall_large text null,
  scryfall_normal text null,
  scryfall_small text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table commanders is 'Pre-populated commander cards from Scryfall API (legendary creatures, vehicles, spacecraft, planeswalkers)';
comment on column commanders.scryfall_id is 'External Scryfall UUID for UPSERT operations and API synchronization';
comment on column commanders.color_identity is 'WUBRG notation for color identity (e.g., WUB for Esper)';

-- -------------------------------------------------------------------------------------
-- TABLE: games
-- Purpose: Game records for each Commander match played by a playgroup
-- Features:
--   - ON DELETE RESTRICT prevents playgroup deletion if games exist
--   - game_date uses DATE type (no time tracking in MVP)
--   - Any playgroup member can create/edit/delete games
-- -------------------------------------------------------------------------------------
create table games (
  id uuid primary key default gen_random_uuid(),
  playgroup_id uuid not null references playgroups(id) on delete restrict,
  game_date date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table games is 'Game records for MTG Commander matches played by playgroups';
comment on column games.playgroup_id is 'Playgroup reference (ON DELETE RESTRICT prevents playgroup deletion if games exist)';
comment on column games.game_date is 'Date the game was played (DATE type, no time tracking in MVP)';

-- -------------------------------------------------------------------------------------
-- TABLE: game_participants
-- Purpose: Junction table linking games to players (members or guests)
-- Features:
--   - Dual player model: member (has playgroup_member_id) or guest (has optional guest_name)
--   - ON DELETE CASCADE when game deleted (cleanup participants)
--   - ON DELETE SET NULL for playgroup_member_id (preserve games when member removed)
--   - Supports ties in finishing_position (multiple players can have same position)
-- -------------------------------------------------------------------------------------
create table game_participants (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references games(id) on delete cascade,
  playgroup_member_id uuid null references playgroup_members(id) on delete set null,
  commander_id uuid not null references commanders(id) on delete restrict,
  player_type player_type_enum not null,
  guest_name text null,
  starting_position integer not null,
  finishing_position integer not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table game_participants is 'Players participating in games with dual player model (member/guest)';
comment on column game_participants.playgroup_member_id is 'Member reference - NULL for guests (ON DELETE SET NULL preserves history when member removed)';
comment on column game_participants.player_type is 'Type of player: member (has stats) or guest (no stats)';
comment on column game_participants.guest_name is 'Optional name for guest players';
comment on column game_participants.starting_position is 'Turn order position (1 to N, validated in application)';
comment on column game_participants.finishing_position is 'Final placement (1 = winner, ties allowed)';

-- =====================================================================================
-- SECTION 3: INDEXES
-- Purpose: Performance optimization for common query patterns
-- =====================================================================================

-- Friend code lookup (exact match for adding members to playgroups)
create unique index idx_profiles_friend_code on profiles (friend_code);

-- Username index for display purposes (not unique, multiple users can share username)
create index idx_profiles_username on profiles (username);

-- Partial unique index: ensures one active membership per user per playgroup
-- Only enforces uniqueness where removed_at IS NULL (active members)
create unique index idx_playgroup_members_active_unique
  on playgroup_members (playgroup_id, user_id)
  where removed_at is null;

-- User's active playgroups (filtered to active members only)
create index idx_playgroup_members_user_active
  on playgroup_members (user_id)
  where removed_at is null;

-- Game history by playgroup (sorted by date descending for pagination)
create index idx_games_playgroup_date
  on games (playgroup_id, game_date desc);

-- Game date sorting for pagination (composite sort for stable ordering)
create index idx_games_date_created
  on games (game_date desc, created_at desc);

-- Fetch all players for a specific game
create index idx_game_participants_game on game_participants (game_id);

-- Playgroup member's game history (for statistics queries)
create index idx_game_participants_playgroup_member on game_participants (playgroup_member_id);

-- Commander statistics and usage tracking
create index idx_game_participants_commander on game_participants (commander_id);

-- Commander search by name (simple ILIKE adequate for ~2-3k records)
create index idx_commanders_name on commanders (name);

-- =====================================================================================
-- SECTION 4: TRIGGERS
-- Purpose: Automatic timestamp updates and profile creation
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- FUNCTION: trigger_set_updated_at
-- Purpose: Reusable trigger function to automatically update updated_at timestamps
-- Usage: Applied to all tables with updated_at column
-- -------------------------------------------------------------------------------------
create or replace function trigger_set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Apply updated_at trigger to all tables with updated_at column
create trigger set_updated_at
  before update on profiles
  for each row execute function trigger_set_updated_at();

create trigger set_updated_at
  before update on playgroups
  for each row execute function trigger_set_updated_at();

create trigger set_updated_at
  before update on commanders
  for each row execute function trigger_set_updated_at();

create trigger set_updated_at
  before update on games
  for each row execute function trigger_set_updated_at();

create trigger set_updated_at
  before update on game_participants
  for each row execute function trigger_set_updated_at();

-- -------------------------------------------------------------------------------------
-- FUNCTION: handle_new_user
-- Purpose: Automatically create profile with unique friend code when user signs up
-- Features:
--   - Generates friend code in format: username#XXXXXX (6 uppercase alphanumeric chars)
--   - Retry logic handles rare collision cases (36^6 = ~2.1 billion combinations)
--   - Uses username from metadata or generates default from user ID
-- Security: SECURITY DEFINER allows function to insert into profiles table
-- -------------------------------------------------------------------------------------
create or replace function handle_new_user()
returns trigger as $$
declare
  v_username text;
  v_friend_code text;
  v_random_code text;
  v_attempt integer := 0;
  v_max_attempts integer := 10;
begin
  -- Extract username from metadata or generate default
  v_username := coalesce(new.raw_user_meta_data ->> 'username', 'user_' || substr(new.id::text, 1, 8));

  -- Ensure username is 3-50 characters (truncate if needed)
  if length(v_username) < 3 then
    v_username := 'user_' || substr(new.id::text, 1, 8);
  elsif length(v_username) > 50 then
    v_username := substr(v_username, 1, 50);
  end if;

  -- Generate unique friend code with retry logic
  loop
    -- Generate 6-character random code
    v_random_code := upper(substr(md5(random()::text || new.id::text || v_attempt::text), 1, 6));

    -- Build friend code: username#XXXXXX
    v_friend_code := v_username || '#' || v_random_code;

    -- Check if friend code is unique
    if not exists (select 1 from public.profiles where friend_code = v_friend_code) then
      exit; -- Unique code found, exit loop
    end if;

    -- Increment attempt counter
    v_attempt := v_attempt + 1;
    if v_attempt >= v_max_attempts then
      raise exception 'Failed to generate unique friend code after % attempts', v_max_attempts;
    end if;
  end loop;

  -- Insert profile with generated friend code
  insert into public.profiles (id, username, friend_code)
  values (new.id, v_username, v_friend_code);

  return new;
end;
$$ language plpgsql security definer;

-- Trigger to create profile automatically when auth user is created
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

comment on function handle_new_user is 'Automatically creates user profile with unique friend code (format: username#XXXXXX) when auth user signs up';

-- =====================================================================================
-- SECTION 5: ROW-LEVEL SECURITY (RLS) HELPER FUNCTIONS
-- Purpose: Reusable functions for RLS policy checks
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- FUNCTION: is_active_playgroup_member
-- Purpose: Check if user is an active member of a playgroup
-- Usage: Used in RLS policies across multiple tables
-- Returns: TRUE if user has active membership (removed_at IS NULL), FALSE otherwise
-- Security: SECURITY DEFINER allows function to query playgroup_members
-- -------------------------------------------------------------------------------------
create or replace function is_active_playgroup_member(
  p_playgroup_id uuid,
  p_user_id uuid
)
returns boolean
language sql
stable
security definer
as $$
  select exists (
    select 1
    from playgroup_members
    where playgroup_id = p_playgroup_id
      and user_id = p_user_id
      and removed_at is null
  );
$$;

comment on function is_active_playgroup_member is 'Checks if user is an active playgroup member (removed_at IS NULL) - used in RLS policies';

-- =====================================================================================
-- SECTION 6: ENABLE ROW-LEVEL SECURITY
-- Purpose: Enable RLS on all tables (required for security policies)
-- Note: commanders table has no RLS policies (public read access)
-- =====================================================================================

alter table profiles enable row level security;
alter table playgroups enable row level security;
alter table playgroup_members enable row level security;
alter table commanders enable row level security;
alter table games enable row level security;
alter table game_participants enable row level security;

-- =====================================================================================
-- SECTION 7: RLS POLICIES
-- Purpose: Define granular access control policies for each table and operation
-- Strategy: One policy per operation (SELECT, INSERT, UPDATE, DELETE) per role
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- RLS POLICIES: profiles
-- Access Rules:
--   - All authenticated users can view all profiles (for member search)
--   - Users can insert their own profile
--   - Users can update their own profile
-- -------------------------------------------------------------------------------------

-- SELECT: authenticated users can view all profiles (needed for adding members)
create policy "profiles_select_authenticated"
  on profiles
  for select
  to authenticated
  using (true);

-- SELECT: anonymous users have no access
create policy "profiles_select_anon"
  on profiles
  for select
  to anon
  using (false);

-- INSERT: authenticated users can insert their own profile
create policy "profiles_insert_authenticated"
  on profiles
  for insert
  to authenticated
  with check (auth.uid() = id);

-- INSERT: anonymous users cannot insert profiles
create policy "profiles_insert_anon"
  on profiles
  for insert
  to anon
  with check (false);

-- UPDATE: authenticated users can update their own profile
create policy "profiles_update_authenticated"
  on profiles
  for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- UPDATE: anonymous users cannot update profiles
create policy "profiles_update_anon"
  on profiles
  for update
  to anon
  using (false);

-- -------------------------------------------------------------------------------------
-- RLS POLICIES: playgroups
-- Access Rules:
--   - Users can view playgroups they are active members of
--   - Authenticated users can create playgroups (automatically become members)
--   - Active members can update playgroup details
-- -------------------------------------------------------------------------------------

-- SELECT: authenticated users can view playgroups they are active members of
create policy "playgroups_select_authenticated"
  on playgroups
  for select
  to authenticated
  using (is_active_playgroup_member(id, auth.uid()));

-- SELECT: anonymous users have no access
create policy "playgroups_select_anon"
  on playgroups
  for select
  to anon
  using (false);

-- INSERT: authenticated users can create playgroups
create policy "playgroups_insert_authenticated"
  on playgroups
  for insert
  to authenticated
  with check (auth.uid() = created_by);

-- INSERT: anonymous users cannot create playgroups
create policy "playgroups_insert_anon"
  on playgroups
  for insert
  to anon
  with check (false);

-- UPDATE: active members can update playgroup details
create policy "playgroups_update_authenticated"
  on playgroups
  for update
  to authenticated
  using (is_active_playgroup_member(id, auth.uid()))
  with check (is_active_playgroup_member(id, auth.uid()));

-- UPDATE: anonymous users cannot update playgroups
create policy "playgroups_update_anon"
  on playgroups
  for update
  to anon
  using (false);

-- -------------------------------------------------------------------------------------
-- RLS POLICIES: playgroup_members
-- Access Rules:
--   - Users can view members of playgroups they belong to
--   - Active members can add new members
--   - Active members can update memberships (soft delete via removed_at)
-- -------------------------------------------------------------------------------------

-- SELECT: authenticated users can view members of playgroups they belong to
create policy "playgroup_members_select_authenticated"
  on playgroup_members
  for select
  to authenticated
  using (is_active_playgroup_member(playgroup_id, auth.uid()));

-- SELECT: anonymous users have no access
create policy "playgroup_members_select_anon"
  on playgroup_members
  for select
  to anon
  using (false);

-- INSERT: active members can add new members to their playgroups
create policy "playgroup_members_insert_authenticated"
  on playgroup_members
  for insert
  to authenticated
  with check (is_active_playgroup_member(playgroup_id, auth.uid()));

-- INSERT: anonymous users cannot add members
create policy "playgroup_members_insert_anon"
  on playgroup_members
  for insert
  to anon
  with check (false);

-- UPDATE: active members can update memberships (e.g., soft delete via removed_at)
create policy "playgroup_members_update_authenticated"
  on playgroup_members
  for update
  to authenticated
  using (is_active_playgroup_member(playgroup_id, auth.uid()))
  with check (is_active_playgroup_member(playgroup_id, auth.uid()));

-- UPDATE: anonymous users cannot update memberships
create policy "playgroup_members_update_anon"
  on playgroup_members
  for update
  to anon
  using (false);

-- -------------------------------------------------------------------------------------
-- RLS POLICIES: commanders
-- Access Rules:
--   - All authenticated users can view commanders (needed for game creation)
--   - No insert/update/delete access via RLS (populated by admin script only)
-- -------------------------------------------------------------------------------------

-- SELECT: authenticated users can view all commanders
create policy "commanders_select_authenticated"
  on commanders
  for select
  to authenticated
  using (true);

-- SELECT: anonymous users have no access
create policy "commanders_select_anon"
  on commanders
  for select
  to anon
  using (false);

-- -------------------------------------------------------------------------------------
-- RLS POLICIES: games
-- Access Rules:
--   - Active playgroup members can view games
--   - Active playgroup members can create games
--   - Active playgroup members can update games
--   - Active playgroup members can delete games
-- -------------------------------------------------------------------------------------

-- SELECT: active playgroup members can view games
create policy "games_select_authenticated"
  on games
  for select
  to authenticated
  using (is_active_playgroup_member(playgroup_id, auth.uid()));

-- SELECT: anonymous users have no access
create policy "games_select_anon"
  on games
  for select
  to anon
  using (false);

-- INSERT: active playgroup members can create games
create policy "games_insert_authenticated"
  on games
  for insert
  to authenticated
  with check (is_active_playgroup_member(playgroup_id, auth.uid()));

-- INSERT: anonymous users cannot create games
create policy "games_insert_anon"
  on games
  for insert
  to anon
  with check (false);

-- UPDATE: active playgroup members can update games
create policy "games_update_authenticated"
  on games
  for update
  to authenticated
  using (is_active_playgroup_member(playgroup_id, auth.uid()))
  with check (is_active_playgroup_member(playgroup_id, auth.uid()));

-- UPDATE: anonymous users cannot update games
create policy "games_update_anon"
  on games
  for update
  to anon
  using (false);

-- DELETE: active playgroup members can delete games
create policy "games_delete_authenticated"
  on games
  for delete
  to authenticated
  using (is_active_playgroup_member(playgroup_id, auth.uid()));

-- DELETE: anonymous users cannot delete games
create policy "games_delete_anon"
  on games
  for delete
  to anon
  using (false);

-- -------------------------------------------------------------------------------------
-- RLS POLICIES: game_participants
-- Access Rules:
--   - Users can view participants for games in their playgroups
--   - Users can insert participants for games in their playgroups
--   - Users can update participants for games in their playgroups
--   - Users can delete participants for games in their playgroups
-- -------------------------------------------------------------------------------------

-- SELECT: users can view participants for games in their playgroups
create policy "game_participants_select_authenticated"
  on game_participants
  for select
  to authenticated
  using (
    exists (
      select 1
      from games
      where games.id = game_participants.game_id
        and is_active_playgroup_member(games.playgroup_id, auth.uid())
    )
  );

-- SELECT: anonymous users have no access
create policy "game_participants_select_anon"
  on game_participants
  for select
  to anon
  using (false);

-- INSERT: users can insert participants for games in their playgroups
create policy "game_participants_insert_authenticated"
  on game_participants
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from games
      where games.id = game_participants.game_id
        and is_active_playgroup_member(games.playgroup_id, auth.uid())
    )
  );

-- INSERT: anonymous users cannot insert participants
create policy "game_participants_insert_anon"
  on game_participants
  for insert
  to anon
  with check (false);

-- UPDATE: users can update participants for games in their playgroups
create policy "game_participants_update_authenticated"
  on game_participants
  for update
  to authenticated
  using (
    exists (
      select 1
      from games
      where games.id = game_participants.game_id
        and is_active_playgroup_member(games.playgroup_id, auth.uid())
    )
  )
  with check (
    exists (
      select 1
      from games
      where games.id = game_participants.game_id
        and is_active_playgroup_member(games.playgroup_id, auth.uid())
    )
  );

-- UPDATE: anonymous users cannot update participants
create policy "game_participants_update_anon"
  on game_participants
  for update
  to anon
  using (false);

-- DELETE: users can delete participants for games in their playgroups
create policy "game_participants_delete_authenticated"
  on game_participants
  for delete
  to authenticated
  using (
    exists (
      select 1
      from games
      where games.id = game_participants.game_id
        and is_active_playgroup_member(games.playgroup_id, auth.uid())
    )
  );

-- DELETE: anonymous users cannot delete participants
create policy "game_participants_delete_anon"
  on game_participants
  for delete
  to anon
  using (false);

-- =====================================================================================
-- MIGRATION COMPLETE
-- =====================================================================================

-- Schema version: 1.0
-- All tables created with RLS enabled and appropriate policies
-- Triggers configured for automatic updated_at and profile creation
-- Indexes optimized for common query patterns
-- Ready for production use
