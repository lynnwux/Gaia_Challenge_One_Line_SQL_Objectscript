# SQL Golden Tee Golf ⛳

InterSystems Employee Programming Challenge #1 — SQL game submission.

Play 9 holes of SQL golf against real Gaia DR3 epoch photometry data. Find the variable stars in as few characters as possible, with a snarky Gen Z caddie powered by **IRIS AI Hub** roasting every shot.

**[▶ Play it live →](https://gaia-sql-golden-tee.fly.dev/app/index.html)**

## The Challenge

Table `g(id BIGINT, b TINYINT, f FLOAT)` — 5.6 million flux observations from 20 Gaia DR3 files.

- `b=0` = BP (blue photometer), `b=1` = RP (red photometer)
- One row per observation. Invalid readings stored as `f=0` (detector noise).

**Goal:** Find every distinct star ID where flux varies by more than 100% in either band — meaning `MAX(f) > 2*MIN(f)` within a star+band group.

**Target:** exactly **57,099 stars**. **Par:** 88 characters.

## How to Play

Open the web app, write SQL in the editor, and hit Swing. You get 9 holes. Each hole scores your character count against par 88. After every shot the AI caddie drops a roast. After 9 holes the caddie delivers a full round report — and if you never got correct, the spoiler drops.

The caddie knows the classic trap: without `f>0`, the answer inflates to exactly 70,688. That's the detector-noise hazard. The filter isn't optional — it's load-bearing.

Reference solution (par): `SELECT DISTINCT id FROM(SELECT id FROM g WHERE f>0 GROUP BY id,b HAVING MAX(f)>2*MIN(f))`

## IRIS AI Hub

The AI caddie is built on **IRIS AI Hub** — the AI orchestration layer in IRIS 2026.1+:

- **`GAIA.SqlJudge`** extends `%AI.Agent` — the IRIS AI Hub agent class. Its caddie persona lives in an `XData INSTRUCTIONS` block (golf metaphors, Gen Z slang, knowledge of the 70,688 trap, and per-outcome response rules).
- **`%AI.Provider.Create("bedrock", ...)`** — IRIS AI Hub's provider abstraction. `"bedrock"` is the configured backend (Amazon Bedrock); swapping to any other `%AI.Provider`-compatible backend requires only changing this one call.
- The `BEDROCK_BEARER_TOKEN` environment variable carries the Bedrock API key. It is injected at runtime as a secret and is **never stored in the repository or image**.

The public hosted version runs with a pre-configured key. Self-hosted clones need to supply their own.

## Stack

- **IRIS SQL** — `LOAD DATA FROM FILE` ingests 5.6M rows at build time
- **Embedded Python** (`%SYS.Python.Run`) — parses and pre-aggregates the 20 gzipped Gaia CSVs
- **`%CSP.REST`** (`GAIA.API`) — `/api/run`, `/api/judge`, `/api/preview`, `/api/schema`
- **`%AI.Agent`** / **`%AI.Provider`** (`GAIA.SqlJudge`) — IRIS AI Hub, Bedrock backend
- **Static HTML** (`/app`) — SQL editor, scorecard, spoiler block, hosted from IRIS CSP

## Run It Yourself

Requirements: Docker, IRIS 2026.2 AI Edition image, Amazon Bedrock access.

```bash
git clone https://github.com/lynnwux/Gaia_Challenge_SQL_Golden_Tee
cd Gaia_Challenge_SQL_Golden_Tee
echo "BEDROCK_BEARER_TOKEN=your_key_here" > .env
docker compose up
```

The container decompresses and loads all Gaia data during `docker build`. Open `http://localhost:8080/app/index.html`.

Without `BEDROCK_BEARER_TOKEN`, the game still runs — the caddie just stays quiet.
