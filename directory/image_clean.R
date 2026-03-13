# this script should standardize all the different image file formats to be .jpg
# run this first before running the make_profiles.R script
library(stringr)
library(magick)
library(tidyverse)
library(here)

folder_path <- here("directory/images_raw") # location of the images

files <- list.files(
  folder_path,
  pattern = "\\.(png|jpeg|jpg)$",
  full.names = TRUE,
  ignore.case = TRUE
)

new_names <- str_replace(basename(files), " - .*?(?=\\.[a-zA-Z]+$)", "")

preview <- data.frame(
  old = basename(files),
  new = new_names
)

print(preview)

file.rename(
  from = files,
  to = file.path(folder_path, new_names)
)

files <- list.files(
  folder_path,
  pattern = "\\.(png|jpeg|jpg)$",
  full.names = TRUE,
  ignore.case = TRUE
)


for (file in files) {
  
  img <- image_read(file)
  
  # remove the extension
  base_name <- tools::file_path_sans_ext(basename(file))
  
  new_path <- file.path(here("directory/images"), paste0(base_name, ".jpg")) # where to save the cleaned images
  
  image_write(img, new_path, format = "jpg")
}
