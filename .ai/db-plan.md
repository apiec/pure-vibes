# Database Planning Summary

## Decisions

1. **Playgroup names**: No uniqueness constraint required (can have duplicate names across the system)

2. **Soft deletes**: Implement soft delete pattern for `playgroup_members` (removed_at) and `games` (deleted_at)

3. **Finishing positions**: Store position value for each player, allowing duplicates. Players with finishing_position = 1 are winners

4. **Account deletion handling**: When a user account is deleted, convert their game_players records to guest type using their username as guest_name

5. **Position validation**: No database-level validation for starting/finishing positions (no range checks, no uniqueness constraints). All validation done at application layer

6. **Commander search**: Use simple ILIKE '%search%' query for MVP (no pg_trgm extension needed for ~2-3k records)

7. **User profiles**: Create separate `profiles` table extending Supabase auth.users

8. **Guest player lookup**: Query `game_players` table directly with LIKE for past guests (no separate lookup table needed)

9. **Concurrent edits**: Defer optimistic locking to post-MVP (simple last-write-wins with updated_at tracking)

10. **Username snapshots**: Always display current username (no snapshot field in game_players)

11. **Player type field**: Use PostgreSQL ENUM type for player_type ('member' | 'guest')

12. **Playgroup deletion**: Use ON DELETE RESTRICT for games → playgroups relationship

13. **UUID generation**: Database-side using gen_random_uuid() as default value

14. **Timestamp types**: Use TIMESTAMPTZ for all timestamp fields; DATE type for game_date

15. **Commander database**: Populate via separate Node.js script from Scryfall bulk data API

16. **Playgroup description**: Remove description field entirely - only store playgroup name

17. **Statistics edge cases**: Use LEFT JOINS and COALESCE to handle zero games/wins gracefully

18. **Indexes**: Use separate UNIQUE constraints for business logic, regular indexes for performance, partial indexes for soft-deletes

19. **Game date validation**: Application layer only (no database constraints on date ranges)

20. **Player type constraint**: Check constraint ensures member has user_id (not NULL) and guest has guest_name (not NULL)

21. **RLS policies**: Enable on all user-facing tables; commanders table allows SELECT for all authenticated users

22. **RLS helper function**: Create is_active_playgroup_member() function for checking membership in policies

23. **Audit fields**: Include created_at and updated_at timestamps only (no created_by or updated_by fields)

24. **Composite index ordering**: Place filtered columns (removed_at, deleted_at) in WHERE clause of partial indexes

25. **Game deletion cascade**: Use ON DELETE CASCADE for game_players → games relationship

26. **Commander search query**: Use ILIKE with ORDER BY to prioritize exact matches, LIMIT 20

27. **Statistics implementation**: Compute in application layer with explicit queries (no database views in MVP)

28. **Pagination**: Use LIMIT/OFFSET with ORDER BY game_date DESC, created_at DESC for stable sorting

29. **Playgroup limits**: No database-level limits on games or members per playgroup

30. **Migration structure**: Single migration file with clear sections (extensions, enums, tables, indexes, constraints, RLS, functions)

## Matched Recommendations

1. **Use PostgreSQL ENUM type** for player_type field with values 'member' and 'guest' for better type safety and storage efficiency

2. **Implement soft delete pattern** using removed_at (playgroup_members) and deleted_at (games) timestamps to preserve historical data

3. **Store finishing positions as-is** allowing duplicate values for ties. Winner identification: finishing_position = 1

4. **Convert deleted users to guests** by setting player_type = 'guest', guest_name = username, then allowing user_id to SET NULL on cascade

5. **No database validation for positions** - all game logic (unique starting positions, valid finishing positions) handled in application layer

6. **Simple ILIKE search for commanders** with ORDER BY prioritizing exact matches, adequate for ~2-3k records without full-text indexes

7. **Create dedicated profiles table** with user_id FK to auth.users for better querying and RLS policy management

8. **Query game_players directly** for guest autocomplete using simple WHERE playgroup_id = X AND player_type = 'guest' queries

9. **Defer optimistic locking** - use updated_at for tracking but no conflict detection in MVP (last-write-wins)

10. **Use current usernames always** - no snapshot field needed, keeps data model simpler and reflects current state

11. **Database-side UUID generation** using gen_random_uuid() as default for all PK columns ensures consistency

12. **Use TIMESTAMPTZ for all timestamps** to handle timezone correctly; store in UTC, convert for display

13. **Separate Scryfall sync script** that performs UPSERT based on scryfall_id, can be run manually for MVP

14. **RLS helper function** `is_active_playgroup_member()` marked STABLE SECURITY DEFINER for reusable, efficient membership checks

15. **Use LEFT JOINS with COALESCE** in statistics queries to handle edge cases (zero games, zero wins) gracefully

16. **Partial unique index** on playgroup_members(playgroup_id, user_id) WHERE removed_at IS NULL for soft-delete uniqueness

17. **ON DELETE RESTRICT** for games → playgroups prevents accidental deletion of playgroups with history

18. **ON DELETE CASCADE** for game_players → games automatically cleans up player records when games are hard-deleted

19. **LIMIT/OFFSET pagination** with composite ORDER BY (game_date DESC, created_at DESC) for stable, predictable sorting

20. **Single migration file** with organized sections makes initial schema atomic and easier to review/deploy

21. **No playgroup/game limits** at database level - rely on indexes for performance, add application limits only if needed

22. **Application-layer statistics** using explicit queries in service functions for better testability and optimization flexibility

23. **Check constraint for player_type** ensures exactly one identity field (user_id for members, guest_name for guests) is populated

24. **Enable RLS on user tables** (profiles, playgroups, playgroup_members, games, game_players) but allow public SELECT on commanders

25. **Composite indexes on foreign keys** especially with soft-delete filters for optimal query performance

## Database Planning Summary

### Overview
The MTG Commander Stats Tracker requires a PostgreSQL database schema with 6 core tables supporting playgroup management, game tracking, and statistics aggregation. Key architectural decisions prioritize data preservation (soft deletes), flexible player models (members + guests), and equal permissions for all playgroup members.

### Core Entities

#### 1. Profiles (extends Supabase auth.users)
- Links to Supabase authentication
- Stores username (unique, searchable)
- Timestamps for tracking

#### 2. Playgroups
- Simple structure: name only (no description)
- No uniqueness constraint on names
- Created by user (no ongoing ownership/admin roles)

#### 3. Playgroup Members (soft delete pattern)
- Junction table for users ↔ playgroups many-to-many relationship
- **Critical**: removed_at timestamp for soft deletes
- Removed members lose access but their historical data remains
- Partial unique index ensures one active membership per user per playgroup
- Re-adding clears removed_at timestamp

#### 4. Commanders
- Pre-populated from Scryfall bulk data (legendary creatures, vehicles, spacecraft, commander planeswalkers)
- ~2-3k records, simple ILIKE search adequate for MVP
- Public read access for all authenticated users
- No RLS needed

#### 5. Games
- Game date as DATE type (no time component)
- Hard deletes
- Any playgroup member can create/edit/delete

#### 6. Game Players
- Junction table linking games to participants
- Dual player model: members (user_id FK) OR guests (guest_name text)
- Each player has commander, starting_position, finishing_position
- **Ties supported**: multiple players can have finishing_position = number
- **No validation at DB level** for positions
- ON DELETE CASCADE when game deleted
- ON DELETE SET NULL for user_id (converts to guest on account deletion)

### Key Relationships

**One-to-Many:**
- Playgroups → Games
- Games → Game Players
- Commanders → Game Players

**Many-to-Many:**
- Users ↔ Playgroups (via playgroup_members with soft delete)
- Users ↔ Games (via game_players as members)

### Data Integrity

**Soft Delete Pattern:**
- playgroup_members: removed_at IS NULL = active member
- All queries must filter for active/non-deleted records

**Foreign Key Cascades:**
- game_players → games: ON DELETE CASCADE (cleanup when game hard-deleted)
- game_players → users: ON DELETE SET NULL (preserve games when user account deleted)
- games → playgroups: ON DELETE RESTRICT (prevent playgroup deletion with games)

**Check Constraints:**
- Player type validation: members must have user_id, guests must have guest_name
- No position range validation at database level (application layer only)

**Unique Constraints:**
- profiles.username (global uniqueness)
- commanders.scryfall_id (prevent duplicates)
- Partial unique on playgroup_members(playgroup_id, user_id) WHERE removed_at IS NULL

### Security (Row-Level Security)

**RLS Enabled On:**
- profiles, playgroups, playgroup_members, games, game_players

**RLS Helper Function:**
```sql
is_active_playgroup_member(playgroup_id, user_id)
```
Returns true if user is active member (removed_at IS NULL)

**Permission Model:**
- All playgroup members have equal permissions
- No admin/owner/moderator roles
- Members can: add/edit/delete games, add/remove members, view all data
- Access gated by active membership check

**Commanders Table:**
- No RLS (public read for authenticated users)
- Populated by admin script only

### Performance Optimization

**Critical Indexes:**
1. playgroup_members(playgroup_id, user_id) WHERE removed_at IS NULL (partial unique)
2. playgroup_members(user_id) WHERE removed_at IS NULL (user's playgroups)
3. games(playgroup_id, game_date DESC) WHERE deleted_at IS NULL (game history)
4. game_players(game_id) (fetch players for game)
5. game_players(user_id) (user's game history)
6. game_players(commander_id) (commander statistics)
7. commanders(name) (search autocomplete)

**Query Patterns:**
- Simple ILIKE '%search%' for commander search with exact match prioritization
- LIMIT/OFFSET pagination for game history (25 per page)
- LEFT JOINS with COALESCE for statistics aggregation
- Application-layer statistics computation (no views in MVP)

**Scalability Considerations:**
- No limits on games or members per playgroup
- Indexes support thousands of games efficiently
- Materialized views deferred to post-MVP if needed

### Special Cases Handling

**Ties in Finishing Positions:**
- Multiple players can have same finishing_position value
- Position 1 = winner(s)
- Draws are rounded down to the lowest common position (2 last players would both have 2nd place, not 1st)

**Guest Players:**
- "Guest John" in game 1 == "Guest John" in game 2
- Autocomplete by querying game_players.guest_name with LIKE
- Included in aggregate commander/playgroup statistics

**Removed Playgroup Members:**
- Soft delete preserves all historical game data
- Removed members can't access playgroup
- Games still display their username
- Re-adding restores full access to history

**User Account Deletion:**
- Application converts member records to guests first
- Sets player_type = 'guest', guest_name = preserved username
- Then allows user_id SET NULL cascade
- Games preserved showing deleted user as guest

**Username Changes:**
- Always display current username (no snapshots)
- Historical games reflect updated usernames

### Technical Specifications

**Data Types:**
- UUID for all IDs (gen_random_uuid() default)
- TIMESTAMPTZ for all timestamps (UTC storage)
- DATE for game_date (no time component)
- TEXT for strings (no VARCHAR)
- ENUM for player_type

**Migration Structure:**
- Single migration file with sections: extensions, enums, tables, indexes, constraints, RLS, functions
- Atomic deployment of complete schema

**Commander Data Source:**
- Separate script fetches Scryfall bulk data
- Filters for legal commanders
- UPSERT based on scryfall_id
- Manual execution for MVP

## Schema Implementation Changes

During the implementation of the database schema (documented in `.ai/db-schema.md`), several significant changes were made from the original plan. This section documents those changes for reference.

### 1. Friend Code System (New Feature)

**Original Plan:**
- Username field was globally unique
- Users added to playgroups via username search

**Schema Implementation:**
- Username is NO LONGER globally unique (multiple users can have same username)
- New `friend_code` field added to profiles table (TEXT, NOT NULL, UNIQUE)
- Friend code format: `username#XXXXXX` where XXXXXX is 6 uppercase alphanumeric characters (A-Z, 0-9)
- Friend codes are permanent (no regeneration in MVP)
- Users now added to playgroups via exact friend code match instead of username search
- Automatic generation via `handle_new_user()` trigger with collision retry logic (36^6 = ~2.1 billion combinations)

**Rationale:** Allows username flexibility while maintaining unique identifiers for member management.

---

### 2. Dual Member Model (Major Change)

**Original Plan:**
- Simple many-to-many relationship between users and playgroups
- Only registered users could be playgroup members

**Schema Implementation:**
- Introduced dual member model with `member_type_enum` ('user' | 'non_user')
- Added `non_user_name` field (TEXT, nullable) to playgroup_members
- Changed `user_id` from NOT NULL to nullable
- Check constraint ensures exactly one identity: `(member_type = 'user' AND user_id IS NOT NULL) OR (member_type = 'non_user' AND non_user_name IS NOT NULL)`
- Non-user members have no system account but can be tracked in playgroups and participate in games

**Rationale:** Supports playgroups that track non-registered participants (e.g., friends who don't want accounts).

---

### 3. Games Soft Delete Removed

**Original Plan:**
- Decision #2: "Implement soft delete pattern for games (deleted_at)"

**Schema Implementation:**
- Games use hard delete only (no deleted_at field)
- Simplified game lifecycle management

**Rationale:** Simplified implementation; games can be truly deleted without historical preservation requirement.

---

### 4. Table Rename: game_players → game_participants

**Original Plan:**
- Table named "game_players"

**Schema Implementation:**
- Table renamed to "game_participants"

**Rationale:** More semantically accurate name reflecting both member and guest participation.

---

### 5. Restructured Player-Game Relationship (Major Change)

**Original Plan:**
- game_players table with direct `user_id` foreign key to profiles
- Simple dual player model: members (user_id FK) OR guests (guest_name text)

**Schema Implementation:**
- game_participants table with `playgroup_member_id` foreign key to playgroup_members
- Adds indirection layer through membership table
- Players are either members (have playgroup_member_id) OR guests (have guest_name only)
- player_type ENUM ('member' | 'guest') tracks distinction
- Members can be users OR non-users (resolved via playgroup_members.member_type)

**Rationale:** Supports the dual member model and maintains referential integrity through playgroup membership.

---

### 6. Statistics Handling Distinction

**Original Plan:**
- No distinction mentioned for statistics aggregation

**Schema Implementation:**
- **Members** (player_type = 'member'): Statistics summarized on dashboard
- **Guests** (player_type = 'guest'): No statistics summary on dashboard
- Non-user members included in statistics (treated as members, not guests)

**Rationale:** Guests are one-time participants; members (user and non-user) are tracked for statistics.

---

### 7. Foreign Key Cascade Behavior Changes

**Original Plan:**
- No specification for playgroups.created_by cascade
- game_players.user_id: ON DELETE SET NULL (converts to guest)
- No specification for playgroup_members.user_id cascade

**Schema Implementation:**
- **playgroups.created_by**: ON DELETE RESTRICT (prevents creator deletion with active playgroups)
- **playgroup_members.user_id**: ON DELETE CASCADE (application converts user members to non_user members before deletion)
- **game_participants.playgroup_member_id**: ON DELETE SET NULL (preserves games when member removed)

**Rationale:** More precise control over deletion cascades; playgroup_members now handles user deletion by converting to non-user type.

---

### 8. Commander Image Fields Expanded

**Original Plan:**
- No specification of image URL fields

**Schema Implementation:**
- Six specific Scryfall image URL fields added:
  - scryfall_png
  - scryfall_border_crop
  - scryfall_art_crop
  - scryfall_large
  - scryfall_normal
  - scryfall_small

**Rationale:** Provides flexibility for different UI contexts (card display, thumbnails, backgrounds).

---

### 9. Profile Creation Automation

**Original Plan:**
- No trigger specification for profile creation

**Schema Implementation:**
- Added `handle_new_user()` trigger function
- Automatically creates profile with friend code when user signs up via Supabase Auth
- Includes retry logic for friend code collision handling (up to 10 attempts)
- Extracts username from auth metadata or generates default: `user_<first-8-chars-of-id>`

**Rationale:** Automates profile setup and ensures every user has a friend code immediately upon registration.

---

### 10. Updated_at Field Inconsistencies

**Original Plan:**
- Decision #23: "Include created_at and updated_at timestamps" on all tables

**Schema Implementation:**
- playgroup_members does NOT include updated_at field
- All other tables include both created_at and updated_at with trigger automation

**Rationale:** Implementation inconsistency; playgroup_members primarily uses removed_at for tracking changes.

---

### 11. Query Pattern Complexity Increase

**Original Plan:**
- Simple joins from game_players to users for display names
- Username search for adding members

**Schema Implementation:**
- Complex joins: game_participants → playgroup_members → profiles
- Display name resolution: `COALESCE(u.username, pm.non_user_name)` handles both user and non-user members
- Friend code lookup query replaces username search entirely

**Rationale:** Necessary complexity to support dual member model and friend code system.

---

### 12. RLS Policy Optimization

**Original Plan:**
- Use `auth.uid()` directly in RLS policies

**Schema Implementation:**
- Use `(select auth.uid())` subquery syntax for better performance
- Added `SET search_path = ''` to all functions for security

**Rationale:** Performance optimization and security hardening (prevents search path injection attacks).

---

## Summary of Architectural Evolution

The schema implementation evolved from a **simple user-only model** to a **flexible dual-model system** supporting:

1. **Multiple identity types**: Users, non-user members, and guests
2. **Username flexibility**: Friend codes enable unique identification without forcing unique usernames
3. **Membership indirection**: game_participants references playgroup_members (not direct user references)
4. **Simplified game lifecycle**: Hard deletes instead of soft deletes for games
5. **Statistics granularity**: Different handling for members vs guests

These changes maintain the core functionality described in the original plan while adding flexibility for real-world usage patterns where not all participants have or want system accounts.

## Unresolved Issues

No unresolved issues remain. All critical database design decisions have been made:

✓ Table structures defined
✓ Relationship patterns established
✓ Soft delete strategy confirmed
✓ Permission model clarified
✓ Performance optimization approach decided
✓ Data validation boundaries set (DB vs application)
✓ Foreign key cascade behaviors specified
✓ Search and pagination strategies chosen
✓ Edge case handling documented

The schema is ready for implementation as a Supabase migration file.
