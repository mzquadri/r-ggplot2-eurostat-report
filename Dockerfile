# R and Quarto, pinned, for rendering the report reproducibly.
#
# rocker/r-ver is used rather than rocker/verse (which bundles Quarto and
# TinyTeX) because verse is several gigabytes and only the HTML output is
# wanted here. r-ver also points install.packages at the Posit Package Manager,
# which serves prebuilt Linux binaries, so ggplot2 installs in seconds instead
# of compiling from source.
FROM rocker/r-ver:4.4.2

ARG QUARTO_VERSION=1.6.39

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && curl -fsSL -o /tmp/quarto.deb \
      "https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb" \
 && apt-get install -y --no-install-recommends /tmp/quarto.deb \
 && rm /tmp/quarto.deb \
 && rm -rf /var/lib/apt/lists/*

# jsonlite reads the JSON-stat response and ggplot2 draws. The `eurostat`
# package is deliberately not used - decoding the response by hand is the part
# of this worth showing.
#
# knitr and rmarkdown are Quarto's requirement rather than the report's: Quarto
# executes R chunks through knitr, and without them `quarto render` stops with
# "The knitr package is not available in this R installation".
RUN install2.r --error --skipinstalled jsonlite ggplot2 knitr rmarkdown

WORKDIR /report
