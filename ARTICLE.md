# SQL Golden Tee Golf: I Built a Game Where an AI Caddie Roasts Your Queries

*An InterSystems employee programming challenge, a telescope's worth of star data, and one very judgmental 16-year-old.*

---

## Before we get started, let me introduce my caddy.

Every golfer needs a caddy. And apparently, every SQL developer deserves one too.

Meet Jayden.

He's 16, chronically online, communicates primarily through sarcasm, and firmly believes every bug is a skill issue.

But he is actually a very good caddy.

Here's how this works.

We've turned a SQL challenge into a round of mini golf. You have one problem to solve and **nine shots** — nine attempts to write the right query.

After every shot, Jayden shows up.

He will judge you.

He will roast your SQL.

But buried somewhere in the Gen Z commentary is a genuinely useful hint — just enough to get you closer without giving away the answer.

And Jayden does want you to succeed. Partly because he's a professional. Partly because he wants a tip. He's 16, but this is America, so apparently it's never too early to start planning for future healthcare costs.

So let's play.

You write a query. You take a shot.

If you miss, Jayden tells you *how* you missed.

Maybe you mixed the bands. Maybe you forgot to deduplicate. Maybe your 100% variation is... mathematically creative.

Nine shots. One SQL challenge. One increasingly judgmental caddy.

And if we finally sink the putt and return exactly **57,099 stars**, Jayden will act like he knew we'd get there the entire time.

Then he'll point to the next hole and say:

*"Alright, SQL Tiger Woods... let's see if that last one was luck."*

---

## The Dataset

This started as the InterSystems Employee Programming Challenge #1 — find variable stars in Gaia DR3 epoch photometry data. The European Space Agency's Gaia mission spent years measuring the brightness of over a billion stars, and the DR3 release includes raw time-series flux data: one row per observation, per star, per photometer.

The table is simple:

```sql
g(id BIGINT, b TINYINT, f FLOAT)
```

- `id` — Gaia source ID, the star's unique identifier
- `b` — photometer band: `0` = BP (blue), `1` = RP (red)  
- `f` — flux in electrons/second for this one observation

5,668,090 rows total. Twenty gzipped CSV files decompressed and loaded at build time via IRIS Embedded Python and `LOAD DATA FROM FILE`.

The goal: find every star whose flux changed by more than 100% in either band. Formally — within each `(id, b)` group, did `MAX(f) > 2 * MIN(f)`?

Target answer: exactly **57,099 stars**.

---

## There Is a Trap

Real telescope data is messy. Not every reading is a real reading. The dataset contains observations that are technically there, technically non-null, and technically capable of making a star look extremely variable — when in reality something went wrong at the detector level.

That's all we'll say about that.

Jayden knows the rest. He won't tell you upfront — that would be terrible caddie behavior. But he'll know the moment you land in it.

Par is 88 characters — set by the best solution we know today. Fair warning: this isn't putt-putt. It's SQL at Augusta National. Most players won't shoot par, and that's by design. Match it, and you've written one of the tightest known solutions to this problem. Beat it, and you've set a new course record — something nobody has managed yet. We're not sure it's possible. Prove us wrong.

---

## How Jayden Works

Jayden is built on **IRIS AI Hub** — the AI orchestration layer in InterSystems IRIS 2026.1+.

```objectscript
Class GAIA.SqlJudge Extends %AI.Agent
{
    XData INSTRUCTIONS
    {
        You are a veteran golf caddie who moonlights as a SQL wizard —
        snarky, Gen Z, deeply invested in this round...
    }
}
```

The `%AI.Agent` base class handles session management, prompt assembly, and response streaming. The caddie's entire personality — the golf metaphors, the Gen Z slang, the specific knowledge of the 70,688 trap, the rules for what to say when you're correct vs. wrong vs. over par — lives in one `XData INSTRUCTIONS` block.

The backend is Amazon Bedrock via `%AI.Provider`:

```objectscript
Set provider = ##class(%AI.Provider).Create("bedrock", {
    "region": "us-east-1",
    "bearer_token": (tok)
})
Set agent = ##class(%AI.Agent).%New(provider)
Set agent.Model = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
```

`%AI.Provider` is IRIS AI Hub's abstraction over AI backends. Swapping Bedrock for any other supported provider is a one-line change. The bearer token comes from a runtime environment variable — never stored in the repository or image.

Every shot triggers a `quick` judgment: 2-3 sentences, immediate feedback, one targeted hint. After nine holes, Jayden delivers a full round report. If you never got the right answer, the spoiler drops: he quotes the reference solution and explains why it works. If you got it but went over par, he tells you the door is open to come back and go lower — then quotes the reference anyway, because respecting par is a lifestyle.

---

## The Architecture

The game runs on a single IRIS instance inside a Docker container deployed to Fly.io.

**Data loading** happens at build time. An Embedded Python script decompresses the Gaia CSV files, parses the flux arrays out of the raw JSON columns, and writes a flat CSV that IRIS `LOAD DATA FROM FILE` ingests into table `g` in the USER database. The resulting `IRIS.DAT` is 182MB — pre-loaded, indexed, ready to query the moment the container starts.

**The REST API** (`GAIA.API extends %CSP.REST`) handles four routes:
- `/api/schema` — table description and goal
- `/api/preview` — top 20 rows
- `/api/run` — execute the player's SQL, verify against the reference answer, return count + correctness + character gap
- `/api/judge` — call Jayden

**Correctness verification** isn't just a count check. The `/api/run` handler intersects the player's result set with the reference answer set:

```objectscript
Set refSQL = "SELECT DISTINCT id FROM(SELECT id FROM g WHERE f>0 GROUP BY id,b HAVING MAX(f)>2*MIN(f))"
Set checkSQL = "SELECT COUNT(*) FROM ("_sql_") u JOIN ("_refSQL_") r ON u.id=r.id"
```

Both the count and the exact ID set must match. You can't game it by returning 57,099 wrong stars.

**Startup persistence** was the hardest engineering problem. IRIS reinitializes its security database (`irissecurity`) on every cold start — wiping any CSP application registrations written at build time. The fix is `%ZSTART`, an IRIS routine that runs automatically after every full initialization:

```objectscript
%ZSTART
 new $namespace
 set $namespace="USER"
 do ##class(GAIA.Setup).Run()
 quit
```

`GAIA.Setup.Run()` deletes and re-creates the `/api` and `/app` CSP applications with the correct authentication settings (`AutheEnabled=64` for unauthenticated public access). This runs on every cold start, after `irissecurity` has been reinitialized, so the registrations are always fresh.

---

## Play It

The game is live at **[gaia-sql-golden-tee.fly.dev/app/index.html](https://gaia-sql-golden-tee.fly.dev/app/index.html)**.

Nine holes. Par 88. One AI caddie with a lot of opinions.

Par is set by the best solution we know today. Match it and you've written one of the tightest known SQL solutions to this problem. Beat it and you've just set a new course record — nobody has done it yet.

Jayden is waiting.

---

*Built with InterSystems IRIS 2026.2 AI Edition, IRIS AI Hub (`%AI.Agent`, `%AI.Provider`), Embedded Python, and real Gaia DR3 data from the European Space Agency. Source: [github.com/lynnwux/Gaia_Challenge_SQL_Golden_Tee](https://github.com/lynnwux/Gaia_Challenge_SQL_Golden_Tee).*
