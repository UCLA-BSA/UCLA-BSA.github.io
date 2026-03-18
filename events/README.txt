================================================================================
  UCLA BSA EVENTS PAGE — CSV FORMATTING GUIDE
================================================================================

--------------------------------------------------------------------------------
  EVENTS.CSV
--------------------------------------------------------------------------------

COLUMNS (in order):
  academic_year | title | description | location | date | time | link | photo | category

RULES:

  academic_year
    - Format: YY-YY  (e.g. 25-26)
    - Used for internal tracking only; not displayed on the page.

  title
    - Plain text. Keep it concise.
    - Example: Faculty Flash Talk I

  description
    - Plain text for simple descriptions.
    - Wrap in "double quotes" if your description contains commas or HTML.
    - Supports HTML formatting:
        Line break:         <br>
        Blank line:         <br><br>
        Non-breaking space: &nbsp;
        Bullet list:        <ul><li>Item one</li><li>Item two</li></ul>
    - Example (quoted):
        "Join us for lunch.<br><br>RSVP link coming soon!"
    - If left blank or set to "To Add", the card will show "Description coming soon."

  location
    - Plain text room/building name.
    - Example: CHS 43-105
    - Leave blank if TBD (nothing will show on the card).

  date
    - Format: M/D/YY  (e.g. 2/6/26 for February 6, 2026)
    - This controls whether the event appears under Upcoming or Past filters.
    - Events past today's date auto-move to "Past Events."

  time
    - Format: H:MM AM/PM  (e.g. 12:00 PM)
    - Displayed on the card alongside the date: "Feb 6, 2026 · 12:00 PM"
    - Leave blank if time is not yet known.

  link
    - Full URL starting with https://
    - Example: https://forms.gle/abc123
    - Shown as a "Learn More" button inside the event modal (popup).
    - Leave blank if there is no link.

  photo
    - Filename relative to the events/ folder.
    - All photos must be placed in:  events/images/
    - Example: images/lunchlearn_1.JPG
    - Accepted formats: .jpg, .JPG, .jpeg, .png, .webp
    - Use the word  placeholder  if you don't have a photo yet.
      A styled gradient box will show instead.

  category
    - Controls the color badge on the card.
    - Accepted values (case-sensitive):
        Lunch and Learn   → green badge
        Townhall          → blue badge
        Social            → orange badge
        Workshop          → purple badge
    - Any other value will show a default grey badge.

EXAMPLE ROW:
  25-26,Faculty Flash Talk I,"Join us for lunch & discussions!",NRB Auditorium,2/6/26,12:00 PM,https://forms.gle/abc123,images/lunchlearn_2.JPG,Lunch and Learn

ADDING NEW EVENTS:
  1. Add a new row at the bottom of events.csv.
  2. If using a photo, drop the image file into events/images/.
  3. Save the file — the page will update automatically on next build.

--------------------------------------------------------------------------------
  IMPORTANT-DATES.CSV
--------------------------------------------------------------------------------

COLUMNS (in order):
  title | link | date

RULES:

  title
    - Plain text name of the deadline or date.
    - Example: Student Directory Form

  link
    - Full URL starting with https://
    - Example: https://forms.gle/DiqSUUkwnZrd6wwCA
    - The title becomes a clickable link when this is filled in.
    - Leave blank if there is no link (just leave empty between the commas).

  date
    - Format: M/D/YY  (e.g. 4/3/26 for April 3, 2026)
    - Once the date has passed, the item auto-disappears from the page.
    - Items are sorted by soonest date first.

URGENCY COLOR CODING (automatic):
    Red dot    → due within 3 days
    Orange dot → due within 7 days
    Yellow dot → due within 14 days
    Green dot  → due more than 14 days away

EXAMPLE ROWS:
  title,link,date
  Student Directory Form,https://forms.gle/DiqSUUkwnZrd6wwCA,4/3/26
  T-Shirt Order Deadline,,4/10/26
  Alumni Mixer RSVP,https://example.com/rsvp,4/25/26

NOTES:
  - Leave a row completely blank (just commas: ,,) and it will be ignored.
  - Do NOT include a link column with just spaces — use nothing or a full URL.

--------------------------------------------------------------------------------
  PHOTOS & IMAGES
--------------------------------------------------------------------------------

  Where to put images:
    events/images/

  Naming tips:
    - No spaces in filenames. Use hyphens or underscores.
      Good:  lunchlearn_spring26.JPG
      Bad:   lunch learn spring 26.JPG
    - File extension is case-sensitive on some servers.
      If you use .JPG (uppercase), write it as .JPG in the CSV too.

  Recurring Events images (Lunch & Learn, Townhall):
    - These are set directly in events.qmd (not via CSV).
    - Look for the <img src="images/..."> tag inside the recurring section
      and update the filename there.

--------------------------------------------------------------------------------
  QUICK CHECKLIST WHEN ADDING A NEW EVENT
--------------------------------------------------------------------------------

  [ ] Added a row to events.csv with all 9 columns filled (or left blank)
  [ ] Date is in M/D/YY format
  [ ] Link starts with https:// (or is left blank)
  [ ] Photo file is in events/images/ and filename matches exactly
  [ ] Category matches one of the accepted values exactly

================================================================================
