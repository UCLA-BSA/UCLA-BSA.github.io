# use this script to turn the student directory responses into profiles
# this script turns each entry from the student directory form into an about page
library(glue)
library(googledrive)
library(dotenv)
library(tidyverse)
library(here)
here::i_am("directory/make_profiles.R")

##### get environment ready to connect to google drive #####
download_files <- TRUE # set to FALSE if you don't want to download each time you run this script
dotenv::load_dot_env(file = here(".env"))
spreadsheet_url <- Sys.getenv("SPREADSHEET_URL")
options(gargle_oauth_cache = ".secrets",
        gargle_oauth_email = Sys.getenv("UCLA_EMAIL"))


# if (download_files == TRUE) {
#   if (!drive_has_token()) {
#     # dotenv::load_dot_env(file = here(".env"))
#     
#     # authenticate google
#     drive_auth(email = Sys.getenv("UCLA_EMAIL")) 
#   }
#   spreadsheet_url <- Sys.getenv("SPREADSHEET_URL")
#   drive_download(as_id(spreadsheet_url), path = here("directory/directory_file.xlsx"), overwrite = TRUE)
# }



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
  
  image_path <- paste(here("directory/images"), program_lower, meta_name, sep = "/")
  
  if(!dir.exists(here("directory/images", program_lower))) {
    dir.create(here("directory/images", program_lower), showWarnings = FALSE, recursive = TRUE)
  }
  
  # only download if image exists in Google drive and if it is different from local folder
  if(!is.na(file_id)) {
    meta <- drive_get(as_id(file_id))
    drive_md5 <- meta$drive_resource[[1]]$md5Checksum
    
    if (file.exists(image_path)) {
      local_md5 <- tools::md5sum(here(image_path))
      
      if (drive_md5 == local_md5) {
        print(paste0("No changes to file ", image_path, ". Will not redownload."))
        
        return(invisible(NULL))
      }
    }
    
    print(paste0("Downloading ", image_path, "."))
    suppressMessages(
      drive_download(
        as_id(file_id),
        path = image_path,
        overwrite = TRUE
      )
    )
  }
}

##### clean data frame #####
student_directory_form <- here("directory/directory_file.xlsx")
if (download_files == TRUE) {
  df <- googlesheets4::read_sheet(spreadsheet_url, range = "E:AE")
  writexl::write_xlsx(df, student_directory_form)
  
} else {
  df <- readxl::read_xlsx(student_directory_form) #%>%
    #select(-c(1, 2, 3, 4))
}
df <- df %>%
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
    str_detect(x, regex("nyu", ignore_case = TRUE)) ~ "New York University",
    str_detect(x, regex("usma|west point|united states military academy", ignore_case = TRUE)) ~ "United States Military Academy",
    .default = x
  )
}


df_clean <- df %>%
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
    ucla_email = case_when(
      is.na(ucla_email) ~ NA_character_,
      str_detect(ucla_email, "@") ~ ucla_email,  # already has @, leave it
      TRUE ~ paste0(ucla_email, "@ucla.edu") # missing domain, append it
    ),
    ucla_email = tolower(ucla_email)
  ) %>%
  
  # cleaning education
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
         advisor2 = ifelse(!is.na(advisor2), advisor2, ""),
         advisor1 = str_remove(advisor1, regex("^(dr\\.?s?\\.?|professor|prof\\.?)\\s*", ignore_case = TRUE)),
         advisor2 = str_remove(advisor2, regex("^(dr\\.?s?\\.?|professor|prof\\.?)\\s*", ignore_case = TRUE))) %>%
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

# delete the folders with the profiles first
unlink(here("directory/profiles/mdsh"), recursive = TRUE)
unlink(here("directory/profiles/ms"), recursive = TRUE)
unlink(here("directory/profiles/phd"), recursive = TRUE)

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

