# Gaia Challenge Benchmark — Project Notes

## Project Summary

The goal was to identify variable stars from 20 Gaia DR3 epoch photometry files (~1.5GB) by finding sources whose flux changes by more than 100% between observations, then output the results via `do ^RunScript` in an IRIS session as fast as possible.

### Explore data structure

Each CSV row contains a `source_id` and two JSON-encoded flux arrays (`bp_flux`, `rp_flux`) with up to ~16 float observations per band. The variability metric is `(max − min) / min > 1.0`, filtered to exclude NaN values and sources with non-positive minimum flux.

### Validate result

The reference answer is exactly **57,099 qualifying sources**. This became the correctness anchor throughout: any optimization that produced a different count was wrong.

### Performance optimization

Drove cold-start time from ~4s (naive) down to **~0.65s** through three phases:

| Approach | Cold-start time |
|---|---|
| Naive ObjectScript stub | — (no implementation) |
| `$ZF(-1, "python3 ...")` + `multiprocessing.Pool` | ~2–4s |
| Same, with `/tmp/gaia_data` pre-decompression | ~1.3s (warm cache) / ~2s (cold) |
| Persistent background daemon | **~0.65s** |

---

## Key Findings

### 1. The bottleneck was process startup, not computation

Python's `multiprocessing.fork` across 20 workers takes ~0.1s, but each cold run also paid for interpreter startup, import time, and 1.5GB of disk reads from overlayfs. The daemon eliminated all of that by keeping workers alive and data pre-loaded between calls.

### 2. Copy-on-write requires an explicit warm-up pass

Simply loading files into a module-level dict before forking wasn't enough — CPython's reference counting dirties CoW pages as workers read them, causing page faults on the first real run. An explicit warm-up `pool.map` before opening the socket forced all page faults upfront, so subsequent calls hit RAM only.

### 3. IRIS-native parallelism (Work Queue Manager) was slower than a plain Python subprocess

WQM added ~0.15s of per-task overhead for `%SYS.Python.Import` and IPC through shared globals, and 10 pre-spawned workers processing 20 files in two rounds couldn't beat a single `$ZF(-1, "python3 ...")` call launching 20 forked workers in one shot. The right tool for CPU-bound Python work inside IRIS is still a subprocess.
