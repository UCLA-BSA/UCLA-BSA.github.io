library(purrr)
library(here)

programs <- list(
  list(
    title = "Doctor of Philosophy (PhD) Students",
    file = "phd-students.qmd",
    contents = "profiles/phd/*.qmd",
    subtitle_filter = '["PhD Student", "PhD Candidate"]',
    has_status = TRUE
  ),
  list(
    title = "Master of Science (MS) Students",
    file = "ms-students.qmd",
    contents = "profiles/ms/*.qmd",
    subtitle_filter = '["MS Student"]',
    has_status = FALSE
  ),
  list(
    title = "Master of Data Science in Health (MDSH) Students",
    file = "mdsh-students.qmd",
    contents = "profiles/mdsh/*.qmd",
    subtitle_filter = '["MDSH Student"]',
    has_status = FALSE
  )
)

make_qmd <- function(p) {
  
  if (p$has_status) {
    table_fields <- "fields: [title, subtitle, description, advisor]"
    table_sort <- "sort-ui: [title, subtitle, description, advisor]"
  } else {
    table_fields <- "fields: [title, description, advisor]"
    table_sort <- "sort-ui: [title, description, advisor]"
  }
  
  yaml <- paste0(
    '---
title: "', p$title, '"
page-layout: full
css: styles.css
format:
  html:
    include-after-body:
      - category-accordion-script.html
      - view-toggle-script.html
listing:
  - id: grid
    type: grid
    page-size: 15
    contents: ', p$contents, '
    include:
      subtitle: ', p$subtitle_filter, '
    grid-columns: 5
    sort-ui: [title, description]
    sort: false
    filter-ui: true
    fields: [image, title, subtitle, description]
    field-display-names:
      title: "Name"
      subtitle: "Status"
      description: "Cohort"
    grid-item-align: left
    categories: unnumbered
  - id: table
    type: table
    page-size: 10
    contents: ', p$contents, '
    include:
      subtitle: ', p$subtitle_filter, '
    ', table_sort, '
    sort: false
    filter-ui: true
    ', table_fields, '
    field-display-names:
      title: "Name"
      subtitle: "Status"
      description: "Cohort"
      advisor: "Advisor"
    categories: unnumbered
    table-hover: true
---
```{=html}
<p class="mb-4" style="display:flex; align-items:center; gap:1rem;">
  <a href="directory.html" class="btn btn-outline-secondary btn-sm">
    &larr; Back to Directory
  </a>
  <span style="margin-left:auto;">
    <button id="btn-grid" class="btn btn-sm btn-secondary" onclick="setView(\'grid\')">&#x229E; Grid</button>
    <button id="btn-table" class="btn btn-sm btn-outline-secondary" onclick="setView(\'table\')">&#9776; List</button>
  </span>
</p>
```

::: {#grid}
:::
::: {#table}
:::
')
  
  writeLines(yaml, here("directory", p$file))
  cat("Written:", p$file, "\n")
}

walk(programs, make_qmd)