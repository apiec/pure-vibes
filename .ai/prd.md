# Product Requirements Document (PRD) - MTG Commander Stats Tracker

## 1. Product Overview

### 1.1 Product Name
MTG Commander Stats Tracker (Internal codename: Pure Vibes)

### 1.2 Product Description
A web-based application designed to help Magic: The Gathering Commander (EDH) playgroups track game statistics, analyze performance metrics, and maintain historical records of their games. The application provides an intuitive interface for recording games, viewing comprehensive statistics, and understanding playgroup dynamics through data visualization.

### 1.3 Target Audience
- Magic: The Gathering Commander playgroups (3-6 regular players) who want to track game outcomes
- Players interested in commander performance analytics and win rate statistics

## 2. User Problem
Magic: The Gathering Commander playgroups face several challenges when attempting to track their game statistics:
1. Manual Tracking is Tedious: Using spreadsheets or pen-and-paper requires significant manual effort, data entry errors are common, and maintaining consistency across multiple games is difficult.
2. Limited Insights: Static tracking methods provide no automatic analysis, visualization, or trend identification. Players cannot easily answer questions like "Which commander has the best win rate?" or "Who wins most often when going first?"
3. Missing Social Aspect: Tracking statistics individually misses the collaborative and competitive social dynamics that make playgroups engaging. There's no shared view of group performance.

This application solves these problems by providing:
- Centralized Data Management: Single source of truth for all playgroup games and statistics
- Automatic Analytics: Instant calculation of win rates, commander performance, and player statistics
- Ease of Use: Simple game entry process optimized for mobile and desktop
- Historical Preservation: Permanent record of all games with full details
- Social Engagement: Shared dashboard that enhances playgroup dynamics and friendly competition
- Data Portability: CSV import allows migration from existing tracking solutions

## 3. Functional Requirements

### 3.1 Authentication and User Management

#### 3.1.1 User Registration
- Users must create accounts using email and password through Supabase Authentication
- Required fields: email address, password (minimum 8 characters)
- Email verification required before account activation
- Password reset functionality via email

#### 3.1.2 User Login
- Login via email and password
- Session persistence across browser sessions
- Logout functionality
- Password recovery through email reset flow

### 3.2 Playgroup Management

#### 3.2.1 Playgroup Creation
- Any authenticated user can create a new playgroup
- Required fields:
  - Playgroup name (unique per user, 3-50 characters)
- Creator is automatically added as first member

#### 3.2.2 Adding Members
- Search for users by email or username
- Add registered users to playgroup
- No invite/approval workflow required (immediate addition)
- Users can be members of multiple playgroups
- No limit on number of playgroups a user can join

#### 3.2.3 Removing Members
- Any playgroup member can remove any other member (including themselves)
- Removing a member does not delete historical game data
- Games played by removed members remain in history with their data intact
- Removed members lose access to playgroup but their statistics are preserved
- Re-adding a previously removed member restores their access to all historical data

#### 3.2.4 Playgroup Browsing
- Users see a list of all playgroups they are members of
- Display shows: playgroup name, member count, total games played, last game date
- One active playgroup selected at a time for context
- Switching between playgroups changes the active context
- No multi-playgroup simultaneous view in MVP

#### 3.2.5 Playgroup Details
- View all current members with usernames
- See total games played
- See date of first and most recent game
- Edit playgroup name

### 3.3 Commander Database

#### 3.3.1 Data Source
- Commander list derived from Scryfall bulk data API
- Includes all legal commanders:
  - Legendary creatures
  - Legendary vehicles
  - Legendary spacecraft
  - Planeswalkers with "can be your commander" ability text

#### 3.3.2 Data Storage
- Pre-computed database table populated via data processing script
- Stored fields:
  - Card name
  - Scryfall ID (UUID)
  - Image URIs
  - Color identity (WUBRG notation)

#### 3.3.3 Commander Search
- Type-ahead search functionality with autocomplete
- Search by card name (partial match, case-insensitive)
- Display results showing card name
- Maximum 20 results displayed at once
- Exact name match prioritized over partial matches

#### 3.3.4 Commander Display
- Users can hover over commander names to see the card image

### 3.4 Game Recording

#### 3.4.1 Game Creation Flow
1. User initiates "Add Game" from active playgroup
2. Set game date
3. Add players (members or guests)
4. Select commander for each player
5. Set starting order
6. Record finishing order
7. Save game record

#### 3.4.2 Player Selection
- Add playgroup members or past guests from a dropdown list
- Add new guest players by entering name (free text, 2-30 characters)
- Minimum players per game: 2
- Maximum players per game: 10
- Each player must be unique within a single game

#### 3.4.3 Commander Selection
- Search and select from pre-computed commander database
- Each player can have a different commander
- Same commander can be played by multiple players in one game
- Display card image preview during selection

#### 3.4.4 Starting Order
- Define the order in which players took their first turn
- Positions numbered 1 through N (where N = number of players)
- Each position must be assigned to exactly one player

#### 3.4.5 Finishing Order
- Record the order in which players were eliminated or won
- Position 1 = winner
- Last position = first eliminated
- Ties allowed: multiple players can share the same position, ties are handled by putting multiple players as the lowest possible position
- Example: In a 4-player game, 1 player got eliminated first, then another got eliminated and two remaining players died at the same time. The last two would tie for second place (no winner this game)
- All players must have a finishing position assigned

#### 3.4.6 Game Date
- Date field required for every game
- Defaults to current date
- No time component tracked in MVP

### 3.5 Game History

#### 3.5.1 Game List View
- Display all games for selected playgroup in reverse chronological order
- Each list item shows:
  - Game date
  - Winner name (if no winner - show information about a tie)
  - Player count (total number of players)
- Pagination: 25 games per page
- Filter options: None in MVP (all-time view only)

#### 3.5.2 Game Detail View
- Click on game to view full details:
  - Complete player list with commanders
  - Card images for all commanders played
  - Starting order for each player
  - Finishing order/positions
  - Game date
  - Indicators for member vs. guest players
  - Edit and delete buttons

#### 3.5.3 Game Editing
- Any playgroup member can edit any game
- All game fields editable (players, commanders, orders, date)
- Validation same as game creation
- Editing updates all related statistics automatically
- No edit history/audit trail in MVP

#### 3.5.4 Game Deletion
- Any playgroup member can delete any game
- Confirmation dialog required before deletion
- Deleted games excluded from all statistics and history views

### 3.6 Statistics Dashboard

#### 3.6.1 Dashboard Scope
- All-time statistics for selected playgroup
- No date range filtering in MVP
- Automatic recalculation when games are added/edited/deleted

#### 3.6.2 Player Statistics
For each playgroup member, display:
- Total games played
- Total wins
- Win rate percentage
- Average finishing position
- Most played commander (name and play count)
- Best performing commander (name and win rate, minimum 5 games)

#### 3.6.3 Commander Statistics
Aggregate statistics across all commanders:
- Most played commanders (top 10, sorted by play count)
- Highest win rate commanders (minimum 5 games played, top 10)
- Color identity distribution (pie chart or bar chart)
- Commander diversity metric (unique commanders / total games)

#### 3.6.4 Playgroup Metrics
Overall playgroup statistics:
- Total games played
- Total unique commanders played
- Average players per game
- Date range (first game to most recent game)
- Most common player count (mode)

#### 3.6.5 Trends and Visualizations
- Win rate over time: line chart showing each player's win rate in rolling 30-game windows
- Starting position analysis: win rate by starting position (does going first matter?)
- Games per month: bar chart showing game frequency over time
- Charts use simple library
- Responsive design for mobile and desktop viewing

#### 3.6.6 Guest Player Handling
- Games with guest players included in all aggregate statistics
- Guest players do not have individual statistics pages
- Guest commanders counted in commander statistics
- Guest names not standardized (each entry treated independently)

### 3.7 Permission Model

#### 3.7.1 Playgroup Permissions
- All playgroup members have equal permissions
- No admin, owner, or moderator roles
- No role-based access control in MVP

#### 3.7.2 Allowed Actions for All Members
- Add new games
- Edit any game
- Delete any game
- Add new members to playgroup
- Remove any member (including themselves)
- View all statistics and history

#### 3.7.3 Limitations
- Cannot delete entire playgroup
- Cannot modify another user's profile
- Cannot access playgroups they are not a member of

## 4. Product Boundaries

### 4.1 What IS Included in MVP

1. Email/password authentication via Supabase
2. Playgroup creation and member management
3. In-app user search by email/username for adding members
4. Game recording with full details (players, commanders, orders, date)
5. Guest player support (non-member participants)
6. Pre-computed commander database from Scryfall bulk data
7. Commander search with autocomplete and image display
8. Game history browsing with list and detail views
9. Comprehensive all-time statistics dashboard
10. Data visualizations (charts for trends and distributions)
11. CSV import for historical game data
12. Equal permissions for all playgroup members
13. Game editing and deletion capabilities
14. Tie support in finishing positions
15. Mobile-responsive design

### 4.2 What is NOT Included in MVP

1. Individual user profile pages or user statistics across all playgroups
2. Individual commander pages with detailed insights
3. Social features (comments, reactions, achievements)
4. Role-based permissions (admin/moderator roles)
5. Invite links for playgroup joining (deferred to post-MVP)
6. Email invitations to non-registered users
7. Date range filtering for statistics (future feature)
8. Export functionality (PDF, Excel)
9. Real-time notifications or activity feeds
10. Deck list tracking or integration
11. Commander power level ratings
12. Matchmaking or suggested pairings
13. Integration with MTG card databases beyond Scryfall
14. Social authentication (Google, Discord, etc.)
15. Multi-language support (English only for MVP)
16. Dark mode theme toggle (system preference only)
17. Playgroup chat or messaging
18. Mobile native apps (web-only)
19. Offline support or PWA functionality
20. Advanced analytics (machine learning, predictions)

### 4.3 Acknowledged Simplifications for MVP

1. No audit trail for game edits or deletions
2. No maximum game history retention limits
3. Simplified permission model (no granular controls)
4. No commander database update mechanism (manual refresh required)
5. No API rate limiting or abuse prevention beyond basic measures
6. No advanced search or filtering in game history
7. No data export capabilities
8. No playgroup archival or soft deletion

### 4.4 Future Considerations (Post-MVP)

1. Shareable invite links with expiration
2. Date range filtering for statistics
3. Individual user profile pages showing cross-playgroup stats
4. Commander detail pages with meta analysis per playgroup
5. Export to PDF or Excel
6. Social authentication providers
7. Power level estimation for commanders
8. Deck list integration and tracking
9. Import data from CSV
10. Advanced permission system for managing the play groups

## 5. User Stories

### 5.1 Authentication and Account Management

#### US-001: User Registration
Title: Create a new user account
Description: As a new user, I want to create an account using my email and password so that I can access the application and create or join playgroups.
Acceptance Criteria:
- User can navigate to registration page from landing page
- Form requires email address and password (minimum 8 characters)
- Email validation ensures proper format
- Password requirements displayed and enforced
- Duplicate email addresses rejected with clear error message
- Successful registration sends verification email
- User redirected to "verify email" page after registration
- Unverified accounts cannot access protected features

#### US-002: Email Verification
Title: Verify email address after registration
Description: As a newly registered user, I want to verify my email address so that I can fully activate my account and access all features.
Acceptance Criteria:
- Verification email sent immediately after registration
- Email contains unique verification link
- Clicking link verifies account and redirects to login
- Verified status persisted in database
- Unverified users see banner prompting verification
- "Resend verification email" option available
- Verification links expire after 24 hours

#### US-003: User Login
Title: Log into existing account
Description: As a registered user, I want to log in using my email and password so that I can access my playgroups and game data.
Acceptance Criteria:
- Login form accessible from landing page
- Email and password fields required
- Invalid credentials show clear error message
- Successful login redirects to playgroups dashboard
- Session persists across browser sessions
- Unverified accounts blocked from login with helpful message
- Login form includes "Forgot password?" link

#### US-004: Password Reset
Title: Reset forgotten password
Description: As a user who forgot their password, I want to reset it via email so that I can regain access to my account.
Acceptance Criteria:
- "Forgot password" link visible on login page
- User enters email address
- Reset email sent if account exists (no confirmation if account doesn't exist for security)
- Reset email contains unique password reset link
- Reset link expires after 1 hour
- User can set new password meeting requirements
- After reset, user redirected to login with success message
- Old password immediately invalidated

#### US-005: User Logout
Title: Log out of account
Description: As a logged-in user, I want to log out so that I can secure my account when using shared devices.
Acceptance Criteria:
- Logout button visible in navigation menu
- Clicking logout immediately ends session
- User redirected to landing/login page
- All authentication tokens cleared
- Attempting to access protected routes after logout redirects to login
- Logout confirmation not required (immediate action)

### 5.2 Playgroup Management

#### US-006: Create Playgroup
Title: Create a new playgroup
Description: As an authenticated user, I want to create a new playgroup so that I can start tracking games with my friends.
Acceptance Criteria:
- "Create Playgroup" button visible on playgroups dashboard
- Form requires playgroup name (3-50 characters)
- Optional description field (up to 500 characters)
- Playgroup name uniqueness validated per user
- Creator automatically added as first member
- Successful creation redirects to playgroup details page
- New playgroup set as active playgroup
- Empty game history displayed initially

#### US-007: View Playgroup List
Title: Browse all my playgroups
Description: As a user, I want to see a list of all playgroups I'm a member of so that I can switch between them and track multiple groups.
Acceptance Criteria:
- Playgroups dashboard shows all playgroups user is member of
- Each playgroup displays: name, member count, total games, last game date
- Currently active playgroup visually highlighted
- Empty state shown if user has no playgroups
- "Create Playgroup" call-to-action prominent when no playgroups exist
- List sorted by most recently active (last game date)
- Clicking playgroup card sets it as active and navigates to details

#### US-008: Search for Users
Title: Find users to add to playgroup
Description: As a playgroup member, I want to search for registered users by email or username so that I can add them to my playgroup.
Acceptance Criteria:
- Search input field on "Add Member" interface
- Search accepts email address or username
- Case-insensitive partial matching supported
- Search results display username and email
- Maximum 20 results shown
- Only verified users appear in results
- Users already in playgroup excluded from results
- "No results found" message when search yields nothing
- Clear search button to reset results

#### US-009: Add Member to Playgroup
Title: Add a user to playgroup
Description: As a playgroup member, I want to add other registered users to my playgroup so that they can participate in game tracking.
Acceptance Criteria:
- "Add Member" button visible in playgroup details
- User search interface displayed
- Clicking user from search results adds them immediately
- No invitation or approval workflow required
- New member immediately gains full access to playgroup
- New member sees playgroup in their playgroups list
- Success notification shown after adding member
- Playgroup member count updates

#### US-010: Remove Member from Playgroup
Title: Remove a member from playgroup
Description: As a playgroup member, I want to remove other members (or myself) from a playgroup so that I can manage the group membership.
Acceptance Criteria:
- "Remove" button visible next to each member in member list
- Confirmation dialog required before removal
- Any member can remove any other member (including themselves)
- Removed member loses access to playgroup immediately
- Removed member's historical game data remains intact
- Games with removed member still display their name
- Statistics recalculated excluding removed member's future access
- Removed member's playgroup list updated
- User can remove themselves (leave playgroup)
- Playgroup persists even if all members removed

#### US-011: View Playgroup Details
Title: See detailed information about a playgroup
Description: As a playgroup member, I want to view comprehensive details about my playgroup so that I understand its current state and history.
Acceptance Criteria:
- Playgroup details page shows name and description
- Complete member list displayed with usernames
- Total games played count shown
- Date of first game displayed
- Date of most recent game displayed
- "Add Game" button prominently placed
- "Add Member" button accessible
- Navigation to game history section
- Navigation to statistics dashboard
- Playgroup name editable

### 5.3 Commander Database and Search

#### US-013: Search for Commander
Title: Find a commander card for game entry
Description: As a user recording a game, I want to search for commander cards so that I can accurately log which commanders were played.
Acceptance Criteria:
- Commander search field displayed for each player in game entry
- Type-ahead autocomplete activates after 2 characters
- Search matches card names (partial, case-insensitive)
- Results display card name, color identity, and thumbnail image
- Maximum 20 results shown at once
- Exact matches prioritized over partial matches
- Clicking result selects commander and closes search
- Selected commander shows card image preview
- Search includes all legal commanders from Scryfall database
- No results message shown when no matches found

#### US-014: View Commander Card Image
Title: See visual representation of commander card
Description: As a user, I want to see the card image of selected commanders so that I can visually confirm the correct card.
Acceptance Criteria:
- Card image displayed after commander selection
- Image loaded from Scryfall URI stored in database
- Hover or click shows larger version of image
- Image includes card art and full card details
- Broken image fallback shows card name as text
- Loading state shown while image fetches
- External link to full Scryfall page available

### 5.4 Game Recording

#### US-015: Add New Game
Title: Record a new game for the playgroup
Description: As a playgroup member, I want to add a new game record so that our playgroup history and statistics are up to date.
Acceptance Criteria:
- "Add Game" button accessible from playgroup details and game history
- Form guides user through multistep process
- Game date field defaults to today but can be edited
- All fields validated before submission
- Success message shown after saving
- User redirected to game detail view
- New game appears at top of history list
- Statistics automatically updated
- The form should be mobile responsive to allow for users to track their games at the game table

#### US-016: Add Players to Game
Title: Select which players participated in the game
Description: As a user recording a game, I want to add players (members or guests) so that the game record accurately reflects who played.
Acceptance Criteria:
- Dropdown list shows all current playgroup members
- Option to add guest player with free-text name entry
- Guest names validated (2-30 characters, no special validation)
- Minimum 2 players required
- Maximum 10 players enforced
- Each player unique within game (no duplicates)
- Mix of members and guests allowed
- Visual distinction between member and guest players
- Remove player button available before submission
- Error message if minimum player count not met

#### US-017: Select Commander for Each Player
Title: Choose which commander each player used
Description: As a user recording a game, I want to select the commander for each player so that we can track commander performance statistics.
Acceptance Criteria:
- Commander selection required for every player
- Commander search interface provided for each player
- Search functionality same as US-013
- Each player can have different commander
- Same commander can be selected multiple times in one game
- Card image preview shown after selection
- "Change commander" option available to re-search
- Cannot proceed to next step until all commanders selected
- Error message highlights players missing commanders

#### US-018: Set Starting Order
Title: Record the turn order for the game
Description: As a user recording a game, I want to set the starting order so that we can analyze whether going first provides an advantage.
Acceptance Criteria:
- Starting order input shown after players and commanders selected
- Positions numbered 1 through N (N = player count)
- Drag-and-drop interface for ordering players
- Alternatively, dropdown selection for each position
- Each position assigned to exactly one player
- All positions must be filled
- Visual confirmation of complete starting order
- Cannot proceed until all positions assigned
- Error message if positions incomplete or duplicated

#### US-019: Record Finishing Order
Title: Log the final placement of each player
Description: As a user recording a game, I want to record the finishing order so that we can track wins and performance.
Acceptance Criteria:
- Finishing order input shown after starting order
- Position 1 = winner(s)
- Last position = first eliminated
- Multiple players can share same position (tie support)
- All players must be assigned a finishing position
- Visual interface shows positions 1 through N
- Drag-and-drop or selection interface
- Clear indicator for tied positions
- Cannot proceed until all players assigned
- Error message if any player unassigned

#### US-021: Submit Game Record
Title: Save the completed game to playgroup history
Description: As a user who has filled out game details, I want to submit the game so that it's recorded in our playgroup history.
Acceptance Criteria:
- "Save Game" button visible after all required fields completed
- Button disabled until minimum requirements met
- Validation performed before submission
- Clear error messages for validation failures
- Success notification after save
- Game immediately visible in history
- Statistics dashboard updated automatically
- User redirected to game detail view
- Option to "Add Another Game" available

### 5.5 Game History and Management

#### US-022: View Game History List
Title: Browse all games played by the playgroup
Description: As a playgroup member, I want to see a list of all games so that I can review our playgroup's history.
Acceptance Criteria:
- Game history accessible from playgroup navigation
- Games listed in reverse chronological order (newest first)
- Each game card shows: date, winner(s), player count
- Visual indicator for games with guest players
- Pagination with 25 games per page
- Page numbers or infinite scroll
- Empty state shown if no games recorded
- "Add Game" call-to-action prominent when history empty
- Loading state while fetching games

#### US-023: View Game Details
Title: See comprehensive details of a specific game
Description: As a user, I want to click on a game to view its full details so that I can see all information recorded about it.
Acceptance Criteria:
- Clicking game from history opens detail view
- Complete player list with names displayed
- Commander for each player shown with card image
- Starting order clearly indicated
- Finishing order/positions displayed
- Game date shown
- Member vs. guest indicator for each player
- "Edit Game" button visible
- "Delete Game" button visible
- "Back to History" navigation available

#### US-024: Edit Existing Game
Title: Modify details of a previously recorded game
Description: As a playgroup member, I want to edit any game so that I can correct mistakes or update information.
Acceptance Criteria:
- "Edit Game" button visible in game detail view
- Any member can edit any game (equal permissions)
- Edit form pre-populated with existing data
- All fields editable (players, commanders, orders, date)
- Same validation as game creation
- Changes saved immediately to database
- Statistics recalculated automatically
- Success notification shown
- User returned to updated game detail view
- No edit history or audit trail tracked

#### US-025: Delete Game
Title: Remove a game from playgroup history
Description: As a playgroup member, I want to delete games so that I can remove mistakes or games that shouldn't be tracked.
Acceptance Criteria:
- "Delete Game" button visible in game detail view
- Any member can delete any game (equal permissions)
- Confirmation dialog required before deletion
- Confirmation shows game date and winner for verification
- Deleted game removed from history list
- Deleted game excluded from all statistics
- Soft delete in database (data retained but marked deleted)
- No recovery mechanism in MVP
- Success notification shown
- User redirected to game history list
- Statistics recalculated automatically

### 5.6 Statistics and Analytics

#### US-026: View Player Statistics
Title: See performance metrics for each playgroup member
Description: As a playgroup member, I want to view individual player statistics so that I can understand each member's performance.
Acceptance Criteria:
- Statistics dashboard accessible from playgroup navigation
- Section for each playgroup member displayed
- For each member show: total games, total wins, win rate %, average finishing position
- Most played commander shown with play count
- Best performing commander shown with win rate (minimum 3 games)
- Statistics include only games where player was a member (not guest)
- Empty state for members with no games
- Statistics update automatically when games added/edited/deleted
- Visual formatting (charts, progress bars, or cards)

#### US-027: View Commander Statistics
Title: See performance metrics for commanders
Description: As a user, I want to view commander statistics so that I can understand which commanders perform best in our playgroup.
Acceptance Criteria:
- Commander statistics section in dashboard
- Top 10 most played commanders with play counts
- Top 10 highest win rate commanders (minimum 5 games played)
- Each commander shows name, color identity, and card image
- Win rate calculated as (wins / games played) × 100
- Color identity distribution visualization (pie or bar chart)
- Commander diversity metric displayed (unique commanders / total games)
- Commanders from guest games included
- Clicking commander shows games where it was played (future enhancement not required)

#### US-028: View Playgroup Metrics
Title: See overall playgroup statistics
Description: As a playgroup member, I want to view aggregate playgroup metrics so that I understand our group's activity and patterns.
Acceptance Criteria:
- Playgroup metrics section in dashboard
- Total games played displayed prominently
- Total unique commanders played shown
- Average players per game calculated
- Date range shown (first game to most recent)
- Most common player count displayed
- Metrics update automatically with new data
- Visual cards or panels for each metric
- Empty state if no games recorded

#### US-029: View Win Rate Trends
Title: See how win rates change over time
Description: As a user, I want to see win rate trends so that I can understand performance changes across our playgroup history.
Acceptance Criteria:
- Line chart showing win rates over time
- Each player represented by different colored line
- X-axis shows time (game sequence or date)
- Y-axis shows win rate percentage
- Rolling 10-game window for smoothing
- Chart responsive for mobile and desktop
- Legend identifying each player
- Tooltip on hover showing exact values
- Empty state if insufficient games (<10)

#### US-030: View Starting Position Analysis
Title: Analyze advantage of starting position
Description: As a user, I want to see if starting position affects win rate so that we can understand if going first is advantageous.
Acceptance Criteria:
- Chart or table showing win rate by starting position
- Positions 1-4 (or max players in group) displayed
- Win rate percentage calculated for each position
- Sample size (total games) shown for each position
- Visual indicator if difference is significant
- Includes all games regardless of player count
- Empty state if insufficient data

#### US-031: View Games Per Month
Title: See game frequency over time
Description: As a user, I want to see how many games we play each month so that I can understand our playgroup activity patterns.
Acceptance Criteria:
- Bar chart showing games played per month
- X-axis shows months (e.g., "Jan 2024")
- Y-axis shows game count
- Displays last 12 months or all-time if less than 12 months
- Responsive design for mobile
- Tooltip shows exact count on hover
- Empty months shown as zero (not omitted)
- Chart updates automatically with new games

## 6. Success Metrics
### 6.1 Active Usage: Game Recording
Target: 80% of users record at least 1 game
Rationale: This metric demonstrates that users are actively using the primary feature (game tracking) rather than just browsing. It validates that the application solves the real problem of tracking Commander games.

### 6.2 Social Adoption: Multi-User Playgroups
Target: 25% of playgroups have at least 2 active users (users who have each recorded at least one game)
Rationale: This metric validates the social/collaborative aspect of the application and indicates true playgroup engagement rather than solo usage. It confirms the product is used as intended—by groups playing together.

### 6.3 Average Games Per Playgroup
Target: 50% of playgroups record at least 1 game per month
Rationale: Indicates sustained usage and ongoing value beyond initial setup. If playgroups consistently record games, it shows the application has become part of their regular Commander gaming routine.