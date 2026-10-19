# How this works

The R and ggplot2 specifics worth being able to explain, and the traps that were
actually hit while writing it.

---

## 1. The stride calculation

This is the only real arithmetic in the project.

```r
strides <- rev(cumprod(rev(c(sizes[-1], 1))))
```

Dense in one line, so unpacked with the real numbers. The dimensions are
`freq, unit, vehicle, geo, time` with extents `1, 1, 4, 37, 35`.

A stride is "how far does the flat offset move when this dimension advances by
one". In a row-major layout, the last dimension moves by 1, and each earlier one
moves by the product of everything to its right.

| step | value |
|---|---|
| `sizes` | `1, 1, 4, 37, 35` |
| `sizes[-1]` — drop the **first**, not the last | `1, 4, 37, 35` |
| `c(sizes[-1], 1)` — append 1 for the innermost | `1, 4, 37, 35, 1` |
| `rev(...)` | `1, 35, 37, 4, 1` |
| `cumprod(...)` | `1, 35, 1295, 5180, 5180` |
| `rev(...)` | `5180, 5180, 1295, 35, 1` |

So `time` advances by 1, `geo` by 35, `vehicle` by `37*35 = 1295`. Correct.

**`sizes[-1]` drops the first element.** In R, a negative index means
"everything except this position" — it is not Python's "last element". Reading
it as Python gives a shifted stride vector, every label moves by one position,
and the result is a wrong chart with no error.

Decoding back is then a divide and a modulo per dimension:

```r
position <- (offsets %/% strides[[d]]) %% sizes[[which(dim_ids == d)]]
codes[[d]][position + 1L]
```

`%/%` is integer division and `%%` is modulo. The `+ 1L` is there because
JSON-stat positions are 0-based and R vectors are 1-based — the single most
likely off-by-one in the file.

## 2. Why there is a verification function

`verify_decoding()` exists because of what a stride bug looks like: the numbers
are real, the country names are real, the years are real, and the pairing
between them is wrong. Nothing raises. The chart is plausible.

So the decode is checked against the response rather than trusted:

1. Re-encode every decoded row's coordinates back to a flat offset.
2. Look up the value the response holds at that offset.
3. Assert it equals the value attached to the row.
4. Separately assert the row count equals the number of values served.

The report calls it in the setup chunk, so a broken decode **stops the render**.
This is the same instinct as a unit test, in a place where people usually do not
put one.

## 3. The factor trap

```r
per_year <- as.data.frame(table(year = cars$year))
per_year$year <- as.integer(per_year$year)        # WRONG
per_year$year <- as.integer(as.character(per_year$year))   # right
```

`table()` returns counts whose names are the values it counted.
`as.data.frame()` turns those names into a **factor**, and `stringsAsFactors =
FALSE` does not prevent it, because the column is not a string column being
converted — it comes from the table's dimnames.

`as.integer()` on a factor returns the **level index**, not the label. So the
years 1990, 1991, 1992 silently became 1, 2, 3. The x-axis still looked like a
plausible sequence, which is precisely why this is worth a comment in the code.

Going via `as.character()` first reads the label and then parses it.

## 4. The variable that shadowed a base function

A data frame was originally called `split`, and `base::split()` is used later to
group by country. R happens to forgive this: when a name is used in a call
position, R keeps looking until it finds a *function*, skipping the data frame.
So `split(trains, trains$geo)` still worked.

It was renamed to `modal` anyway. Code that depends on R's willingness to look
past a variable of the same name is code that will confuse the next reader, and
the forgiveness does not extend to `sapply(x, split)`, where `split` is in an
argument position and the data frame wins.

## 5. The ggplot2 layering

Each figure is the same four ideas.

```r
ggplot(data, aes(x = year, y = value, colour = vehicle_label)) +
  geom_line(linewidth = 0.9) +
  scale_colour_manual(values = MODE_COLOURS) +
  labs(title = ..., caption = EUROSTAT_CAPTION) +
  theme_report()
```

- **`aes()` maps columns to visual properties.** Inside `aes()`, `colour` takes
  a column name and ggplot builds a legend from its values. Outside `aes()`, as
  in `geom_col(fill = "#4C7CAE")`, it is a constant. Putting a constant inside
  `aes()` is a common mistake: ggplot treats the string as a one-level factor,
  invents a legend for it, and picks its own colour.
- **`scale_*_manual` pins the mapping.** `MODE_COLOURS` is a named vector, so
  "Passenger cars" is the same blue in every figure. Without it, ggplot assigns
  colours by factor level order, and a chart with one series missing would
  recolour the rest — implying a series changed meaning.
- **`theme_report()` is a function, not an object**, so each call returns a
  fresh theme. Defining it once keeps the gridlines, legend position and caption
  styling identical across figures, which is what makes them read as one
  document.
- **The caption carries the attribution.** Eurostat's licence requires
  acknowledgement, and a caption on the figure travels with the image if it is
  ever lifted out of the report.

### Reordering a bar chart

```r
ref <- ref[order(ref$value), ]
ref$geo_label <- factor(ref$geo_label, levels = ref$geo_label)
```

ggplot draws a discrete axis in **factor level order**, not data frame order.
Sorting the rows alone changes nothing visible. The second line rebuilds the
factor with the levels in the sorted order, which is what actually reorders the
bars. This only works because `geo_label` is unique within the slice — one row
per country.

## 6. Why not the `eurostat` package

It exists, it is good, and it would have replaced most of
`R/tidy_modal_split.R` with one call.

It is not used because the thing worth demonstrating here is reading a
statistical API and verifying the result, not calling a wrapper. With the
wrapper, the JSON-stat offset arithmetic — the part that can be wrong without
failing — is somebody else's code and there is nothing to check.

For actual work, the wrapper is the right choice.

## 7. What would break this

- **Eurostat revising the table.** The report renders from a committed snapshot
  precisely so this cannot change a figure silently. `R/fetch_eurostat.R` prints
  the new hash so the change is a decision rather than an accident.
- **A new `geo` code that is two letters but not a country.** Aggregates are
  identified by *not* matching `^[A-Z]{2}$`. That holds for `EU27_2020`, `EU28`
  and the euro-area codes, but it is a heuristic about the shape of a string,
  not a lookup against Eurostat's own classification.
- **A dimension order change in the response.** The strides are computed from
  `$id` and `$size` as served, not hardcoded, so a reordering is handled. A
  dimension being *added* would change the arity and need the `modal_split`
  filter revisiting.
