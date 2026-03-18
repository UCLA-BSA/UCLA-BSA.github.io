# use this script to turn the student directory responses into profiles
# this script turns each entry from the student directory form into an about page
library(glue)
library(googledrive)
library(dotenv)
library(tidyverse)
library(here)
here::i_am("directory/make_profiles.R")

##### get environment ready to connect to google drive #####
download_files <- FALSE # set to FALSE if you don't want to download each time you run this script

if (download_files == TRUE) {
  if (!drive_has_token()) {
    dotenv::load_dot_env(file = here(".env"))
    drive_auth() # authenticate google
  }
  spreadsheet_url <- Sys.getenv("SPREADSHEET_URL")
  drive_download(as_id(spreadsheet_url), path = here("directory/directory_file.xlsx"), overwrite = TRUE)
}



# functions to get image id and extensions
safe_drive_get <- function(id) {
  if (is.na(id)) {
    return(NA) 
  }
  drive_get(as_id(id))
}

safe_ext <- function(meta_name) {
  if (is.na(meta_name)) {
    return(NA_character_)
  }
  tools::file_ext(meta_name)
}

# download images function
download_image <- function(file_id, program_lower, meta_name) {
  
  if(!dir.exists(here("directory/images", program_lower))) {
    dir.create(here("directory/images", program_lower), showWarnings = FALSE, recursive = TRUE)
  }
  
  if(!is.na(file_id)) {
    drive_download(
      as_id(file_id),
      path = paste(here("directory/images"), program_lower, meta_name, sep = "/"),
      overwrite = TRUE
    )
  }
}

##### clean data frame #####
student_directory_form <- here("directory/directory_file.xlsx")

df <- readxl::read_xlsx(student_directory_form) %>%
  select(-c(1, 2, 3, 4)) %>%
  rename(first = 1,
         last = 2,
         preferred = 3,
         photo = 4,
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
         alumni_opt_out = 22,
         description = 23,
         personal_website = 24,
         linkedin = 25,
         github = 26,
         other_web = 27
  ) %>%
  mutate(current_program = recode(current_program, "Master of Data Science in Public Health (MDSH)" = "MDSH"),
         program_lower = tolower(current_program),
         file_id = str_extract(photo, "(?<=id=)[^&]+")) %>%
  mutate(meta = map(file_id, safe_drive_get)) %>%
  unnest(meta, names_sep = "_") %>%
  mutate(ext = map(meta_name, safe_ext)) %>%
  select(-meta_drive_resource)


# download all profile picture images
if (download_files == TRUE) {
  pmap(list(df$file_id, df$program_lower, df$meta_name), download_image)
}


##### clean data frame #####
# for previous degree line
complete_degree <- function(deg, major, grad_year, school, location) {
  deg <- ifelse(!is.na(deg), deg, "")
  major <- ifelse(!is.na(major), paste(" in ", major, sep = ""), "")
  grad_year <- ifelse(!is.na(grad_year), paste(", ", grad_year, sep = ""), "")
  school <- ifelse(!is.na(school), school, "")
  location <- ifelse(!is.na(location), paste(" \u2014 ", location, sep = ""), "")
  paste("**", deg, major, "**", grad_year, "  \n", school, location, sep = "")
}



df_clean <- df %>%
  mutate(preferred = ifelse(!is.na(preferred), paste("(", preferred, ") ", sep = ""), "")) %>%
  mutate(
    filename = glue("{str_to_lower(first)}-{str_to_lower(last)}-{str_to_lower(current_program)}-{str_to_lower(year)}"),
    filename = str_replace_all(filename, "[^a-z0-9 -]", ""),
    filename = str_replace_all(filename, "\\s+", "-"),
    filename = paste0(here("directory/profiles/"), program_lower, "/", filename, ".qmd")
  ) %>%
  separate_wider_delim(year, delim = " ", names = c("quarter", "start_year"), cols_remove = FALSE) %>%
  mutate(
    advisor = advisor |>
      str_replace_all("\\s+and\\s+", ",") |> # replace " and " with comma
      str_replace_all("\\s*,\\s*", ",") |> # remove all spaces around commas
      str_trim() # trim leading/trailing whitespace
  ) %>%
  mutate(
    first_clean = str_replace_all(str_to_lower(first), "\\s+", "-"),
    last_clean  = str_replace_all(str_to_lower(last),  "\\s+", "-")#,
    # image_file  = glue("{first_clean}-{last_clean}-{str_to_lower(current_program)}-{str_to_lower(start_year)}"),
    # image_file  = paste0(image_file, ".jpg")
  ) %>%
  mutate(
    ucla_email = case_when(
      is.na(ucla_email) ~ NA_character_,
      str_detect(ucla_email, "@") ~ ucla_email,  # already has @, leave it
      TRUE ~ paste0(ucla_email, "@ucla.edu")      # missing domain, append it
    )
  ) %>%
  
  # fixing links
  mutate(across(
    c(personal_website, linkedin, github, other_web),
    ~ case_when(
      is.na(.) ~ NA_character_,
      str_detect(., "^https?://") ~ .,
      TRUE ~ paste0("https://", .)
    )
  )) %>%
  
  # sections to actually be used in the profile
  mutate(
    image_file = if_else(
      file.exists(paste(here("directory/images"), program_lower, meta_name, sep = "/")),
      paste(program_lower, meta_name, sep = "/"),
      "anon.jpg"),
    bio = if_else(
      !is.na(description) & description != "",
      description,
      ""
    ),
    candidacy = if_else(
      !is.na(candidacy) & candidacy == "Yes",
      "Candidate",
      "Student"
    ),
    bach_edu = if_else(
      !is.na(bachelors_deg) & bachelors_deg != "",
      complete_degree(bachelors_deg, bachelors_major, bachelors_grad, bachelors_school, bachelors_location),
      ""
    ),
    masters_edu = if_else(
      !is.na(masters_deg) & masters_deg != "",
      complete_degree(masters_deg, masters_major, masters_grad, masters_school, masters_location),
      ""
    ),
    advisor = if_else(
      !is.na(advisor) & advisor != "",
      advisor,
      "Not Listed"
    ),
    advisor_type = if_else(
      !is.na(advisor_type) & advisor_type != "",
      paste(advisor_type, " ", sep = ""),
      ""
    )
  ) %>%
  mutate(masters_edu = ifelse(masters_edu != "" & masters_grad >= 2026 & !is.na(masters_grad), "", masters_edu),
         education_label = ifelse(masters_edu != "" | bach_edu != "", "### Education:", ""),
         bio_label = ifelse(bio != "", "### Bio:", "")) %>%
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
  




##### create everyone's profiles #####
# use this template to build each person's profile
template <- function(df) {
  
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
    # if (!is.na(df$ucla_email) && df$ucla_email != "")
    #   paste0("    - icon: envelope\n      href: mailto:", df$ucla_email),
    # if (!is.na(df$ucla_email) && df$ucla_email != "")
    #   paste0("    - text: ", str_replace(df$ucla_email, "@", " [at] ")),
    if (!is.na(df$personal_website) && df$personal_website != "")
      paste0("    - icon: globe\n      href: ", df$personal_website, "\n      target: _blank"),
    if (!is.na(df$linkedin) && df$linkedin != "")
      paste0("    - icon: linkedin\n      href: ", df$linkedin, "\n      target: _blank"),
    if (!is.na(df$github) && df$github != "")
      paste0("    - icon: github\n      href: ", df$github, "\n      target: _blank"),
    if (!is.na(df$other_web) && df$other_web != "")
      paste0("    - icon: camera\n      href: ", df$other_web, "\n      target: _blank")
  )
  
  links_section <- if (length(links) > 0) {
    paste0("  links:\n", paste(links, collapse = "\n"))
  } else {
    ""
  }
  
  # email scrambler to protect from scrapers; the code (with the scramble_email.html) should only make the email on render
  email_js <- if (!is.na(df$ucla_email[[1]]) && df$ucla_email[[1]] != "") {
    parts <- str_split(df$ucla_email[[1]], "@")[[1]]
    user <- parts[1]
    domain <- parts[2]
    paste0('**Email:**', '<script type="text/javascript">scrambleIt("', domain, '","', user, '");</script>')
  } else {
    ""
  }
  # profile template below
  glue(
    "
---
title: \"**{df$first} {df$preferred}{df$last}**\"
subtitle: \"{df$current_program} {df$candidacy}\"
description: \"Cohort: {df$year}\"
image: ../../images/{df$image_file}
categories: [{categories_yaml}]
about:
  template: trestles
  image-shape: round
{links_section}
---


### {df$current_program} {df$candidacy}, Biostatistics
University of California, Los Angeles  
**{df$advisor_type}Advisor(s):** {df$advisor_full}  
**Cohort:** {df$year}  
{email_js}

{df$education_label}

{df$masters_edu}

{df$bach_edu}

{df$bio_label}

{df$bio}
"
  )
}

# create the .qmd profiles for each person
for (i in seq_len(nrow(df_clean))) {
  
  if(!dir.exists((dirname(df_clean$filename[i])))) {
    dir.create(dirname(df_clean$filename[i]), showWarnings = FALSE, recursive = TRUE)
  }
  
  writeLines(
    template(df_clean[i, ]),
    df_clean$filename[i]
  )
}

