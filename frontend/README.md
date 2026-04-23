# Frontend

This directory is the incremental SvelteKit frontend for KDIC.

## Build Into Yesod Static

The frontend is built into `../static/app` and is served by Yesod at root-level app routes:

- `/`
- `/search`
- `/words/*`
- `/notifications`
- `/profile`

After changing frontend code:

```bash
npm install
npm run build
```

Then open the app through Yesod, not a separate frontend origin.

## Dev

```bash
npm install
npm run dev
```

The dev server runs on port `3904`.

Set the API origin when Yesod is running on another host or port:

```bash
cp .env.example .env
```

By default the frontend uses same-origin requests. Set `PUBLIC_KDIC_API_BASE_URL` only if you intentionally want a different backend origin.

When you run the frontend dev server on `http://localhost:3904`, Vite proxies `/api/*` requests to the local Yesod app on `http://localhost:3004`. Keep the backend running there if you want auth, profile, and word APIs to work in dev without setting `PUBLIC_KDIC_API_BASE_URL`.

## Current Pages

- `/` homepage backed by `/api/home`
- `/search` backed by `/api/search`
- `/words/[id]` backed by `/api/word/:id`
- `/notifications` backed by `/api/notifications`
- `/profile` backed by `/api/me`
