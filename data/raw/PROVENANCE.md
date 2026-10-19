# Where this data came from

One file, committed as served. The report renders from this snapshot and never
from the network, so a figure cannot change because an upstream table was
revised between renders.

## tran_hv_psmod.json

| | |
|---|---|
| Dataset | Modal split of inland passenger transport |
| Eurostat code | `tran_hv_psmod` |
| Source | Eurostat (ESTAT) |
| Request | `https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/tran_hv_psmod?format=JSON&lang=EN` |
| Format | JSON-stat 2.0 |
| Data last published upstream | 2026-08-26 |
| Downloaded | 2026-10-18 |
| Size | 90,761 bytes |
| SHA-256 | `eee898d1bc29443c469dd804fd23a236d296610b1e23e3d8ec1508ace9947220` |

### Licence

Eurostat's dissemination data is reusable under the European Commission's reuse
policy, **Commission Decision 2011/833/EU**, which permits reuse for commercial
and non-commercial purposes provided the source is acknowledged. Eurostat states
the terms at <https://ec.europa.eu/eurostat/about-us/policies/copyright>.

Required acknowledgement, which appears on every figure in the report:

> Source: Eurostat, Modal split of inland passenger transport (tran_hv_psmod).

Eurostat does not hold copyright in the underlying national statistics and the
reuse notice does not extend to any third-party material; none is used here.

### Shape of the response

Five dimensions, in the order the response's own `id` field gives:

| Dimension | Extent | Contents |
|---|---|---|
| `freq` | 1 | `A`, annual |
| `unit` | 1 | `PC`, percent |
| `vehicle` | 4 | `CAR`, `TRN`, `BUS_TOT`, and `TRN_BUS_TOT_AVD` (a sum of available data) |
| `geo` | 37 | 35 reporting countries plus the `EU27_2020` and `EU28` aggregates |
| `time` | 35 | 1990 to 2024 |

That is 5,180 possible cells, but the response is **sparse**: it carries
**4,538 observations**, and combinations with no observation are absent from
`value` rather than present as null. The report therefore builds its table from
the keys that exist, and charts the reporting coverage before charting any trend.

The stride arithmetic `read_jsonstat()` uses was checked against this file
independently of the R code: decoding all 4,538 offsets and re-encoding them from
their coordinates reproduces every original offset, with no mismatches. That is
the same property `verify_decoding()` asserts at render time.

`TRN_BUS_TOT_AVD` is excluded from the analysis. It is a partial sum rather than
a mode, so including it alongside `CAR`, `TRN` and `BUS_TOT` would double-count.

### Re-fetching it

`R/fetch_eurostat.R` downloads the same URL, writes the file, and prints the
SHA-256 so it can be compared against the table above. A different hash means
Eurostat has revised the table; that is a thing to look at deliberately, not to
overwrite silently, because every number in the rendered report comes from this
snapshot.
