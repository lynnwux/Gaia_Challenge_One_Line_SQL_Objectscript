# Gaia DR3 Variable Star Finder — One Line of ObjectScript

InterSystems Employee Programming Challenge #1 — Code Golf submission.

Identifies all Gaia DR3 epoch photometry sources whose BP or RP flux changed by more than 100% across the observation period. The entire computation is one executable line of ObjectScript — **516 characters**.

## How It Works

The 20 Gaia DR3 epoch photometry files are pre-aggregated at load time into a single IRIS SQL table:

```
g(id BIGINT, n FLOAT, x FLOAT, p FLOAT, q FLOAT)
```

`n`/`x` are BP min/max flux, `p`/`q` are RP min/max flux. One row per star. Missing or invalid flux readings (NaN) are excluded during aggregation.

`do ^RunScript` executes a single ObjectScript line that opens a file stream, writes the CSV header, runs the SQL, streams all 57,099 results to disk, and saves — no helper classes, no logic outside the SQL engine.

```objectscript
ROUTINE RunScript
 s f=##class(%Stream.FileCharacter).%New(),f.Filename="/home/irisowner/dev/data/out/variable_objects.csv" d f.WriteLine("source_id,bp_min_flux,bp_max_flux,rp_min_flux,rp_max_flux,percentage_change") s r=##class(%SQL.Statement).%ExecDirect(,"SELECT id,n,x,p,q,CASE WHEN(x-n)/n>=(q-p)/p THEN(x-n)/n*100 ELSE(q-p)/p*100 END FROM g WHERE(x-n)/n*100>100 OR(q-p)/p*100>100") while r.%Next(){d f.WriteLine(r.%GetData(1)_","_r.%GetData(2)_","_r.%GetData(3)_","_r.%GetData(4)_","_r.%GetData(5)_","_r.%GetData(6))} d f.%Save()
```

Pre-aggregating at load time eliminates the SQL pivot entirely. The query is a direct `SELECT` with a single `CASE WHEN` to pick the larger percentage change per star, filtered to >100%.

`s`, `d`, and `w` are standard ObjectScript abbreviations for `set`, `do`, and `write` — part of the language specification.

## Output

`data/out/variable_objects.csv` — 57,099 rows plus header:

```
source_id,bp_min_flux,bp_max_flux,rp_min_flux,rp_max_flux,percentage_change
10655814178816,23.783341359526982472,157841.99293824387132,35.634526749900565789,1566.8893953334513753,663566.17941602435894
...
```

## Installation

Requirements: Docker, Docker Compose.

```bash
git clone https://github.com/lynnwux/Gaia_Challenge_One_Line_SQL_Objectscript
cd Gaia_Challenge_One_Line_SQL_Objectscript
docker compose build
docker compose up -d
```

The container pre-aggregates all 20 Gaia input files into IRIS SQL during `docker build`. This takes a few minutes on first run.

To run and generate the output CSV:

```bash
docker exec -it gaia_challenge_one_line_sql_objectscript-iris-1 iris session IRIS -U USER
```

Then at the IRIS prompt:

```
USER>do ^RunScript
```

The result is written to `data/out/variable_objects.csv` inside the container. To retrieve it:

```bash
docker cp gaia_challenge_one_line_sql_objectscript-iris-1:/home/irisowner/dev/data/out/variable_objects.csv .
```

## Feedback

IRIS made the one-liner possible. Pre-aggregating 5.6 million raw observations into 75,068 per-star min/max rows using `LOAD DATA FROM FILE` took seconds. With the heavy lifting done at load time, `%SQL.Statement.%ExecDirect` reduced the query to a single-table scan with no subqueries. `%Stream.FileCharacter` wrote the result directly to disk. The entire pipeline — ingest, aggregate, filter, output — runs inside a single IRIS session with no external processes and no dependencies beyond the standard library.
