# use this script to turn the student directory responses into profiles
# this script turns each entry from the student directory form into an about page
library(glue)
library(googledrive)
library(googlesheets4)
library(dotenv)
library(tidyverse)
library(jsonlite)
library(here)
here::i_am("directory/make_profiles.R")

##### get environment ready to connect to google drive #####
CACHE_FILE <- here("directory/.image_cache.json")
load_cache <- function() {
  if (file.exists(CACHE_FILE)) fromJSON(CACHE_FILE) else list()
}
save_cache <- function(cache) {
  write_json(cache, CACHE_FILE, auto_unbox = TRUE)
}


download_files <- TRUE # set to FALSE if you don't want to download each time you run this script
drive_deauth()
googlesheets4::gs4_deauth()

if (file.exists(here(".env"))) {
  dotenv::load_dot_env(file = here(".env"))
}

options(
  gargle_oauth_cache = ".secrets",
  gargle_interactivity = FALSE
)

# handle Google Drive/Sheets authentication
if (Sys.getenv("GDRIVE_JSON") != "") {
  # github actions path
  message("Authenticating via Service Account JSON...")
  tmp_json <- tempfile(fileext = ".json")
  writeLines(Sys.getenv("GDRIVE_JSON"), tmp_json)
  drive_auth(path = tmp_json)
  googlesheets4::gs4_auth(path = tmp_json)
} else {
  # if running locally, authenticate via google email
  message("Authenticating via local UCLA email...")
  drive_auth(email = Sys.getenv("UCLA_EMAIL"))
  googlesheets4::gs4_auth(email = Sys.getenv("UCLA_EMAIL"))
}

spreadsheet_url <- Sys.getenv("STUDENT_DIRECTORY_URL")

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
download_image <- function(file_id, program_lower, meta_name, alumni = FALSE, graduation_year = NA) {
  if (is.na(file_id) || is.na(meta_name)) return(invisible(NULL))
  
  if (alumni && !is.na(graduation_year)) {
    subfolder <- paste0(program_lower, "-alumni/", program_lower, graduation_year)
  } else {
    subfolder <- program_lower
  }
  
  image_path <- paste(here("directory/images"), subfolder, meta_name, sep = "/")
  
  if (!dir.exists(here("directory/images", subfolder))) {
    dir.create(here("directory/images", subfolder), showWarnings = FALSE, recursive = TRUE)
  }
  
  cache <- load_cache()
  cached_md5 <- cache[[file_id]]
  
  # If file exists locally and MD5 matches cache, skip entirely (no API call)
  if (file.exists(image_path) && !is.null(cached_md5)) {
    local_md5 <- tools::md5sum(image_path)[[1]]
    cached_local <- if (is.list(cached_md5)) cached_md5$local_md5 else cached_md5
    if (local_md5 == cached_local) {
      message("Cache hit, skipping: ", meta_name)
      return(invisible(NULL))
    }
  }
  
  # Call API only if no cache entry or local file is missing/changed
  message("Checking Drive for: ", meta_name)
  meta <- drive_get(as_id(file_id))
  drive_md5 <- meta$drive_resource[[1]]$md5Checksum
  
  if (file.exists(image_path)) {
    local_md5 <- tools::md5sum(image_path)[[1]]
    if (local_md5 == drive_md5) {
      cache[[file_id]] <- list(drive_md5 = drive_md5, local_md5 = local_md5, path = image_path)
      save_cache(cache)
      message("Up to date, skipping: ", meta_name)
      return(invisible(NULL))
    }
  }
  
  message("Downloading: ", meta_name)
  suppressMessages(
    drive_download(as_id(file_id), path = image_path, overwrite = TRUE)
  )
  
  local_md5 <- tools::md5sum(image_path)[[1]]
  cache[[file_id]] <- list(drive_md5 = drive_md5, local_md5 = local_md5, path = image_path)
  save_cache(cache)
}

##### clean data frame #####
student_directory_form <- here("directory/directory_file.xlsx")
if (download_files == TRUE) {
  df <- googlesheets4::read_sheet(spreadsheet_url, range = "A:AE")
  writexl::write_xlsx(df, student_directory_form)
  
} else {
  df <- readxl::read_xlsx(student_directory_form)
}

df <- df %>%
  filter(.[[3]] == "I agree to the FERPA directory release, photo consent, and formatting authorization described above.") %>% # include only those who agree to FERPA
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
         program_lower = tolower(current_program)) %>%
  mutate(file_id = str_extract(photo, "(?<=id=)[^&]+"),
         meta = map(file_id, safe_drive_get)) %>%
  unnest(meta, names_sep = "_") %>%
  mutate(ext = map(meta_name, safe_ext)) %>%
  select(-meta_drive_resource) %>%
  # set program graduation year for the MS and MDSH students
  separate_wider_delim(year, delim = " ", names = c("quarter", "start_year"), cols_remove = FALSE) %>%
  mutate(
    graduation_year = if_else(program_lower %in% c("ms", "mdsh"),
                              as.numeric(start_year) + 2,
                              NA_real_),
    graduation_date = if_else(program_lower %in% c("ms", "mdsh"),
                              as.Date(paste0(as.numeric(start_year) + 2, "-07-01")), # assume by July 1 all the MS, MDSH students will have graduated
                              NA),
    alumni = graduation_date < Sys.Date(),
    alumni = ifelse(is.na(alumni) | alumni == FALSE,
                    FALSE,
                    TRUE),
    alumni_dir = ifelse(alumni == TRUE,
                        paste0(program_lower, "-alumni/", program_lower, graduation_year),
                        program_lower),
    alumni_opt_out = ifelse(is.na(alumni_opt_out),
                            FALSE,
                            TRUE)
  ) %>%
  filter(!(alumni_opt_out == TRUE & alumni == TRUE))


# download all profile picture images
if (download_files == TRUE) {
  invisible(
    pmap(list(df$file_id, df$program_lower, df$meta_name, df$alumni, df$graduation_year), download_image)
  )
}

##### clean data frame #####
# for previous degree line
complete_degree <- function(deg, major, grad_year, school, location) {
  deg <- ifelse(!is.na(deg), deg, "")
  major <- ifelse(!is.na(major), paste(" in ", major, sep = ""), "")
  grad_year <- ifelse(!is.na(grad_year), paste(", ", grad_year, sep = ""), "")
  school <- ifelse(!is.na(school), school, "")
  location <- ifelse(!is.na(location),
                     ifelse(school != "",
                            paste(" \u2014 ", location, sep = ""),
                            location),
                     "")
  paste("**", deg, major, "**", grad_year, "  \n", school, location, sep = "")
}

# list of school names to clean up
standardize_university <- function(x) {
  case_when(
    str_detect(x, regex("ucla|university of california.*los angeles", ignore_case = TRUE)) ~ "University of California, Los Angeles",
    str_detect(x, regex("ucb|uc berkeley|university of california.*berkeley", ignore_case = TRUE)) ~ "University of California, Berkeley",
    str_detect(x, regex("ucsb|uc santa barbara|university of california.*santa barbara", ignore_case = TRUE)) ~ "University of California, Santa Barbara",
    str_detect(x, regex("ucsd|uc san diego|university of california.*san diego", ignore_case = TRUE)) ~ "University of California, San Diego",
    str_detect(x, regex("ucsf|uc san francisco|university of california.*san francisco", ignore_case = TRUE)) ~ "University of California, San Francisco",
    str_detect(x, regex("ucd|uc davis|university of california.*davis", ignore_case = TRUE)) ~ "University of California, Davis",
    str_detect(x, regex("uci|uc irvine|university of california.*irvine", ignore_case = TRUE)) ~ "University of California, Irvine",
    str_detect(x, regex("ucr|uc riverside|university of california.*riverside", ignore_case = TRUE)) ~ "University of California, Riverside",
    str_detect(x, regex("ucsc|uc santa cruz|university of california.*santa cruz", ignore_case = TRUE)) ~ "University of California, Santa Cruz",
    str_detect(x, regex("ucm|uc merced|university of california.*merced", ignore_case = TRUE)) ~ "University of California, Merced",
    str_detect(x, regex("cal poly pomona", ignore_case = TRUE)) ~ "California State Polytechnic University, Pomona",
    str_detect(x, regex("jhu|johns? hopkins( university)?", ignore_case = TRUE)) ~ "Johns Hopkins University",
    str_detect(x, regex("usc|university of southern california", ignore_case = TRUE)) ~ "University of Southern California",
    str_detect(x, regex("university of chicago|uchicago", ignore_case = TRUE)) ~ "The University of Chicago",
    str_detect(x, regex("nyu", ignore_case = TRUE)) ~ "New York University",
    str_detect(x, regex("usma|west point|united states military academy", ignore_case = TRUE)) ~ "United States Military Academy",
    .default = x
  )
}


# list of advisors

standardize_advisor <- function(x) {
  case_when(
    is.na(x) ~ NA_character_,
    str_detect(x, regex("^li$", ignore_case = TRUE)) ~ "Gang Li", # for now assume "Li" means Gang Li, adjust later for Sijia Li if it pops up
    str_detect(x, regex("\\bholbrook\\b", ignore_case = TRUE)) ~ "Andrew Holbrook",
    str_detect(x, regex("\\bballiu\\b", ignore_case = TRUE)) ~ "Brunilda Balliu",
    str_detect(x, regex("\\bcrespi\\b", ignore_case = TRUE)) ~ "Catherine M. Crespi",
    str_detect(x, regex("\\bramirez\\b", ignore_case = TRUE)) ~ "Christina Ramirez",
    str_detect(x, regex("\\bsenturk\\b", ignore_case = TRUE)) ~ "Damla Senturk",
    str_detect(x, regex("\\btelesca\\b", ignore_case = TRUE)) ~ "Donatello Telesca",
    str_detect(x, regex("\\bbargagli\\b", ignore_case = TRUE)) ~ "Falco J. Bargagli Stoffi",
    str_detect(x, regex("\\bgang\\s+li\\b", ignore_case = TRUE)) ~ "Gang Li",
    str_detect(x, regex("\\bsijia\\s+li\\b", ignore_case = TRUE)) ~ "Sijia Li",
    str_detect(x, regex("\\bhua\\s+zhou\\b", ignore_case = TRUE)) ~ "Hua Zhou",
    str_detect(x, regex("\\bjin\\s+zhou\\b", ignore_case = TRUE)) ~ "Jin Zhou",
    str_detect(x, regex("\\bguindani\\b", ignore_case = TRUE)) ~ "Michele Guindani",
    str_detect(x, regex("\\bweiss\\b", ignore_case = TRUE)) ~ "Robert Weiss",
    str_detect(x, regex("\\bbanerjee\\b", ignore_case = TRUE)) ~ "Sudipto Banerjee",
    str_detect(x, regex("\\bbelin\\b", ignore_case = TRUE)) ~ "Thomas Belin",
    str_detect(x, regex("\\bdai\\b", ignore_case = TRUE)) ~ "Xiaowu Dai",
    .default = x
  )
}

df_clean <- df %>%
  # individual cleaning
  mutate(
    advisor = if_else(first == "Hanxi" & last == "Chen" & current_program == "MS" & year == "Fall 2024",
                      "Damla Senturk",
                      advisor),
    advisor_type = if_else(first == "Hanxi" & last == "Chen" & current_program == "MS" & year == "Fall 2024",
                           "research",
                           advisor_type)
  ) %>%

  # cleaning names
  mutate(
    unique_id = row_number(), # id to assign to each person's file
    first = str_to_title(first),
    last  = str_to_title(last),
    preferred = ifelse(preferred == first | preferred == last | preferred == paste(first, last), NA, preferred), # remove duplicated preferred name
    preferred = ifelse(
      str_detect(preferred, "\\(.*\\)"),
      str_extract(preferred, "(?<=\\().*?(?=\\))"), # if someone puts name as first (preferred) last, only extracts preferred
      preferred),
    preferred = ifelse(!is.na(preferred), paste("(", preferred, ") ", sep = ""), "")
  ) %>%
  mutate(
    filename = glue("{str_to_lower(first)}-{str_to_lower(last)}-{str_to_lower(current_program)}-{str_to_lower(unique_id)}"),
    filename = str_replace_all(filename, "[^a-z0-9 -]", ""),
    filename = str_replace_all(filename, "\\s+", "-"),
    filename = ifelse(alumni == FALSE | is.na(alumni),
                      paste0(here("directory/profiles/"), program_lower, "/", filename, ".qmd"),
                      paste0(here("directory/profiles/"), alumni_dir, "/", filename, ".qmd")
    )
  ) %>%
  
  mutate(
    advisor = advisor |>
      str_replace_all("\\s+and\\s+", ",") |> # replace " and " with comma
      str_replace_all("\\s*,\\s*", ",") |> # remove all spaces around commas
      str_trim() # trim leading/trailing whitespace
  ) %>%
  
  mutate(
    ucla_email = case_when(
      is.na(ucla_email) ~ NA_character_,
      str_detect(ucla_email, "@") ~ ucla_email,  # already has @, leave it
      TRUE ~ paste0(ucla_email, "@ucla.edu") # missing domain, append it
    ),
    ucla_email = tolower(ucla_email)
  ) %>%
  
  # cleaning education
  ## adjusting degree names
  mutate(bachelors_deg = ifelse(is.na(bachelors_deg) & (!is.na(bachelors_major) | bachelors_major != ""),
                                "Bachelor's Degree",
                                bachelors_deg),
         masters_deg = ifelse(is.na(masters_deg) & (!is.na(masters_deg) | masters_deg != ""),
                              "Master's Degree",
                              masters_deg)) %>%
  
  ## cleaning the majors
  mutate(bachelors_major = tools::toTitleCase(bachelors_major),
         masters_major = tools::toTitleCase(masters_major),
         bachelors_major = bachelors_major %>% # for double majors, replace "/" with "&"
           str_replace_all("&", "and") %>% # if "&" is used in one major, replace with "and"
           str_replace_all("/", " & ")) %>%
  
  ## first strip country if USA, then use state abbreviation
  mutate(bachelors_location = str_remove(bachelors_location, regex(",?\\s*(usa|united states|u\\.s\\.a\\.|u\\.s\\.)\\s*$", ignore_case = TRUE)),
         masters_location = str_remove(masters_location, regex(",?\\s*(usa|united states|u\\.s\\.a\\.|u\\.s\\.)\\s*$", ignore_case = TRUE)),
         bachelors_location = str_replace_all(bachelors_location, regex(paste0(",\\s*(", paste(state.name, collapse = "|"), ")"), ignore_case = TRUE), function(x) paste0(", ", state.abb[match(str_to_title(str_trim(str_remove(x, ","))), state.name)])),
         masters_location = str_replace_all(masters_location, regex(paste0(",\\s*(", paste(state.name, collapse = "|"), ")"), ignore_case = TRUE), function(x) paste0(", ", state.abb[match(str_to_title(str_trim(str_remove(x, ","))), state.name)]))) %>%
  
  mutate(bachelors_location = str_replace(bachelors_location, "\\b([a-zA-Z]{2})$", toupper),
         masters_location = str_replace(masters_location, "\\b([a-zA-Z]{2})$", toupper)) %>% # make all two letter words uppercase
  
  mutate(bachelors_school = standardize_university(bachelors_school), # standardize the school names
         masters_school = standardize_university(masters_school)) %>%
  
  ## graduation year and alumni
  mutate(
    bachelors_grad = as.numeric(str_extract(as.character(bachelors_grad), "\\d{4}")),
    masters_grad = as.numeric(str_extract(as.character(masters_grad), "\\d{4}"))
  ) %>%
  
  mutate(graduation_yaml = ifelse(alumni == TRUE,
                                  paste("graduation:", graduation_year),
                                  "")) %>%
  
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
      alumni == TRUE & !is.na(alumni),
      if_else(
        file.exists(paste(here("directory/images"), paste0(program_lower, "-alumni"), paste0(program_lower, graduation_year), meta_name, sep = "/")),
        paste("/directory", "images", paste0(program_lower, "-alumni"), paste0(program_lower, graduation_year), meta_name, sep = "/"),
        "/directory/images/anon.jpg"
      ),
      if_else(
        file.exists(paste(here("directory/images"), program_lower, meta_name, sep = "/")),
        paste("/directory", "images", program_lower, meta_name, sep = "/"),
        "/directory/images/anon.jpg"
      )
    ),
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
         advisor2 = ifelse(!is.na(advisor2), advisor2, ""),
         advisor1 = str_remove(advisor1, regex("^(dr\\.?s?\\.?|professor|prof\\.?)\\s*", ignore_case = TRUE)),
         advisor2 = str_remove(advisor2, regex("^(dr\\.?s?\\.?|professor|prof\\.?)\\s*", ignore_case = TRUE))) %>%
  
  mutate(
    advisor1 = standardize_advisor(advisor1), # standardize advisor names
    advisor2 = standardize_advisor(advisor2)
  ) %>%
  
  unite("advisor_full", advisor1, advisor2, sep = ", ", remove = FALSE, na.rm = TRUE) %>%
  mutate(advisor_full = gsub(", $", "", advisor_full)) # removes trailing comma if advisor2 was ""





##### create everyone's profiles #####
# use this template to build each person's profile
template <- function(df) {
  
  categories_vec <- c(
    paste0("Program: ", df$current_program),
    paste0("Cohort: ", df$year),
    if (isTRUE(df$alumni)) "Alumni",
    if (isTRUE(df$alumni) && !is.na(df$graduation_year)) paste0("Class of: ", df$graduation_year),
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
{df$graduation_yaml}
advisor: {df$advisor_full}
image: {df$image_file}
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

# delete the folders with the profiles first
unlink(here("directory/profiles/mdsh"), recursive = TRUE)
unlink(here("directory/profiles/ms"), recursive = TRUE)
unlink(here("directory/profiles/phd"), recursive = TRUE)
unlink(here("directory/profiles/mdsh-alumni"), recursive = TRUE)
unlink(here("directory/profiles/ms-alumni"), recursive = TRUE)
unlink(here("directory/profiles/phd-alumni"), recursive = TRUE)


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


# ── Export anonymized stats data for the dashboard ──────────────────────
stats_data <- df_clean %>%
  mutate(
    # bachelors_location is already cleaned: US locs end in ", XX" (state abbr)
    bs_state   = str_extract(bachelors_location, "(?<=,\\s)[A-Z]{2}$"),
    bs_country = case_when(
      !is.na(bs_state)                                    ~ "United States",
      is.na(bachelors_location) | bachelors_location == "" ~ NA_character_,
      TRUE ~ str_trim(str_extract(bachelors_location, "[^,]+$"))
    )
  ) %>%
  transmute(
    program     = current_program,
    candidacy   = tolower(candidacy),          # "candidate" or "student"
    cohortYear  = start_year,
    hasMasters  = !is.na(masters_deg) & masters_deg != "",
    bsMajor     = na_if(bachelors_major, ""),
    bsSchool    = na_if(bachelors_school, ""),
    bsCountry   = bs_country,
    bsState     = bs_state,
    advisor1      = if_else(advisor1 == "Not Listed" | is.na(advisor1), NA_character_, advisor1),
    advisor2      = na_if(advisor2, ""),
    advisorType   = tolower(advisor_type),
    alumni        = alumni,
    mastersSchool = na_if(standardize_university(masters_school), "")
    # deliberately omitting: names, email, linkedin url, github url, photo, bio text
  )

write_json(stats_data, here("stats/student_stats.json"), auto_unbox = TRUE, na = "null")
message("Wrote stats/student_stats.json (", nrow(stats_data), " rows)")

