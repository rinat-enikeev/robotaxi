# Robotaxi

Robotaxi is a SvelteKit application that curates global coverage of autonomous taxi operators, ridehailing platforms, and their university partners. It combines a statically generated marketing site, API routes backed by Supabase, and a data pipeline driven by YAML sources and reproducible SQL seeds.

The goal of the project is to provide a single hub for exploring where robotaxi pilots are active, which companies operate them, and how those operations connect to academic research.

## Highlights

- Static marketing page with pre-rendered content and client-side interactivity.
- Supabase-backed REST endpoints for robotaxis, ridehailings, and universities.
- Deck.gl and MapLibre visualisations powered by curated global geodata.
- YAML source files with scripts that regenerate database seeds deterministically.
- Continuous formatting, linting, and type-safe Svelte components.

## Project Structure

```
robotaxi/
├─ data/               # YAML source of truth for cities, operators, universities
├─ scripts/            # Helpers that convert YAML into Supabase SQL seeds
├─ src/
│  ├─ routes/          # SvelteKit pages and API endpoints
│  ├─ hooks.server.ts  # Supabase client wiring and session guard
│  └─ lib/             # Supporting utilities
├─ supabase/           # Local Supabase config, migrations, seeds, tests
└─ static/             # GeoJSON, images, and other static assets
```

Refer to `data/README.md` for contributor rules and dataset-specific guidance.

## Getting Started

### Prerequisites

- Node.js 18+ (use `nvm use` if you manage multiple versions).
- npm 9+ (ships with recent Node releases).
- Supabase CLI for running the database locally (`brew install supabase/tap/supabase`).
- Python 3.10+ if you plan to regenerate SQL seeds (requires `pyyaml`).

### Installation

```bash
git clone https://github.com/<your-org>/robotaxi.git
cd robotaxi
npm install
```

Create a `.env` file at the project root with your Supabase credentials:

```
PUBLIC_SUPABASE_URL=<https://your-project.supabase.co>
PUBLIC_SUPABASE_ANON_KEY=<anon-key>
PRIVATE_SUPABASE_SERVICE_ROLE=<service-role-key>
```

For local development with the Supabase CLI:

```bash
supabase start          # boots the local Postgres, API, and Studio
supabase status         # confirm services are healthy
```

After the services are up, seed the database:

```bash
make
supabase db reset
```

Then launch the app:

```bash
npm run dev
```

Visit `http://localhost:5173` to explore the site.

## Working With Data

All canonical data lives in YAML files under `data/`. To regenerate SQL after editing a dataset, run the corresponding script:

```bash
./scripts/generate_cities_seed.sh
./scripts/generate_robotaxis_seed.sh
./scripts/generate_ridehailings_seed.sh
./scripts/generate_operations_seed.sh
./scripts/generate_universities_seed.sh
```

Only execute the scripts for the files you changed. They validate required fields and write updated SQL to `supabase/seeds/`. Supabase database migrations live in `supabase/migrations/`; add new migrations when the schema changes.

## Available Scripts

- `npm run dev` – start the Vite dev server with hot module replacement.
- `npm run build` – generate the production build.
- `npm run preview` – preview the production build locally.
- `npm run check` – SvelteKit sync + `svelte-check` for type safety.
- `npm run lint` – run ESLint across the repo.
- `npm run format` / `format_check` – format Svelte and TS files with Prettier.
- `npm run test` – execute unit tests with Vitest.

The `checks.sh` helper runs the common lint + type + test suite in one command.

## Testing and QA

Supabase SQL tests live under `supabase/tests/` and can be executed with:

```bash
supabase test db
```

Vitest is used for frontend/unit coverage. Keep tests colocated with the code they validate and aim for deterministic inputs derived from the seeded datasets.

## Deployment

- Static pages are pre-rendered at build time via SvelteKit.
- Server routes rely on the Supabase PostgREST endpoint configured in `hooks.server.ts`.
- CI formatting rules live in `.github/workflows/format.yml`. Extend workflows as needed for linting, testing, or deployments.

A production deployment typically consists of:

1. Running `npm run build` to produce the SvelteKit output (`.svelte-kit`).
2. Applying new Supabase migrations (`supabase db push`) and seeding data.
3. Publishing the generated build to your hosting provider (e.g. Vercel, Cloudflare Pages, Netlify).

## Contributing

1. Create a feature branch.
2. Update YAML datasets and regenerate relevant seeds.
3. Run `npm run format`, `npm run lint`, `npm run check`, and `npm run test`.
4. Verify Supabase migrations and seeds are included in your diff.
5. Submit a pull request describing the data source and validation steps.

## License

This project is distributed under the terms of the MIT License. See `LICENSE` for details.
