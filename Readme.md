# LifeOS Backend

A personal life-tracking API — health, fitness, nutrition, habits, and finance, unified under one backend. Built with **Express**, **Prisma**, and **Supabase (PostgreSQL)**.

> This is the backend for the [LifeOS dashboard](#) — see `LifeOS-Backend-Feature-Spec.docx` in this repo for the full product spec, endpoint list, and architecture notes.

---

## ✨ Features (built so far)

- 🔐 **Auth** — register, login, logout, refresh tokens, password reset
- 👤 **User profile** — profile, preferences, and fitness/nutrition goals
- 🗄️ **PostgreSQL via Prisma** — auto-synced schema, no manual SQL
- 📝 **Structured logging** — every request, response, and DB query logged with daily rotation and 15-day auto-cleanup
- 🧪 **End-to-end test script** — Perl script covering every endpoint, including negative/auth-failure cases
- 📊 **Endpoint hit tracking** — live counts of how often each route is called

More modules (Health, Fitness, Nutrition, Habits, Finance, Analytics) are planned — see the Roadmap section below.

---

## 🧱 Tech Stack

| Layer | Choice |
|---|---|
| Runtime | Node.js |
| Framework | Express 5 |
| ORM | Prisma (`prisma-client-js` generator) |
| Database | PostgreSQL (Supabase, free tier) |
| Auth | JWT (access + refresh tokens), bcrypt for password hashing |
| Validation | Zod |
| Logging | Winston + winston-daily-rotate-file |

---

## 📁 Project Structure

```
Backend/
├── lib/
│   ├── prisma.js          # Shared Prisma Client instance (with query logging)
│   ├── logger.js          # Winston logger config (console + rotating files)
│   └── stats.js           # In-memory endpoint hit counter
├── middleware/
│   ├── auth.js            # requireAuth — verifies JWT, attaches req.userId
│   └── requestLogger.js   # Logs every request/response with a requestId
├── routes/
│   ├── auth.js            # /auth/register, /login, /logout, /refresh, /password-reset
│   ├── users.js            # /users/me, /users/me/preferences, /users/me/goals
│   └── admin.js            # /admin/stats — live endpoint hit counts
├── prisma/
│   └── schema.prisma       # Database schema (User, Preference, Goal, tokens...)
├── logs/                   # Auto-generated, git-ignored, self-cleaning (15-day retention)
├── .env                    # Local secrets — never committed
├── .gitignore
├── package.json
└── server.js               # App entry point
```

---

## 🚀 Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/) (v18+)
- A free [Supabase](https://supabase.com/) project (or any PostgreSQL database)

### 1. Clone & install

```bash
git clone <your-repo-url>
cd Backend
npm install
```

### 2. Configure environment variables

Create a `.env` file in the project root:

```dotenv
# Pooled connection — used for normal app queries
DATABASE_URL="postgresql://postgres.xxxx:PASSWORD@aws-x-region.pooler.supabase.com:6543/postgres?pgbouncer=true"

# Direct connection — used for schema migrations (npx prisma db push)
DIRECT_URL="postgresql://postgres.xxxx:PASSWORD@aws-x-region.pooler.supabase.com:5432/postgres"

JWT_SECRET="a-long-random-string-here"

PORT=3000
```

> Get both connection strings from Supabase: **Project Settings → Database → Connection string** (toggle between "Connection pooling" and "Direct connection").

### 3. Sync the database schema

```bash
npx prisma db push
npx prisma generate
```

This creates all tables in your Supabase database to match `prisma/schema.prisma` — no manual SQL needed. Re-run this any time you change the schema.

### 4. Start the server

```bash
npm start
```

You should see:
```
Server running on port 3000
```

---

## 🧪 Testing

An end-to-end Perl test script covers every Auth & User endpoint, including token refresh and auth-rejection cases:

```bash
perl endpoints_test.pl
```

Expected output ends with:
```
Passed: 15
Failed: 0

ALL TESTS PASSED
```

---

## 📋 API Reference

### Auth (`/auth`)

| Method | Endpoint | Purpose |
|---|---|---|
| POST | `/auth/register` | Create a new account, returns access + refresh tokens |
| POST | `/auth/login` | Authenticate, returns access + refresh tokens |
| POST | `/auth/logout` | Invalidate a refresh token |
| POST | `/auth/refresh` | Exchange a refresh token for a new access token |
| POST | `/auth/password-reset` | Request a password reset token |

### Users (`/users`)

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/users/me` | Get current user's profile |
| PATCH | `/users/me` | Update profile fields |
| GET | `/users/me/preferences` | Get currency/locale/unit preferences |
| PATCH | `/users/me/preferences` | Update preferences |
| GET | `/users/me/goals` | Get fitness/nutrition targets |
| PATCH | `/users/me/goals` | Update targets |

All `/users/*` routes require an `Authorization: Bearer <accessToken>` header.

### Admin (`/admin`)

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/admin/stats` | Live hit counts per endpoint (dev/debug only — not yet auth-protected) |

---

## 📝 Logging

Every request, response, and database query is logged with a shared `requestId` for tracing:

- **Console** — colored, human-readable, for local development
- **`logs/combined-YYYY-MM-DD.log`** — everything (info, warn, error, debug)
- **`logs/error-YYYY-MM-DD.log`** — errors only

Logs rotate daily and **auto-delete after 15 days** — no manual cleanup, no disk-space creep.

---

## 🗺️ Roadmap

Modules planned next, in build order:

1. ✅ Foundation — Auth, User profile/preferences/goals
2. ⬜ Health — weights, sleep, vitals, medications, appointments
3. ⬜ Fitness — training plans, sessions, sets
4. ⬜ Nutrition — meals, water, macro tracking
5. ⬜ Habits — habit definitions, streaks
6. ⬜ Finance — accounts, transactions, budgets, debts, investments
7. ⬜ Analytics, Calendar, Documents, Weekly Review, Search
8. ⬜ Hardening — indexing, caching, rate limiting, load testing

See `LifeOS-Backend-Feature-Spec.docx` for the complete endpoint list and performance architecture for every module above.

---

## ⚠️ Known Gotchas (learned the hard way)

- **Prisma generator:** this project uses `prisma-client-js` (not the newer `prisma-client` generator), since it outputs plain JS directly into `node_modules` — no TypeScript build step required.
- **Supabase connections:** always use the **direct** connection (port 5432, `DIRECT_URL`) for `prisma db push`/migrations — the pooled connection (port 6543) will hang on schema operations.
- **After editing schema.prisma:** always run both `npx prisma db push` (updates the DB) and `npx prisma generate` (rebuilds the client) — one without the other leads to `prisma.<model>` being `undefined`.
- **After editing server code:** fully stop (`Ctrl+C`) and restart `node server.js` — Node does not hot-reload by default.

---

## 📄 License

ISC