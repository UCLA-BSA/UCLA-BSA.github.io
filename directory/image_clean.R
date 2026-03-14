# this script should standardize all the different image file formats to be .jpg
# run this first before running the make_profiles.R script
library(stringr)
library(magick)
library(tidyverse)
library(here)

### delete existing photos to start from clean slate

images_folder <- here("directory/images")
files_to_delete <- list.files(
  images_folder,
  pattern = "\\.(png|jpeg|jpg)$",
  full.names = TRUE,
  ignore.case = TRUE
)

# exclude anon.jpg
files_to_delete <- files_to_delete[basename(files_to_delete) != "anon.jpg"]

file.remove(files_to_delete) # remove everyone's photos


### clean raw photos
raw_images_path <- here("directory/images_raw") # location of the images

files <- list.files(
  raw_images_path,
  pattern = "\\.(png|jpeg|jpg)$",
  full.names = TRUE,
  ignore.case = TRUE
)

new_names <- str_replace(basename(files), " - .*?(?=\\.[a-zA-Z]+$)", "")

preview <- data.frame(
  old = basename(files),
  new = new_names
)

file.copy(
  from = files,
  to = file.path(here("directory/images"), new_names)
)

files <- list.files(
  here("directory/images"),
  pattern = "\\.(png|jpeg|jpg)$",
  full.names = TRUE,
  ignore.case = TRUE
)


for (file in files) {

  img <- image_read(file)
  file.remove(file)

  # remove the extension
  base_name <- tools::file_path_sans_ext(basename(file))

  new_path <- file.path(here("directory/images"), paste0(base_name, ".jpg")) # where to save the cleaned images

  image_write(img, new_path, format = "jpg")
}

