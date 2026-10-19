#' Turn Eurostat's JSON-stat response into a tidy data frame.
#'
#' Eurostat serves JSON-stat 2.0: one flat named vector of values, plus the
#' dimensions needed to work out what each position means. There is no row per
#' observation, so the shape has to be reconstructed. Doing that by hand rather
#' than with the `eurostat` package is the point here - the index arithmetic is
#' where this format is easy to get silently wrong, and getting it wrong
#' produces a plausible plot of mislabelled numbers rather than an error.
#'
#' The flat key is a row-major offset over the dimensions in the order given by
#' `$id`, with extents `$size`. For dimensions (d1 ... dn) and 0-based
#' coordinates (i1 ... in):
#'
#'   offset = i1 * (s2 * s3 * ... * sn) + i2 * (s3 * ... * sn) + ... + in
#'
#' Sparse by design: combinations with no observation are simply absent from
#' `$value`, which is why the result is built by walking the keys that exist
#' rather than by expanding the full grid and joining.

library(jsonlite)

#' @param path path to the saved JSON-stat response
#' @return a data frame with one row per observation
read_jsonstat <- function(path) {
  raw <- jsonlite::fromJSON(path, simplifyVector = FALSE)

  dim_ids <- unlist(raw$id)
  sizes <- unlist(raw$size)

  # Strides, right to left: the last dimension advances by 1, each earlier one
  # by the product of all the sizes to its right.
  strides <- rev(cumprod(rev(c(sizes[-1], 1))))
  names(strides) <- dim_ids

  # For each dimension, the category codes in index order. Eurostat gives an
  # index as a named list of code -> position, and the positions are 0-based.
  codes <- lapply(dim_ids, function(d) {
    index <- raw$dimension[[d]]$category$index
    if (is.list(index)) {
      positions <- unlist(index)
      names(sort(positions))
    } else {
      unlist(index)
    }
  })
  names(codes) <- dim_ids

  labels <- lapply(dim_ids, function(d) {
    lab <- raw$dimension[[d]]$category$label
    if (is.null(lab)) NULL else unlist(lab)
  })
  names(labels) <- dim_ids

  offsets <- as.integer(names(raw$value))
  values <- unlist(raw$value, use.names = FALSE)

  # Decode each offset back into one coordinate per dimension by dividing out
  # the strides, largest first.
  decoded <- vapply(
    dim_ids,
    function(d) {
      position <- (offsets %/% strides[[d]]) %% sizes[[which(dim_ids == d)]]
      codes[[d]][position + 1L]
    },
    character(length(offsets))
  )

  frame <- as.data.frame(decoded, stringsAsFactors = FALSE)
  names(frame) <- dim_ids
  frame$value <- values

  attr(frame, "labels") <- labels
  attr(frame, "updated") <- raw$updated
  attr(frame, "dataset_label") <- raw$label
  frame
}

#' Check the decoding against the response rather than trusting it.
#'
#' Two independent facts are asserted: the number of observations recovered
#' equals the number of values served, and a value looked up by its decoded
#' coordinates is the value at that offset. An off-by-one in the stride
#' arithmetic shifts every label by one position and would otherwise pass
#' unnoticed, because the resulting plot still looks reasonable.
verify_decoding <- function(frame, path) {
  raw <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  dim_ids <- unlist(raw$id)
  sizes <- unlist(raw$size)
  strides <- rev(cumprod(rev(c(sizes[-1], 1))))
  names(strides) <- dim_ids

  stopifnot(nrow(frame) == length(raw$value))

  codes <- lapply(dim_ids, function(d) {
    index <- raw$dimension[[d]]$category$index
    if (is.list(index)) names(sort(unlist(index))) else unlist(index)
  })
  names(codes) <- dim_ids

  # Re-encode every row's coordinates back to an offset and compare against the
  # value the response holds there.
  recomputed <- rep(0L, nrow(frame))
  for (d in dim_ids) {
    position <- match(frame[[d]], codes[[d]]) - 1L
    recomputed <- recomputed + position * strides[[d]]
  }

  served <- unlist(raw$value[as.character(recomputed)], use.names = FALSE)
  stopifnot(identical(served, frame$value))

  invisible(TRUE)
}

#' Modal split as percentages, countries only, with readable vehicle names.
#'
#' Aggregates (EU27_2020, EU28, EA19 and friends) are kept but flagged, because
#' a chart that silently mixes "Germany" and "the EU average" as if they were
#' the same kind of row is a chart that misleads.
modal_split <- function(frame) {
  labels <- attr(frame, "labels")

  keep <- c("CAR", "TRN", "BUS_TOT")
  out <- frame[frame$vehicle %in% keep & frame$unit == "PC", ]

  out$vehicle_label <- unname(labels$vehicle[out$vehicle])
  out$geo_label <- unname(labels$geo[out$geo])
  out$year <- as.integer(out$time)

  # Eurostat aggregate codes are the ones that are not two-letter country
  # codes. EU27_2020 and EU28 are both present in this dataset.
  out$is_aggregate <- !grepl("^[A-Z]{2}$", out$geo)

  out <- out[order(out$geo, out$vehicle, out$year), ]
  rownames(out) <- NULL
  out[, c(
    "geo", "geo_label", "is_aggregate", "vehicle", "vehicle_label",
    "year", "value"
  )]
}
