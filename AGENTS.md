# kdic (Social Word Dictionary) Agent Notes

## Overview
- Haskell/Yesod web application that combines a dictionary (words, meanings, examples) with SNS features (word stories/comments, likes, bookmarks, notifications).
- UI: Modern 3-column layout (Wonderful.dev style) with Dictionary.com inspired word headers.
- Build tool: Stack. Project metadata in `package.yaml`.
- DB: SQLite via Persistent; migrations in `src/Model.hs` from `config/models`.
- Templates: Hamlet/Lucius/Julius in `templates/`.
- Styling: Tailwind CSS (build config in `config/front/`).

## Key Features
- **Dictionary**: Detailed word pages with pronunciation, part of speech, definitions, and multiple examples.
- **SNS (Word Stories)**: Users can share stories or usage tips for words via a threaded comment system.
- **Interactions**: Like and bookmark words; follow other users.
- **Notifications**: Real-time alerts for interactions on shared stories.
- **Admin Panel**: Manage words, users, and site-wide settings.

## 3-Column Layout Structure
The application uses a consistent 12-column grid system (`grid-cols-12`):
- **Left (col-span-3)**: Exploration menu (Home, Trending, Notifications).
- **Center (col-span-6)**: Main content (Search results, Word details, Social feed).
- **Right (col-span-3)**: Contextual info (Popular tags, Word statistics, Daily word).

## Key Paths
- **App Core**: `app/main.hs`, `src/Application.hs`, `src/Foundation.hs`.
- **Routes**: `config/routes`.
- **Models**: `config/models` (compiled by `src/Model.hs`).
- **Handlers**: `src/Handler/` (e.g., `Word.hs`, `Home.hs`, `Admin.hs`).
- **Templates**: `templates/` (Hamlet files for HTML).
- **CSS**: `config/front/tailwind.input.css` (source), `static/css/tailwind.css` (generated).

## Runtime & Config
- **Settings**: Loaded from `config/settings.yml`, overridden by `.env` or environment variables.
- **Database**: Default at `data/kdic.sqlite3`.
- **Authentication**: Email/Password + OAuth2 (Google, Kakao, Naver).
- **Migrations**: `runMigrationUnsafe` is used in `src/Application.hs` for seamless development updates.

## Development Commands
- **Rebuild Project**: `make rebuild` (clean + build)
- **Start Server**: `make start` (runs on port 3004)
- **Fast Dev Run**: `make dev-start` (uses dev flags)
- **Tailwind Build**: `make tailwind` (Required after changing CSS classes in templates)
- **Test**: `stack test`

## Seed Data
On first run, the app:
- Ensures an admin user `ygpark2` exists (password `1234`).
- Seeds an initial word ("Yesod") with definitions and examples.

## Notes For Changes
- **CSS**: If you add new Tailwind classes to `.hamlet` files, you MUST run `make tailwind`.
- **Routes**: Define in `config/routes`, then implement in `src/Handler/`.
- **Logic**: Use `src/Import.hs` or `src/Import/NoFoundation.hs` for common imports. Note that `Word` is hidden from `ClassyPrelude` to avoid collision with the `Word` entity.
