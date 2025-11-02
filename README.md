# MTG Commander Stats Tracker

A modern web application designed to help Magic: The Gathering Commander (EDH) playgroups track game statistics, analyze performance metrics, and maintain historical records of their games.

## Table of Contents

- [Overview](#overview)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
- [Available Scripts](#available-scripts)
- [Project Scope](#project-scope)

## Overview

MTG Commander Stats Tracker (internal codename: **Pure Vibes**) provides an intuitive interface for Commander playgroups to:

- **Record games** with complete details (players, commanders, turn order, results)
- **Track statistics** including win rates, commander performance, and player analytics
- **Visualize trends** with charts and data visualizations
- **Manage playgroups** with flexible member management
- **Search commanders** from a comprehensive database powered by Scryfall

### Target Audience

- Magic: The Gathering Commander playgroups (3-6 regular players)
- Players interested in performance analytics and win rate statistics
- Groups looking to move beyond manual spreadsheet tracking

### Key Features

- Email/password authentication via Supabase
- Playgroup creation and member management
- Comprehensive game recording with support for guest players
- Statistics dashboard with data visualizations
- Game history browsing
- Mobile-responsive design for tracking games at the table

## Tech Stack

| Technology | Version | Purpose |
|------------|---------|---------|
| **Astro** | v5 | Modern web framework with SSR (Node.js adapter) |
| **React** | v19 | UI library for interactive components |
| **TypeScript** | v5 | Type-safe development |
| **Tailwind CSS** | v4 | Utility-first CSS framework |
| **Shadcn/ui** | Latest | Component library (New York style) |
| **Supabase** | Latest | Backend services (authentication & database) |

### Additional Technologies

- **ESLint** - Code linting with Astro, React, and accessibility plugins
- **Prettier** - Code formatting
- **Husky** - Git hooks for automated linting and formatting
- **Scryfall API** - Commander card database source

## Getting Started

### Prerequisites

- **Node.js**: v22.14.0 (specified in `.nvmrc`)
- **npm**: Latest version
- **Supabase Account**: For authentication and database services

### Installation

1. **Clone the repository**

```bash
git clone <repository-url>
cd pure-vibes
```

2. **Install dependencies**

```bash
npm install
```

3. **Set up environment variables**

Create a `.env` file in the project root with the following variables:

```env
SUPABASE_URL=your_supabase_project_url
SUPABASE_KEY=your_supabase_anon_key
```

See `.env.example` for reference.

4. **Start the development server**

```bash
npm run dev
```

The application will be available at `http://localhost:3000`

### Using the Correct Node Version

This project uses Node.js v22.14.0. If you have `nvm` installed:

```bash
nvm use
```

## Available Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Start development server on port 3000 |
| `npm run build` | Build the application for production |
| `npm run preview` | Preview the production build locally |
| `npm run lint` | Run ESLint to check for code issues |
| `npm run lint:fix` | Automatically fix ESLint issues |
| `npm run format` | Format code with Prettier |

### Pre-commit Hooks

This project uses Husky with `lint-staged` to automatically lint and format files before commits. The following files are processed:

- **TypeScript/React files** (`.ts`, `.tsx`, `.astro`): Linted with ESLint
- **JSON, CSS, Markdown files**: Formatted with Prettier

## Project Scope

### Included in MVP

✅ **Authentication & User Management**
- Email/password authentication via Supabase
- User registration with email verification
- Password reset functionality

✅ **Playgroup Management**
- Create and manage playgroups
- In-app user search by email/username
- Add/remove members with equal permissions
- Support for guest players (non-member participants)

✅ **Game Recording**
- Record games with complete details (date, players, commanders, turn order)
- Commander search with autocomplete and card image display
- Starting and finishing order tracking
- Support for ties in finishing positions

✅ **Statistics & Analytics**
- Comprehensive all-time statistics dashboard
- Player statistics (win rates, average finishing position, best commanders)
- Commander statistics (most played, highest win rates, color distribution)
- Playgroup metrics (total games, unique commanders, activity patterns)
- Data visualizations (win rate trends, starting position analysis, games per month)

✅ **Game History**
- Browse game history with pagination
- Detailed game views with all recorded information
- Edit and delete capabilities for all members

✅ **Data Management**
- Pre-computed commander database from Scryfall

### Not Included in MVP

❌ Individual user profile pages across playgroups
❌ Individual commander detail pages
❌ Social features (comments, reactions, achievements)
❌ Role-based permissions (admin/moderator roles)
❌ Invite links for playgroup joining
❌ Date range filtering for statistics
❌ Export functionality
❌ Deck list tracking or integration
❌ Commander power level ratings
❌ Social authentication (Google, Discord, etc.)
❌ Multi-language support (English only)
❌ Mobile native apps (web-only)
❌ Offline support or PWA functionality

See the full PRD for detailed feature specifications and future considerations.