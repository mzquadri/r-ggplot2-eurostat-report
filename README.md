# Modal split of inland passenger transport, in R

A Quarto report built with ggplot2 on an official Eurostat table: the share of
inland passenger travel taken by car, by train, and by bus, across the EU from
1990 onwards.

Built with AI assistance (Claude Code).

Every number in the prose is computed from the data at render time rather than
typed in, so the text cannot drift away from the figures. The raw API response
is committed, so the report renders offline and reproducibly.

## Run it

Needs R and Quarto.

```bash
quarto render report.qmd
```

Or without installing either, using the pinned image in this repository
(R 4.4.2, Quarto 1.6.39). The `quarto-cli` image on its own is not enough: it
ships no R, and `quarto render` stops with "The knitr package is not available
in this R installation".

```bash
docker build -t r-eurostat .
docker run --rm -v "$PWD":/report -w /report r-eurostat quarto render report.qmd
```

Packages: `jsonlite` for the API response, `ggplot2` for the figures. Nothing
else — in particular **not** the `eurostat` package, deliberately. Decoding
JSON-stat by hand is the part of this worth showing; see below.

Output: a single self-contained `report.html`. `embed-resources: true` inlines
the figures and the CSS, so the file can be opened or sent on its own with no
accompanying directory.

## What it found

Every figure below is computed at render time; none is typed into the prose.

- The snapshot covers **35 countries**, **1990 to 2024**, and reporting peaks at
  **35 countries in 2010**. The single-year comparisons use **2024**, the most
  recent year holding at least 90% of that peak.
- **The EU car share has barely moved.** For the `EU27_2020` aggregate it was
  **82.0% in 2000** and **82.5% in 2024**, a change of **+0.5 percentage
  points** over 24 years.
- In 2024 the spread across countries is **30.9 percentage points**, from
  **97.8% (Montenegro)** down to **66.9% (Hungary)**. **Germany sits at 84.1%,
  ranking 12 of 34.**
- Rail gained share in **14 of 32** countries. The largest gain is
  **Switzerland, up 7.3 percentage points** between its own first and last
  reported year.

The EU-level flatness is the point worth sitting with: whatever has changed in
European transport policy since 2000, it has not changed what share of distance
is driven.

## The data

Eurostat `tran_hv_psmod`, "Modal split of inland passenger transport", retrieved
2026-10-18 and committed at `data/raw/tran_hv_psmod.json`, SHA-256
`eee898d1bc29443c469dd804fd23a236d296610b1e23e3d8ec1508ace9947220`.

CI recomputes that digest and fails if it no longer matches this README and
`PROVENANCE.md`, so the snapshot, the prose and the figures cannot drift apart.

Full provenance, the exact request URL, the licence and the response's shape are
in [`data/raw/PROVENANCE.md`](data/raw/PROVENANCE.md).

Licence: reusable under **Commission Decision 2011/833/EU**, the European
Commission's reuse policy, with acknowledgement of the source. The required
acknowledgement appears as a caption on every figure.

## Decoding JSON-stat, and why it is done by hand

Eurostat serves JSON-stat 2.0. There is no row per observation: there is one
flat object of values keyed by integer offset, plus the dimension metadata
needed to work out what each offset means.

```
"size": [1, 1, 4, 37, 35]         # freq, unit, vehicle, geo, time
"value": { "4620": 11.0, "4621": 10.6, ... }
```

The key is a row-major offset over the dimensions in the order the response's
own `id` field gives. For coordinates `(i1 ... in)` and extents `(s1 ... sn)`:

```
offset = i1*(s2*s3*...*sn) + i2*(s3*...*sn) + ... + in
```

`R/tidy_modal_split.R` computes the strides, decodes every offset back into one
coordinate per dimension, and attaches the human-readable labels.

**This arithmetic is where the format is easy to get silently wrong.** An
off-by-one in a stride shifts every label by one position: the numbers are all
real, the countries are all real, and the chart is entirely wrong while looking
completely plausible. There is no error to notice.

So `verify_decoding()` re-encodes each decoded row's coordinates back to an
offset and checks the value the response holds there, then asserts the row count
equals the number of values served. The report calls it in its setup chunk, so a
broken decode **stops the render** rather than producing a convincing figure.

The response is also **sparse**: combinations with no observation are absent
rather than null, so the table is built from the keys that exist instead of by
expanding the full grid. 5,180 cells are possible; far fewer are served.

## Three things the report is careful about

These are the reasons the report is longer than four charts.

**Coverage is charted before any trend.** Countries enter the series at
different dates, so a line chart over the raw data invites the reader to
interpolate through years nobody measured. The first figure is simply how many
countries reported in each year, and the single-year comparisons use the most
recent year with at least 90% of peak coverage rather than the latest year
present — which would compare a handful of early reporters against each other.

**Unequal windows are labelled, not hidden.** The rail-change figure uses each
country's own first and last reported year, because a fixed window would discard
most of the 2004 and 2007 accession states. The chart says so, since a country
reporting since 2010 is not comparable with one reporting since 1990.

**Aggregates are kept separate from countries.** `EU27_2020` and `EU28` are in
the same `geo` dimension as Germany. `modal_split()` flags them, and no figure
mixes an aggregate into a ranking of countries.

**Shares are not volumes.** The three modes sum to 100% by construction, so this
measures how people travel and not how much. A falling car share is consistent
with more driving if rail grew faster. The report states this rather than
implying a trend it cannot support, and makes no causal claim about policy.

## Layout

```
R/tidy_modal_split.R   read_jsonstat, verify_decoding, modal_split
R/fetch_eurostat.R     re-download the snapshot and print its SHA-256
report.qmd             the report
report.html            the rendered output, self-contained
Dockerfile             pinned R 4.4.2 and Quarto 1.6.39
data/raw/              the committed API response and its provenance
```

See [LEARNING.md](LEARNING.md) for the R specifics worth knowing: why
`as.integer()` on a factor is a trap, what `cumprod`/`rev` are doing in the
stride calculation, and how the ggplot2 layering works.
