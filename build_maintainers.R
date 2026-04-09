# build_maintainers.R
# ============================================================
# Reads maintainers.csv and bakes the lookup table directly
# into footer.html so every rendered page has the data.
#
# Run from the repo root:
#   Rscript build_maintainers.R
# Then: quarto render
#
# The CSV has two columns:
#   page        — the .qmd file path (e.g. stats/stats.qmd)
#   maintainer  — the person's name  (e.g. Timothy Shen)
# ============================================================

library(jsonlite)

csv <- read.csv("maintainers.csv", stringsAsFactors = FALSE, strip.white = TRUE)

# Convert .qmd paths to .html paths the browser will see
# e.g. "stats/stats.qmd" -> "/stats/stats"   (no .html — stripped in JS)
#      "index.qmd"        -> "/"
csv$html_path <- ifelse(
  csv$page == "index.qmd",
  "/",
  paste0("/", sub("\\.qmd$", "", csv$page))
)

# Build named list { "/stats/stats": "Timothy Shen", ... }
lookup <- setNames(as.list(csv$maintainer), csv$html_path)
json   <- toJSON(lookup, auto_unbox = TRUE, pretty = FALSE)

# Read footer.html, replace the placeholder with real data, write back
footer <- readLines("footer.html", warn = FALSE)
footer <- gsub(
  pattern     = "var MAINTAINERS = \\{\\}; /\\* MAINTAINERS_PLACEHOLDER \\*/",
  replacement = paste0("var MAINTAINERS = ", json, ";"),
  x           = footer
)
writeLines(footer, "footer.html")

cat("Injected", nrow(csv), "maintainer entries into footer.html\n")
for (i in seq_len(nrow(csv))) {
  cat(sprintf("  %-40s -> %s\n", csv$html_path[i], csv$maintainer[i]))
}
