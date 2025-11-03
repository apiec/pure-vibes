# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

10x Astro Starter - A modern, opinionated starter template for building fast, accessible, and AI-friendly web applications.

## Tech Stack

- **Astro** v5 - Modern web framework, configured for server-side rendering (SSR) with Node.js adapter
- **React** v19 - UI library for interactive components
- **TypeScript** v5 - Type-safe development
- **Tailwind CSS** v4 - Utility-first CSS framework
- **Shadcn/ui** - Component library (New York style)
- **Supabase** - Backend services for authentication and database

## Development Commands

```bash
# Development
npm run dev              # Start dev server on port 3000
npm run build            # Build for production
npm run preview          # Preview production build

# Code Quality
npm run lint             # Run ESLint
npm run lint:fix         # Fix ESLint issues automatically
npm run format           # Format code with Prettier
```

**Note**: This project uses Husky with pre-commit hooks running `lint-staged` to automatically lint and format staged files.

## Project Structure

- `src/layouts/` - Astro layouts for page templates
- `src/pages/` - Astro pages (file-based routing)
- `src/pages/api/` - API endpoints (use `export const prerender = false`)
- `src/middleware/index.ts` - Astro middleware for request/response modification
- `src/db/` - Supabase clients and types
- `src/types.ts` - Shared types for backend and frontend (Entities, DTOs)
- `src/components/` - UI components (Astro for static, React for dynamic)
- `src/components/ui/` - Shadcn/ui components
- `src/components/hooks/` - Custom React hooks
- `src/lib/` - Services and utility functions
- `src/lib/services/` - Business logic and service layer
- `src/assets/` - Internal static assets
- `public/` - Public static assets

## Architecture Guidelines

### Component Strategy

- **Use Astro components (`.astro`)** for static content and layouts
- **Use React components (`.tsx`)** only when interactivity is needed
- Never use "use client" or Next.js directives (this is Astro, not Next.js)

### API Routes

- API handlers use uppercase method names: `GET`, `POST`, etc.
- Always add `export const prerender = false` for dynamic API routes
- Use Zod for input validation
- Extract business logic into services in `src/lib/services/`
- Access Supabase via `context.locals.supabase` in routes, not by direct import

### Backend & Database

- Use Supabase from `context.locals` in Astro routes
- Use `SupabaseClient` type from `src/db/supabase.client.ts`, not from `@supabase/supabase-js`
- Validate all data exchanged with backend using Zod schemas

### Error Handling Pattern

- Handle errors and edge cases at the beginning of functions
- Use early returns to avoid deeply nested if statements
- Place the happy path last in the function
- Avoid unnecessary else statements (use if-return pattern)
- Use guard clauses for preconditions and invalid states

### React Best Practices

- Use functional components with hooks
- Extract logic into custom hooks in `src/components/hooks/`
- Use `React.memo()` for expensive components with stable props
- Use `useCallback` for event handlers passed to children
- Use `useMemo` for expensive calculations
- Use `useId()` for generating accessibility attribute IDs
- Consider `useOptimistic` for optimistic UI updates
- Use `useTransition` for non-urgent state updates

### Astro-Specific

- Leverage View Transitions API with ClientRouter for smooth page transitions
- Use content collections with type safety for structured content
- Use `Astro.cookies` for server-side cookie management
- Access environment variables via `import.meta.env`
- Implement hybrid rendering where needed

### Styling with Tailwind

- Use `@layer` directive to organize styles (components, utilities, base)
- Use arbitrary values with square brackets for one-off designs: `w-[123px]`
- Use `dark:` variant for dark mode support
- Use responsive variants: `sm:`, `md:`, `lg:`, `xl:`, etc.
- Use state variants: `hover:`, `focus-visible:`, `active:`, etc.

### Accessibility (ARIA)

- Use ARIA landmarks for page regions (main, navigation, search)
- Apply appropriate ARIA roles only for custom elements without semantic HTML equivalents
- Set `aria-expanded` and `aria-controls` for expandable content
- Use `aria-live` regions for dynamic content updates
- Avoid redundant ARIA that duplicates native HTML semantics

## Path Aliases

The project uses TypeScript path aliases configured in `tsconfig.json`:

- `@/*` maps to `./src/*`

Example usage:
```typescript
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
```

## Environment Variables

Required environment variables (see `.env.example`):

- `SUPABASE_URL` - Supabase project URL
- `SUPABASE_KEY` - Supabase anon/public key

## Configuration Files

- `astro.config.mjs` - Astro configuration (SSR mode, port 3000, Node adapter)
- `components.json` - Shadcn/ui configuration (New York style, neutral base color)
- `tsconfig.json` - TypeScript configuration with strict mode
- `eslint.config.js` - ESLint flat config with Astro, React, and accessibility plugins
- `.prettierrc.json` - Prettier configuration
