#' Re-download the Eurostat snapshot and report its SHA-256.
#'
#' The report never calls this. It renders from the committed file in
#' data/raw/, so that a figure cannot change because an upstream table was
#' revised between two renders.
#'
#' Run it when a refresh is actually wanted, and compare the printed hash
#' against data/raw/PROVENANCE.md. A different hash means Eurostat has revised
#' the table, which is a thing to look at deliberately: every number in the
#' rendered report comes from this file, so replacing it silently changes the
#' prose as well as the charts.
#'
#'   Rscript R/fetch_eurostat.R
#'
#' Writes to a temporary file first and only then moves it into place, so an
#' interrupted download cannot leave a truncated JSON where a valid one was.

DATASET <- "tran_hv_psmod"
BASE <- "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data"
URL <- paste0(BASE, "/", DATASET, "?format=JSON&lang=EN")
DESTINATION <- file.path("data", "raw", paste0(DATASET, ".json"))

fetch_eurostat <- function(url = URL, destination = DESTINATION) {
  stopifnot(requireNamespace("jsonlite", quietly = TRUE))

  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  temporary <- paste0(destination, ".part")

  message("GET ", url)
  # mode = "wb" matters on Windows: the default text mode rewrites line endings,
  # which changes the bytes and therefore the hash of a file whose whole purpose
  # is to be hash-checked.
  utils::download.file(url, destination = temporary, mode = "wb", quiet = TRUE)

  # Parse before committing the file. A 200 response carrying an error document
  # would otherwise be saved as though it were data.
  parsed <- jsonlite::fromJSON(temporary, simplifyVector = FALSE)
  if (is.null(parsed$value) || length(parsed$value) == 0) {
    unlink(temporary)
    stop("the response carried no values; not overwriting ", destination)
  }

  file.rename(temporary, destination)

  digest <- NULL
  if (requireNamespace("openssl", quietly = TRUE)) {
    digest <- paste(openssl::sha256(file(destination, open = "rb")), collapse = "")
  } else if (nzchar(Sys.which("sha256sum"))) {
    digest <- sub(" .*", "", system2("sha256sum", shQuote(destination), stdout = TRUE))
  }

  message("wrote ", destination, " (", file.size(destination), " bytes)")
  message("label: ", parsed$label)
  message("upstream updated: ", parsed$updated)
  message("observations: ", length(parsed$value))
  if (is.null(digest)) {
    message("sha256: unavailable (install the openssl package to print it)")
  } else {
    message("sha256: ", digest)
  }

  invisible(destination)
}

if (identical(environment(), globalenv()) && !interactive()) {
  fetch_eurostat()
}
