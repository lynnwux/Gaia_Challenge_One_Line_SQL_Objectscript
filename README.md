# Gaia DR3 Variable Star Finder — One Line of ObjectScript

InterSystems Employee Programming Challenge #1 — Code Golf submission.

Identifies all Gaia DR3 epoch photometry sources whose BP or RP flux changed by more than 100% across the observation period. The entire computation is one executable line of ObjectScript.

## How It Works

The 20 Gaia DR3 epoch photometry files are flattened into a single IRIS SQL table:

```
g(id BIGINT, b TINYINT, f FLOAT)
```

`b=0` is the BP band, `b=1` is the RP band. One row per observation. Missing or invalid flux readings are stored as SQL NULL and are ignored by aggregate functions automatically.

`do ^RunScript` executes a single ObjectScript line that opens a file stream, writes the CSV header, runs the SQL, streams all 57,099 results to disk, and saves — no helper classes, no logic outside the SQL engine.

```objectscript
ROUTINE RunScript
 s f=##class(%Stream.FileCharacter).%New(),f.Filename="/home/irisowner/dev/data/out/variable_objects.csv" d f.WriteLine("source_id,bp_min_flux,bp_max_flux,rp_min_flux,rp_max_flux,percentage_change") s r=##class(%SQL.Statement).%ExecDirect(,"SELECT source_id,bp_min_flux,bp_max_flux,rp_min_flux,rp_max_flux,CASE WHEN (bp_max_flux-bp_min_flux)/bp_min_flux>=(rp_max_flux-rp_min_flux)/rp_min_flux THEN (bp_max_flux-bp_min_flux)/bp_min_flux*100 ELSE (rp_max_flux-rp_min_flux)/rp_min_flux*100 END percentage_change FROM(SELECT id source_id,MIN(CASE WHEN b=0 THEN f END) bp_min_flux,MAX(CASE WHEN b=0 THEN f END) bp_max_flux,MIN(CASE WHEN b=1 THEN f END) rp_min_flux,MAX(CASE WHEN b=1 THEN f END) rp_max_flux FROM g GROUP BY id)WHERE(bp_max_flux-bp_min_flux)/bp_min_flux*100>100 OR(rp_max_flux-rp_min_flux)/rp_min_flux*100>100") while r.%Next(){d f.WriteLine(r.%GetData(1)_","_r.%GetData(2)_","_r.%GetData(3)_","_r.%GetData(4)_","_r.%GetData(5)_","_r.%GetData(6))} d f.%Save()
```

The SQL is a two-layer pivot. The inner query uses `CASE WHEN b=0/1` to split BP and RP into separate columns within a single `GROUP BY id`. The outer query computes `(max-min)/min*100` per band and reports the larger value as `percentage_change`, filtering to >100%.

`s` and `d` are standard ObjectScript abbreviations for `set` and `do` — part of the language specification.

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
docker compose up
```

The container decompresses the 20 Gaia input files and loads them into IRIS SQL on first start.

To run and generate the output CSV:

```bash
docker exec -it <container_name> iris session IRIS -U USER
do ^RunScript
```

The result is written to `data/out/variable_objects.csv`.

## Feedback

IRIS made the one-liner possible. `LOAD DATA FROM FILE` ingested 5.6 million rows in seconds. `%SQL.Statement.%ExecDirect` executed the pivot query and returned a streaming result set. `%Stream.FileCharacter` wrote it directly to disk. The entire pipeline — ingest, aggregate, filter, output — runs inside a single IRIS session with no external processes, no network hops, and no dependencies beyond the standard library.

The `CASE WHEN` pivot pattern for splitting the flat `(id, band, flux)` table into per-band columns is what kept the SQL self-contained. It turned a multi-step transformation into a single pass the query optimizer could handle end to end.
