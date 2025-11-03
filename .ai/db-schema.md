# Database Schema - MTG Commander Stats Tracker

## Overview

PostgreSQL database schema for Pure Vibes (MTG Commander Stats Tracker) using Supabase as the database provider. The
schema supports playgroup management, game tracking with dual member model (user/non-user) and dual player model (member/guest), commander statistics, and soft-delete patterns for playgroup membership preservation.

---

## 1. Tables

### 1.1 profiles

Extends Supabase `auth.users` with application-specific user data.

| Column      | Type        | Constraints             | Description                                            |
|-------------|-------------|-------------------------|--------------------------------------------------------|
| id          | UUID        | PRIMARY KEY             | References auth.users(id) ON DELETE CASCADE            |
| username    | TEXT        | NOT NULL                | Display name (not unique, 3-50 chars alphanumeric)     |
| friend_code | TEXT        | NOT NULL, UNIQUE        | Unique identifier for adding members (username#XXXXXX) |
| created_at  | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Record creation timestamp                              |
| updated_at  | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Last update timestamp                                  |

**Notes:**

- `id` must match Supabase auth.users(id)
- Username is NOT globally unique (multiple users can have same username)
- Friend code is globally unique in format: `username#XXXXXX` where XXXXXX is 6 uppercase alphanumeric characters (A-Z, 0-9)
- Friend code is used to add users to playgroups (replaces username search)
- Friend code is permanent for MVP (no regeneration)

---

### 1.2 playgroups

Core playgroup entity for organizing game tracking groups.

| Column     | Type        | Constraints                            | Description                               |
|------------|-------------|----------------------------------------|-------------------------------------------|
| id         | UUID        | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique playgroup identifier               |
| name       | TEXT        | NOT NULL                               | Playgroup name (no uniqueness constraint) |
| created_by | UUID        | NOT NULL, REFERENCES profiles(id)      | User who created the playgroup            |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW()                | Record creation timestamp                 |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW()                | Last update timestamp                     |

**Notes:**

- Playgroup names can be duplicated (no unique constraint)
- No description field in MVP
- Cannot be deleted if games exist (ON DELETE RESTRICT from games FK)

---

### 1.3 playgroup_members

Junction table for users ↔ playgroups many-to-many relationship with soft delete support.

| Column        | Type             | Constraints                                           | Description                                  |
|---------------|------------------|-------------------------------------------------------|----------------------------------------------|
| id            | UUID             | PRIMARY KEY, DEFAULT gen_random_uuid()                | Unique membership record identifier          |
| playgroup_id  | UUID             | NOT NULL, REFERENCES playgroups(id) ON DELETE CASCADE | Playgroup reference                          |
| user_id       | UUID             | NULL, REFERENCES profiles(id) ON DELETE CASCADE       | User reference                               |
| member_type   | member_type_enum | NOT NULL                                              | Enum: 'user' or 'non_user'                   |
| non_user_name | TEXT             | NULL                                                  | Non-user member name (NULL for users)        |
| removed_at    | TIMESTAMPTZ      | NULL                                                  | Soft delete timestamp (NULL = active member) |
| created_at    | TIMESTAMPTZ      | NOT NULL, DEFAULT NOW()                               | Record creation timestamp                    |

**Check Constraints:**

```sql
CHECK (
  (member_type = 'user' AND user_id IS NOT NULL AND non_user_name IS NULL) OR
  (member_type = 'non_user' AND non_user_name IS NOT NULL AND user_id IS NULL)
)

```

**Notes:**

- Dual member model: members have user_id, non_users have non_user_name
- Soft delete pattern: removed_at IS NULL indicates active membership
- Removed members lose access but historical game data preserved
- Re-adding a member clears removed_at timestamp
- Partial unique constraint ensures one active membership per user per playgroup

---

### 1.4 commanders

Pre-populated commander cards database from Scryfall bulk data API.

| Column               | Type        | Constraints                            | Description                            |
|----------------------|-------------|----------------------------------------|----------------------------------------|
| id                   | UUID        | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique commander identifier            |
| scryfall_id          | UUID        | NOT NULL, UNIQUE                       | Scryfall card UUID (external ID)       |
| name                 | TEXT        | NOT NULL                               | Commander card name                    |
| color_identity       | TEXT        | NULL                                   | WUBRG notation (e.g., "WUB" for Esper) |
| scryfall_png         | TEXT        | NULL                                   | Scryfall png image URL                 |
| scryfall_border_crop | TEXT        | NULL                                   | Scryfall border crop image URL         |
| scryfall_art_crop    | TEXT        | NULL                                   | Scryfall art crop image URL            |
| scryfall_large       | TEXT        | NULL                                   | Scryfall large image URL               |
| scryfall_normal      | TEXT        | NULL                                   | Scryfall normal image URL              |
| scryfall_small       | TEXT        | NULL                                   | Scryfall small image URL               |
| created_at           | TIMESTAMPTZ | NOT NULL, DEFAULT NOW()                | Record creation timestamp              |
| updated_at           | TIMESTAMPTZ | NOT NULL, DEFAULT NOW()                | Last update timestamp                  |

**Notes:**

- Populated via separate script from Scryfall API
- Includes legendary creatures, vehicles, spacecraft, and planeswalkers with "can be your commander" text
- ~2-3k records expected
- Public read access for all authenticated users (no RLS)
- UPSERT operations based on scryfall_id

---

### 1.5 games

Game records for each Commander match played by a playgroup.

| Column       | Type        | Constraints                                            | Description               |
|--------------|-------------|--------------------------------------------------------|---------------------------|
| id           | UUID        | PRIMARY KEY, DEFAULT gen_random_uuid()                 | Unique game identifier    |
| playgroup_id | UUID        | NOT NULL, REFERENCES playgroups(id) ON DELETE RESTRICT | Playgroup reference       |
| game_date    | DATE        | NOT NULL                                               | Date game was played      |
| created_at   | TIMESTAMPTZ | NOT NULL, DEFAULT NOW()                                | Record creation timestamp |
| updated_at   | TIMESTAMPTZ | NOT NULL, DEFAULT NOW()                                | Last update timestamp     |

**Notes:**

- ON DELETE RESTRICT prevents playgroup deletion if games exist
- game_date uses DATE type (no time tracking in MVP)
- Any playgroup member can create/edit/delete games

---

### 1.6 game_participants

Junction table linking games to players

| Column              | Type             | Constraints                                               | Description                                |
|---------------------|------------------|-----------------------------------------------------------|--------------------------------------------|
| id                  | UUID             | PRIMARY KEY, DEFAULT gen_random_uuid()                    | Unique game player record identifier       |
| game_id             | UUID             | NOT NULL, REFERENCES games(id) ON DELETE CASCADE          | Game reference                             |
| playgroup_member_id | UUID             | NULL, REFERENCES playgroup_members(id) ON DELETE SET NULL | Member reference (NULL for guests)         |
| commander_id        | UUID             | NOT NULL, REFERENCES commanders(id)                       | Commander played                           |
| player_type         | player_type_enum | NOT NULL                                                  | Enum: 'member' or 'guest'                  |
| guest_name          | TEXT             | NULL                                                      | Guest player name (optional)               |
| starting_position   | INTEGER          | NOT NULL                                                  | Turn order position (1 to N)               |
| finishing_position  | INTEGER          | NOT NULL                                                  | Final placement (1 = winner, ties allowed) |
| created_at          | TIMESTAMPTZ      | NOT NULL, DEFAULT NOW()                                   | Record creation timestamp                  |
| updated_at          | TIMESTAMPTZ      | NOT NULL, DEFAULT NOW()                                   | Last update timestamp                      |

**Notes:**

- Dual player mode: can either be a playgroup member or a guest
- ON DELETE CASCADE when game deleted (cleanup game players)
- ON DELETE SET NULL for playgroup_member_id (preserve games when member removed)

---

## 2. ENUM Types

### 2.1 member_type_enum

```sql
CREATE
TYPE member_type_enum AS ENUM ('user', 'non_user');
```

**Values:**

- `'user'`: Registered user (has user_id)
- `'non_user'`: Non-user member (has non_user_name)

### 2.2 player_type_enum

```sql
CREATE
TYPE player_type_enum AS ENUM ('member', 'guest');
```

**Values:**

- `'member'`: Playgroup member (has `playgroup_member_id`, has statistics summarised on dashboard)
- `'guest'`: Non-member participant (Has optional `guest_name`, no statistics summary on dashboard)

---

## 3. Indexes

### 3.1 Performance Indexes

```sql
-- Friend code lookup (replaces username search, used for adding members)
CREATE UNIQUE INDEX idx_profiles_friend_code ON profiles (friend_code);

-- Username index for display purposes (no longer unique)
CREATE INDEX idx_profiles_username ON profiles (username);

-- Playgroup membership lookup (partial unique for active members only)
CREATE UNIQUE INDEX idx_playgroup_members_active_unique
    ON playgroup_members (playgroup_id, user_id)
    WHERE removed_at IS NULL;

-- User's active playgroups
CREATE INDEX idx_playgroup_members_user_active
    ON playgroup_members (user_id)
    WHERE removed_at IS NULL;

-- Foreign key index for playgroup_members.playgroup_id
CREATE INDEX idx_playgroup_members_playgroup_id
    ON playgroup_members (playgroup_id);

-- Foreign key index for playgroups.created_by
CREATE INDEX idx_playgroups_created_by
    ON playgroups (created_by);

-- Foreign key index for games.playgroup_id
CREATE INDEX idx_games_playgroup_id
    ON games (playgroup_id);

-- Game history by playgroup (composite index)
CREATE INDEX idx_games_playgroup_date
    ON games (playgroup_id, game_date DESC);

-- Game date sorting for pagination
CREATE INDEX idx_games_date_created
    ON games (game_date DESC, created_at DESC);

-- Fetch players for a game
CREATE INDEX idx_game_participants_game ON game_participants (game_id);

-- Playgroup member's game history
CREATE INDEX idx_game_participants_playgroup_member ON game_participants (playgroup_member_id);

-- Commander statistics
CREATE INDEX idx_game_participants_commander ON game_participants (commander_id);

-- Commander search
CREATE INDEX idx_commanders_name ON commanders (name);
```

### 3.2 Index Strategy Notes

- **Partial unique index** on playgroup_members ensures one active membership per user per playgroup
- **Composite index** on games(playgroup_id, game_date DESC) optimizes game history queries
- **Partial indexes** on removed_at improve performance by excluding soft-deleted playgroup members
- **Foreign key indexes** added for all FK constraints to improve JOIN performance and constraint checking
- **Simple ILIKE search** on commanders.name adequate for ~2-3k records (no full-text search in MVP)

---

## 4. Row-Level Security (RLS)

### 4.1 RLS Helper Function

```sql
CREATE
OR REPLACE
FUNCTION is_active_playgroup_member(
  p_playgroup_id UUID,
  p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
SELECT EXISTS (SELECT 1
               FROM public.playgroup_members
               WHERE playgroup_id = p_playgroup_id
                 AND user_id = p_user_id
                 AND removed_at IS NULL);
$$;
```

**Purpose:** Reusable function for checking if user is an active playgroup member (used in RLS policies).

**Security:** `SET search_path = ''` prevents search path injection attacks.

---

### 4.2 RLS Policies by Table

#### profiles

```sql
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Users can view all profiles (for member search)
CREATE
POLICY "profiles_select_all" ON profiles
  FOR
SELECT
    USING ((select auth.uid()) IS NOT NULL);

-- Users can insert their own profile
CREATE
POLICY "profiles_insert_own" ON profiles
  FOR INSERT
WITH CHECK ((select auth.uid()) = id);

-- Users can update their own profile
CREATE
POLICY "profiles_update_own" ON profiles
  FOR
UPDATE
    USING ((select auth.uid()) = id)
WITH CHECK ((select auth.uid()) = id);
```

---

#### playgroups

```sql
ALTER TABLE playgroups ENABLE ROW LEVEL SECURITY;

-- Users can view playgroups they are active members of
CREATE
POLICY "playgroups_select_member" ON playgroups
  FOR
SELECT
    USING (
    is_active_playgroup_member(id, (select auth.uid()))
    );

-- Authenticated users can create playgroups
CREATE
POLICY "playgroups_insert_authenticated" ON playgroups
  FOR INSERT
WITH CHECK ((select auth.uid()) = created_by);

-- Active members can update playgroup details
CREATE
POLICY "playgroups_update_member" ON playgroups
  FOR
UPDATE
    USING (
    is_active_playgroup_member(id, (select auth.uid()))
    )
WITH CHECK (
    is_active_playgroup_member(id, (select auth.uid()))
    );
```

---

#### playgroup_members

```sql
ALTER TABLE playgroup_members ENABLE ROW LEVEL SECURITY;

-- Users can view members of playgroups they belong to
CREATE
POLICY "playgroup_members_select_member" ON playgroup_members
  FOR
SELECT
    USING (
    is_active_playgroup_member(playgroup_id, (select auth.uid()))
    );

-- Active members can add new members
CREATE
POLICY "playgroup_members_insert_member" ON playgroup_members
  FOR INSERT
WITH CHECK (
    is_active_playgroup_member(playgroup_id, (select auth.uid()))
  );

-- Active members can update (soft delete) memberships
CREATE
POLICY "playgroup_members_update_member" ON playgroup_members
  FOR
UPDATE
    USING (
    is_active_playgroup_member(playgroup_id, (select auth.uid()))
    )
WITH CHECK (
    is_active_playgroup_member(playgroup_id, (select auth.uid()))
    );
```

---

#### commanders

```sql
-- No RLS on commanders table - public read access for authenticated users
-- Populated by admin script only
```

---

#### games

```sql
ALTER TABLE games ENABLE ROW LEVEL SECURITY;

-- Active playgroup members can view games
CREATE
POLICY "games_select_member" ON games
  FOR
SELECT
    USING (
    is_active_playgroup_member(playgroup_id, (select auth.uid()))
    );

-- Active playgroup members can create games
CREATE
POLICY "games_insert_member" ON games
  FOR INSERT
WITH CHECK (
    is_active_playgroup_member(playgroup_id, (select auth.uid()))
  );

-- Active playgroup members can update games
CREATE
POLICY "games_update_member" ON games
  FOR
UPDATE
    USING (
    is_active_playgroup_member(playgroup_id, (select auth.uid()))
    )
WITH CHECK (
    is_active_playgroup_member(playgroup_id, (select auth.uid()))
    );

-- Active playgroup members can delete games
CREATE
POLICY "games_delete_member" ON games
  FOR DELETE
USING (
    is_active_playgroup_member(playgroup_id, (select auth.uid()))
  );
```

---

#### game_participants

```sql
ALTER TABLE game_participants ENABLE ROW LEVEL SECURITY;

-- Users can view game players for games in their playgroups
CREATE
POLICY "game_participants_select_member" ON game_participants
  FOR
SELECT
    USING (
    EXISTS (
    SELECT 1
    FROM games
    WHERE games.id = game_participants.game_id
    AND is_active_playgroup_member(games.playgroup_id, (select auth.uid()))
    )
    );

-- Users can insert game players for games in their playgroups
CREATE
POLICY "game_participants_insert_member" ON game_participants
  FOR INSERT
WITH CHECK (
    EXISTS (
      SELECT 1
      FROM games
      WHERE games.id = game_participants.game_id
        AND is_active_playgroup_member(games.playgroup_id, (select auth.uid()))
    )
  );

-- Users can update game players for games in their playgroups
CREATE
POLICY "game_participants_update_member" ON game_participants
  FOR
UPDATE
    USING (
    EXISTS (
    SELECT 1
    FROM games
    WHERE games.id = game_participants.game_id
    AND is_active_playgroup_member(games.playgroup_id, (select auth.uid()))
    )
    )
WITH CHECK (
    EXISTS (
    SELECT 1
    FROM games
    WHERE games.id = game_participants.game_id
    AND is_active_playgroup_member(games.playgroup_id, (select auth.uid()))
    )
    );

-- Users can delete game players for games in their playgroups
CREATE
POLICY "game_participants_delete_member" ON game_participants
  FOR DELETE
USING (
    EXISTS (
      SELECT 1
      FROM games
      WHERE games.id = game_participants.game_id
        AND is_active_playgroup_member(games.playgroup_id, (select auth.uid()))
    )
  );
```

---

## 5. Relationships

### 5.1 One-to-One

- `profiles.id` → `auth.users.id` (extends Supabase auth)

### 5.2 One-to-Many

- `profiles` → `playgroups` (created_by: one user creates many playgroups)
- `playgroups` → `games` (one playgroup has many games)
- `games` → `game_participants` (one game has many players)
- `commanders` → `game_participants` (one commander used in many games)
- `playgroup_members` → `game_participants` (one member plays many games)

### 5.3 Many-to-Many

- `profiles` ↔ `playgroups` via `playgroup_members` (with soft delete support)
- `playgroup_members` ↔ `games` via `game_participants` (members and guests participate in games)

---

## 6. Foreign Key Cascade Behaviors

| Child Table            | Parent Table       | Relationship        | ON DELETE Behavior | Rationale                                                 |
|------------------------|--------------------|---------------------|--------------------|-----------------------------------------------------------|
| profiles               | auth.users         | id                  | CASCADE            | Remove user data when auth account deleted                |
| playgroups             | profiles           | created_by          | RESTRICT           | Prevent creator deletion with active playgroups           |
| playgroup_members      | playgroups         | playgroup_id        | CASCADE            | Remove memberships when playgroup deleted                 |
| playgroup_members      | profiles           | user_id             | CASCADE            | Convert user members to non-user members                  |
| games                  | playgroups         | playgroup_id        | RESTRICT           | Prevent playgroup deletion if games exist                 |
| game_participants      | games              | game_id             | CASCADE            | Remove participants when game deleted (hard delete)       |
| game_participants      | playgroup_members  | playgroup_member_id | SET NULL           | Preserve game history when member removed                 |
| game_participants      | commanders         | commander_id        | RESTRICT           | Prevent commander deletion if used in games               |

---

## 7. Data Validation

### 7.1 Database-Level Validation

- **UNIQUE constraints**: profiles.friend_code, commanders.scryfall_id
- **NOT NULL constraints**: All required fields marked NOT NULL
- **CHECK constraints**: player_type validation ensures member has user_id OR guest has guest_name
- **ENUM constraints**: player_type limited to 'member' or 'guest'
- **FK constraints**: Referential integrity enforced

### 7.2 Application-Level Validation (Not in DB)

- Username format (3-50 characters, alphanumeric, NOT unique)
- Friend code format: `^[a-zA-Z0-9]{3,50}#[A-Z0-9]{6}$` (username#XXXXXX where XXXXXX is 6 uppercase alphanumeric)
- Playgroup name length (3-50 characters)
- Guest name length (2-30 characters)
- Player count per game (2-10 players)
- Starting position uniqueness (1 to N, each used once)
- Finishing position validity (1 to N, ties allowed)
- Game date range (not in future, reasonable past dates)

---

## 8. Special Cases & Edge Case Handling

### 8.1 Soft Deletes

- **Playgroup members**: `removed_at IS NULL` indicates active membership
    - Queries must filter: `WHERE removed_at IS NULL`
    - Soft delete: `UPDATE playgroup_members SET removed_at = NOW() WHERE ...`
    - Re-add member: `UPDATE playgroup_members SET removed_at = NULL WHERE ...`

### 8.2 Non-user members

- Member name stored in `playgroup_members.non_user_name`
- Included in playgroup statistics

### 8.2 Guest Players

- Guest name stored in `game_participants.guest_name`
- Not included in playgroup statistics

### 8.3 Ties in Finishing Positions

- Multiple players can have same `finishing_position` value
- Position 1 = winner(s)
- Example: 4-player game with tie for 3rd place: positions [1, 3, 3, 4]
- Statistics calculate win rate based on `finishing_position = 1`

### 8.4 Username Changes

- Always display current username from `profiles.username`
- No snapshot field in `game_participants` (keeps schema simple)
- Historical games reflect updated usernames

### 8.5 User Account Deletion

- Application converts member records to non-users before deletion:
    1. Update `playgroup_members`: SET `member_type = 'non_user'`, `non_user_name = <preserved username>`
    2. Allow `user_id` to SET NULL
    3. Deleted user shown as non_user

---

## 9. Query Patterns

### 9.1 Common Queries

**Get user's active playgroups:**

```sql
SELECT p.*
FROM playgroups p
         JOIN playgroup_members pm ON pm.playgroup_id = p.id
WHERE pm.user_id = $1
  AND pm.removed_at IS NULL
ORDER BY p.updated_at DESC;
```

**Get playgroup game history (paginated):**

```sql
SELECT g.*
FROM games g
WHERE g.playgroup_id = $1
ORDER BY g.game_date DESC, g.created_at DESC
LIMIT 25 OFFSET $2;
```

**Get game details with players:**

```sql
SELECT gp.*,
       COALESCE(u.username, pm.non_user_name) as display_name,
       c.name                                 as commander_name,
       c.scryfall_border_crop                 as commander_image
FROM game_participants gp
         LEFT JOIN playgroup_members pm ON pm.id = gp.playgroup_member_id
         LEFT JOIN profiles u ON u.id = pm.user_id
         JOIN commanders c ON c.id = gp.commander_id
WHERE gp.game_id = $1
ORDER BY gp.finishing_position ASC;
```

**Search commanders:**

```sql
SELECT id, name, color_identity, scryfall_border_crop
FROM commanders
WHERE name ILIKE '%' || $1 || '%'
ORDER BY
    CASE WHEN name ILIKE $1 THEN 0 ELSE 1
END,
  name ASC
LIMIT 20;
```

**Player statistics (win rate, games played):**

```sql
SELECT pm.id                                                                        as member_id,
       COALESCE(u.username, pm.non_user_name)                                       as display_name,
       COUNT(DISTINCT gp.game_id)                                                   as games_played,
       COUNT(DISTINCT CASE WHEN gp.finishing_position = 1 THEN gp.game_id END)      as wins,
       ROUND(
               100.0 * COUNT(DISTINCT CASE WHEN gp.finishing_position = 1 THEN gp.game_id END)
                   / NULLIF(COUNT(DISTINCT gp.game_id), 0),
               2
       )                                                                            as win_rate,
       ROUND(AVG(gp.finishing_position), 2)                                         as avg_position
FROM playgroup_members pm
         LEFT JOIN profiles u ON u.id = pm.user_id
         JOIN game_participants gp ON gp.playgroup_member_id = pm.id
         JOIN games g ON g.id = gp.game_id
WHERE g.playgroup_id = $1
  AND pm.removed_at IS NULL
GROUP BY pm.id, u.username, pm.non_user_name;
```

**Commander statistics:**

```sql
SELECT c.id,
       c.name,
       c.color_identity,
       COUNT(gp.id)                                          as times_played,
       COUNT(CASE WHEN gp.finishing_position = 1 THEN 1 END) as wins,
       ROUND(
               100.0 * COUNT(CASE WHEN gp.finishing_position = 1 THEN 1 END)
                   / NULLIF(COUNT(gp.id), 0),
               2
       )                                                     as win_rate
FROM commanders c
         JOIN game_participants gp ON gp.commander_id = c.id
         JOIN games g ON g.id = gp.game_id
WHERE g.playgroup_id = $1
GROUP BY c.id, c.name, c.color_identity
HAVING COUNT(gp.id) >= 5
ORDER BY win_rate DESC
LIMIT 10;
```

### 9.2 Search Patterns

**Friend code lookup (for adding members):**

```sql
SELECT id, username, friend_code
FROM profiles
WHERE friend_code = $1  -- Exact match on friend code
  AND id NOT IN (
    SELECT user_id
    FROM playgroup_members
    WHERE playgroup_id = $2
      AND removed_at IS NULL
  )
LIMIT 1;
```

**Note:** This replaces username search. Users are added by exact friend code match only.

**Guest autocomplete:**

```sql
SELECT DISTINCT guest_name
FROM game_participants
WHERE game_id IN (SELECT id
                  FROM games
                  WHERE playgroup_id = $1)
  AND player_type = 'guest'
  AND guest_name ILIKE '%' || $2 || '%'
ORDER BY guest_name
LIMIT 20;
```

---

## 10. Performance Considerations

### 10.1 Optimization Strategy

- **Simple queries first**: Leverage indexes, avoid premature optimization
- **Pagination**: Use LIMIT/OFFSET with composite ORDER BY for stable sorting
- **Aggregation**: Compute statistics in application layer (no materialized views in MVP)
- **Soft delete filtering**: Always include WHERE clauses for removed_at IS NULL on playgroup_members
- **Partial indexes**: Improve query performance on filtered columns

### 10.2 Scalability Notes

- No database limits on games/members per playgroup
- Indexes support thousands of games efficiently
- ~2-3k commanders: simple ILIKE search adequate, no full-text search needed
- Consider materialized views for statistics if playgroups exceed 10k games (post-MVP)
- Consider pg_trgm extension for fuzzy commander search if needed (post-MVP)

---

## 11. Design Decisions Summary

1. ✅ **Soft deletes** for playgroup_members (removed_at) only; hard delete for games
2. ✅ **Dual member model** (user/non-user) and dual player model (member/guest) using ENUMs and check constraints
3. ✅ **No position validation** at database level (application handles)
4. ✅ **Partial unique index** for active memberships
5. ✅ **Simple ILIKE search** for commanders (no full-text)
6. ✅ **RLS helper function** for reusable membership checks
7. ✅ **Database-side UUID generation** using gen_random_uuid()
8. ✅ **TIMESTAMPTZ** for all timestamps, DATE for game_date
9. ✅ **Application-layer statistics** (no database views)
10. ✅ **Equal permissions model** (no role-based access)
11. ✅ **ON DELETE behaviors** preserve history where appropriate
12. ✅ **Single migration structure** for atomic deployment

---

## 12. Migration Implementation Notes

### 12.1 Migration Structure

The Supabase migration should follow this order:

1. **Extensions** (if needed)
2. **ENUM types** (player_type_enum)
3. **Tables** (in dependency order)
4. **Indexes** (after tables created)
5. **Triggers** (updated_at automation)
6. **RLS Helper Functions**
7. **Enable RLS** on tables
8. **RLS Policies**

### 12.2 Updated_at Trigger

Create a reusable trigger function to automatically update `updated_at` timestamps:

```sql
CREATE
OR REPLACE
FUNCTION trigger_set_updated_at()
RETURNS TRIGGER
SET search_path = ''
AS $$
BEGIN NEW.updated_at = NOW();
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
CREATE TRIGGER set_updated_at
    BEFORE UPDATE
    ON profiles
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

CREATE TRIGGER set_updated_at
    BEFORE UPDATE
    ON playgroups
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

CREATE TRIGGER set_updated_at
    BEFORE UPDATE
    ON playgroup_members
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

CREATE TRIGGER set_updated_at
    BEFORE UPDATE
    ON commanders
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

CREATE TRIGGER set_updated_at
    BEFORE UPDATE
    ON games
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

CREATE TRIGGER set_updated_at
    BEFORE UPDATE
    ON game_participants
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
```

### 12.3 Profile Creation Trigger

Automatically create profile with friend code when user signs up via Supabase Auth:

```sql
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_username TEXT;
  v_friend_code TEXT;
  v_random_code TEXT;
  v_attempt INTEGER := 0;
  v_max_attempts INTEGER := 10;
BEGIN
  -- Get username from metadata or generate default
  v_username := COALESCE(NEW.raw_user_meta_data ->> 'username', 'user_' || substr(NEW.id::text, 1, 8));

  -- Generate unique friend code with retry logic
  LOOP
    -- Generate 6-character uppercase alphanumeric code
    v_random_code := UPPER(
      substr(md5(random()::text || NEW.id::text || v_attempt::text), 1, 6)
    );
    -- Replace any lowercase letters with uppercase (md5 produces lowercase hex)
    v_random_code := UPPER(translate(
      v_random_code,
      'abcdef',
      regexp_replace(v_random_code, '[^0-9]', '', 'g') || 'ABCDEF'
    ));

    v_friend_code := v_username || '#' || v_random_code;

    -- Check if friend code is unique
    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE friend_code = v_friend_code) THEN
      EXIT;
    END IF;

    v_attempt := v_attempt + 1;
    IF v_attempt >= v_max_attempts THEN
      RAISE EXCEPTION 'Failed to generate unique friend code after % attempts', v_max_attempts;
    END IF;
  END LOOP;

  -- Insert profile with generated friend code
  INSERT INTO public.profiles (id, username, friend_code)
  VALUES (NEW.id, v_username, v_friend_code);

  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT
    ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();
```

**Notes:**
- Friend code format: `username#XXXXXX` where XXXXXX is 6 uppercase alphanumeric characters
- Retry logic handles rare collision cases (36^6 = ~2.1 billion combinations)
- Character set: A-Z, 0-9 (uppercase alphanumeric)
- Friend codes are permanent (no regeneration in MVP)

---

## 13. Testing Considerations

### 13.1 Data Integrity Tests

- ✅ Verify soft delete preserves historical data
- ✅ Test partial unique constraint on active memberships
- ✅ Validate check constraint on player_type
- ✅ Ensure cascade behaviors work correctly
- ✅ Test RLS policies for unauthorized access

### 13.2 Performance Tests

- ✅ Query performance with 1000+ games per playgroup
- ✅ Commander search with partial matches
- ✅ Statistics aggregation with large datasets
- ✅ Pagination stability with concurrent updates

### 13.3 Edge Cases to Test

- ✅ Re-adding removed playgroup members
- ✅ User account deletion converts user members to non-user members
- ✅ Ties in finishing positions
- ✅ Games with all guest players
- ✅ Empty statistics (zero games/wins)

---

## 14. Future Enhancements (Post-MVP)

1. **Materialized views** for statistics if performance degrades at scale
2. **pg_trgm extension** for fuzzy commander search
3. **Audit trail** tables for game edit history
4. **Optimistic locking** with version columns for concurrent edit detection
5. **Date range filtering** indexes for statistics queries
6. **Role-based permissions** (admin, moderator) if needed
7. **Playgroup archival** (separate from soft delete)
8. **Commander metadata sync** automation from Scryfall API
9. **Full-text search** on commander names/types if needed
10. **Composite indexes** optimization based on real query patterns

---

**Schema Version:** 1.1
**Last Updated:** 2025-11-04
**Status:** Security and performance optimized

**Changelog:**
- **v1.1** (2025-11-04): Applied security and performance fixes
  - Added `SET search_path = ''` to all functions (security fix)
  - Optimized RLS policies to use `(select auth.uid())` (performance fix)
  - Added foreign key indexes for better query performance
  - Removed duplicate index on profiles.friend_code
- **v1.0** (2025-11-03): Initial schema implementation
