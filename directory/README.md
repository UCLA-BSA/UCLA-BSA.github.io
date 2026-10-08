# Maintaining the Student Directory

This folder contains the source files and automation for the UCLA Biostatistics Student Association directory. Student and alumni profiles are generated from the directory response spreadsheets, rendered by Quarto, and published to GitHub Pages.

For the usual update, maintain the two response spreadsheets and let the scheduled GitHub Action do the rest. It runs once each day (late evening Pacific time) and also runs whenever a change is pushed to `main`.

## Directory update flow

1. Students submit the Student Directory Form and, if applicable, the alumni form.
2. The `Update and Build Biostatistics Student Directory` GitHub Actions workflow reads the two linked Google Sheets.
3. `make_profiles.R` keeps FERPA-consented entries, downloads any current profile photos, determines current student versus alumni status, and rebuilds profile files under `profiles/`.
4. Quarto renders the changed profile and listing pages. The workflow also refreshes the anonymized data used by the student-statistics page.
5. `build_directory_index.R` rebuilds `about/directory-index.js`, which lets the About page link board members to their directory profile.
6. The workflow commits generated profile/index changes to `main` and publishes the updated site to GitHub Pages.

Do not manually edit generated profile files unless an urgent one-off correction is necessary. The next directory run replaces files in these folders:

- `profiles/phd/`
- `profiles/ms/`
- `profiles/mdsh/`
- `profiles/phd-alumni/`
- `profiles/ms-alumni/`
- `profiles/mdsh-alumni/`

## Routine maintenance

### Start-of-year checklist

1. Update the Student Directory Form for the new cohort and confirm it still writes to the spreadsheet identified by the `STUDENT_DIRECTORY_URL` GitHub secret.
2. Update the deadline, explanatory copy, and form link in `directory.qmd`. The form announcement is near the top of that file.
3. Check that program names and cohort values in the form still match the script’s expected values. In particular, the program value `Master of Data Science in Public Health (MDSH)` is converted to `MDSH` by `make_profiles.R`.
4. Verify that the FERPA-consent response contains the exact consent text expected in `make_profiles.R`. Only rows with that response are published.
5. Confirm that the repository secrets below still point to accessible resources.
6. Submit one test response, run the workflow manually, and check the resulting profile and program listing before inviting all students to complete the form.

### During the year

- Ask new students to submit the form. Their profile should appear after the next scheduled run.
- Keep one FERPA-approved response row per student. If a student submits a replacement response rather than editing an existing one, remove the superseded row from the response sheet before the next run; the generator does not deduplicate submissions.
- Check the [GitHub Actions workflow](../.github/workflows/update_directory.yml) after an important update. Failed runs leave the existing published directory in place.
- Use the workflow’s **Run workflow** button for an immediate update. Choose **Force re-download all images** only when image files may be stale or damaged; it clears the reusable image cache and makes the run slower.

### After graduation

MS and MDSH students are moved to alumni automatically on July 1 of the year calculated from their cohort (start year + 2). PhD alumni are moved when their name, cohort, and graduation year match a row in the alumni spreadsheet.

To maintain this process, keep the alumni spreadsheet current and ensure its `First Name`, `Last Name`, `Cohort Year`, and `Graduation Year` values match the directory form as closely as possible. An alumni who opts out is excluded from alumni listings.

## Key files

| File or folder | Purpose |
| --- | --- |
| `make_profiles.R` | Main generator: reads the Sheets, applies FERPA and alumni rules, downloads photos, creates profiles, and exports anonymous statistics. |
| `build_directory_index.R` | Builds the name-to-profile lookup used on the About page after profiles have been rendered. |
| `directory.qmd` | Directory landing page, including the form announcement and its link/deadline. |
| `phd-students.qmd`, `ms-students.qmd`, `mdsh-students.qmd` | Current-student listings. |
| `alumni.qmd`, `phd-alumni.qmd`, `ms-alumni.qmd`, `mdsh-alumni.qmd` | Alumni landing and listing pages. |
| `profiles/_metadata.yml` | Shared layout settings for every profile. |
| `images/anon.jpg` | Fallback image when a student has no usable photo. |
| `styles.css` and `profiles/profile-styles.css` | Directory and profile presentation. |
| `.github/workflows/update_directory.yml` | Scheduled/manual generation, rendering, commit, and publishing workflow. |

## Form and data requirements

The profile generator relies on the response-column order and labels currently used by the forms. It removes the first four student-form columns before assigning the remaining fields, so rearranging, inserting, or deleting form questions can map data into the wrong profile fields.

Before changing the form structure, update the corresponding `select()`/`rename()` section in `make_profiles.R` and test with copied data first. The script currently supports program, cohort, preferred name, photo, UCLA email, candidacy, advisor, education, biography, and personal-link fields.

For a photo to be included, the form response must contain a Google Drive file link that includes `id=...`. If a photo cannot be downloaded, the profile uses `images/anon.jpg`.

The script standardizes common school and advisor names. Add recurring variants to `standardize_university()` or `standardize_advisor()` in `make_profiles.R` instead of making the same correction in generated profiles.

## Automation configuration

The workflow requires these repository secrets:

| Secret | Purpose |
| --- | --- |
| `GDRIVE_JSON` | Google service-account credentials with access to the response spreadsheets and uploaded photos. |
| `STUDENT_DIRECTORY_URL` | URL of the student directory response spreadsheet. |
| `ALUMNI_URL` | URL of the alumni spreadsheet. |
| `DIRECTORY_BOT_APP_ID` and `DIRECTORY_BOT_APP_PRIVATE_KEY` | GitHub App credentials used to commit generated profile/index updates and publish the site. |

Do not commit `.env`, `.secrets`, downloaded `.xlsx` files, the image cache, or credentials. Local copies of the form responses and downloaded directory photos are ignored intentionally.

## Running an update locally

Normally, use GitHub Actions. A local run is useful for development or diagnosing a problem, but it regenerates all profile folders, so begin from a clean working tree or keep any uncommitted work safely separate.

1. Install R, Quarto, and the R packages listed in the workflow: `tidyverse`, `googledrive`, `googlesheets4`, `glue`, `dotenv`, `here`, `writexl`, `readxl`, and `jsonlite`.
2. Create a local `.env` file from `.env.example`, adding `UCLA_EMAIL`, `STUDENT_DIRECTORY_URL`, and `ALUMNI_URL`. Alternatively, provide `GDRIVE_JSON` for service-account authentication.
3. From the repository root, run:

   ```sh
   Rscript directory/make_profiles.R
   quarto render
   Rscript directory/build_directory_index.R
   ```

4. Review the changed profiles, listings, and `about/directory-index.js` before committing. Generated site output in `docs/` is ignored locally; GitHub Actions handles publication.

If you are testing from previously downloaded spreadsheet files instead of Google Sheets, set `download_files <- FALSE` in `make_profiles.R`. The ignored files must be named `directory/directory_file.xlsx` and `directory/alumni_file.xlsx`.

## Troubleshooting

- **A student is missing:** confirm they submitted the form, selected the FERPA release exactly as required, and chose a supported program value. Then inspect the workflow log.
- **A profile has the wrong advisor or school spelling:** add a normalization rule in `make_profiles.R`, rerun the generator, and verify the listing filters.
- **A photo is missing or outdated:** check the Drive-sharing permissions and the response’s file link. Use the workflow’s force-redownload option if needed.
- **An alumnus is in the wrong section:** verify the cohort/year calculation for MS or MDSH, or the matching first name, last name, cohort, and graduation year in the alumni sheet for PhD.
- **The About-page directory link is missing:** confirm the profile rendered successfully, then rebuild `about/directory-index.js` with `build_directory_index.R`.

When correcting an automation issue, make the correction in the generator, form, or workflow—not only in the rendered HTML—so it persists on the next scheduled update.
