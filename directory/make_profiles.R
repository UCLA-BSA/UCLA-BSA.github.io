# use this script to turn the student directory responses into profiles
# this script turns each entry from the student directory form into an about page
library(tidyverse)
library(glue)
library(here)
here::i_am("directory/make_profiles.R")

student_directory_form <- here("directory/Biostatistics Student Directory Form (Responses).xlsx") # replace as needed
df <- readxl::read_xlsx(student_directory_form) %>%
  select(-1) %>%
  rename(email = 1,
         first = 2,
         last = 3,
         preferred = 4,
         ucla_email = 5,
         current_program = 6,
         candidacy = 7,
         year = 8,
         advisor = 9,
         advisor_type = 10,
         bachelors_deg = 11,
         bachelors_major = 12,
         bachelors_grad = 13,
         bachelors_school = 14,
         bachelors_location = 15,
         masters_deg = 16,
         masters_major = 17,
         masters_grad = 18,
         masters_school = 19,
         masters_location = 20,
         other_edu = 21,
         description = 22,
         personal_website = 23,
         linkedin = 24,
         github = 25,
         other_web = 26
  )


df_clean <- df %>%
  mutate(
    filename = glue("{str_to_lower(first)}-{str_to_lower(last)}-{str_to_lower(current_program)}-{str_to_lower(year)}"),
    filename = str_replace_all(filename, "[^a-z0-9 -]", ""),
    filename = str_replace_all(filename, "\\s+", "-"),
    filename = paste0(here("directory/profiles/"), filename, ".qmd")
  ) %>%
  separate_wider_delim(year, delim = "-", names = c("start_year", "start_year_end"), cols_remove = FALSE) %>%
  mutate(
    advisor = advisor |>
      str_replace_all("\\s+and\\s+", ",") |> # replace " and " with comma
      str_replace_all("\\s*,\\s*", ",") |> # remove all spaces around commas
      str_trim() # trim leading/trailing whitespace
  ) %>%
  mutate(image_file = glue("{str_to_lower(first)}-{str_to_lower(last)}-{str_to_lower(current_program)}-{str_to_lower(start_year)}"),
         image_file = paste0(image_file, ".jpg")) %>%
  # sections to actually be used in the profile
  mutate(
    image_file = if_else(
      file.exists(paste0(here("directory/images/"), image_file)),
      image_file,
      "anon.jpg"),
    bio = if_else(
      !is.na(description) & description != "",
      paste0("### Bio:", "\n\n", description),
      ""
    ),
    candidacy = if_else(
      !is.na(candidacy) & candidacy == "Yes",
      "Candidate",
      "Student"
    ),
    bach_edu = if_else(
      !is.na(bachelors_deg) & bachelors_deg != "",
      paste0("**", bachelors_deg, " in ", bachelors_major, "**", ", ", bachelors_grad, "  \n", bachelors_school, " \u2014 ", bachelors_location),
      ""
    ),
    masters_edu = if_else(
      !is.na(masters_deg) & masters_deg != "",
      paste0("**", masters_deg, " in ", masters_major, "**", ", ", masters_grad, "  \n", masters_school, " \u2014 ", masters_location),
      ""
    ),
    advisor = if_else(
      !is.na(advisor) & advisor != "",
      advisor,
      "Not Listed"
    ),
    advisor_type = if_else(
      !is.na(advisor_type) & advisor_type != "",
      advisor_type,
      ""
    )
  ) %>%
  separate_wider_delim(
    advisor,
    delim = ",",
    names = c("advisor1", "advisor2"),
    too_few = "align_start",
    cols_remove = FALSE
  ) %>%
  mutate(advisor1 = ifelse(!is.na(advisor1), advisor1, "Not Listed"),
         advisor2 = ifelse(!is.na(advisor2), advisor2, "")) %>%
  unite("advisor_full", advisor1, advisor2, sep = ", ", remove = FALSE, na.rm = TRUE) %>%
  mutate(advisor_full = gsub(", $", "", advisor_full)) # removes trailing comma if advisor2 was ""



# use this template to build each person's profile
template <- function(df) {
  # build categories cleanly
  # categories_vec <- c(
  #   df$current_program,
  #   df$year,
  #   df$advisor1,
  #   df$advisor2
  # ) %>%
  #   unlist() %>%
  #   as.character() %>%
  #   discard(~ is.na(.) || . == "")   # remove NA and blanks
  
  categories_vec <- c(
    paste0("Program: ", df$current_program),
    paste0("Cohort: ", df$year),
    if(!is.na(df$advisor1) && df$advisor1 != "") {paste0("Advisor: ", df$advisor1)},
    if(!is.na(df$advisor2) && df$advisor2 != "") {paste0("Advisor: ", df$advisor2)}
  ) %>%
    discard(~ is.na(.) || . == "" || . == "Advisor: NA")
  
  # categories_yaml <- paste(categories_vec, collapse = ", ")
  categories_yaml <- paste0('"', categories_vec, '"', collapse = ", ")
  
  # build links conditionally on if they exist
  links <- c(
    if (!is.na(df$ucla_email) && df$ucla_email != "")
      paste0("    - icon: envelope\n      href: mailto:", df$ucla_email),
    if (!is.na(df$personal_website) && df$personal_website != "")
      paste0("    - icon: globe\n      href: ", df$personal_website),
    if (!is.na(df$linkedin) && df$linkedin != "")
      paste0("    - icon: linkedin\n      href: ", df$linkedin),
    if (!is.na(df$github) && df$github != "")
      paste0("    - icon: github\n      href: ", df$github),
    if (!is.na(df$other_web) && df$other_web != "")
      paste0("    - icon: camera\n      href: ", df$other_web)
  )
  
  links_yaml <- if (length(links) > 0) paste(links, collapse = "\n") else "[]"
  
  # profile template below
  glue(
    "
---
title: \"**{df$first} {df$last}**\"
subtitle: \"{df$current_program} {df$candidacy}\"
description: \"Cohort: {df$year}\"
image: ../images/{df$image_file}
categories: [{categories_yaml}]
about:
  template: trestles
  links:
{links_yaml}
---


### {df$current_program} {df$candidacy}, Biostatistics
University of California, Los Angeles  
**{df$advisor_type} Advisor(s):** {df$advisor_full}  
**Cohort:** {df$year} 

### Education:

{df$masters_edu}

{df$bach_edu}



{df$bio}
"
  )
}

# create the .qmd profiles for each person
for (i in seq_len(nrow(df_clean))) {
  writeLines(
    template(df_clean[i, ]),
    df_clean$filename[i]
  )
}

