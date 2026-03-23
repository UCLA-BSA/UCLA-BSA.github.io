function navcard(args, kwargs)
  local color = pandoc.utils.stringify(kwargs["color"] or "#2774AE")
  local preview_raw = kwargs["preview"]
  local preview = preview_raw and tonumber(pandoc.utils.stringify(preview_raw)) or nil

  local items = ""
  local i = 1

  while true do
    local href = kwargs["href" .. i]
    if not href then break end
    href = pandoc.utils.stringify(href)
    if href == "" then break end

    local label  = pandoc.utils.stringify(kwargs["label" .. i] or "")
    local meta   = pandoc.utils.stringify(kwargs["meta"  .. i] or "")
    local hidden = (preview and i > preview) and ' class="important-date-item navcard-item navcard-hidden"' or ' class="important-date-item navcard-item"'

items = items ..
  '<a href="' .. href .. '" target="_blank" ' .. hidden .. ' style="text-decoration:none; border-left:4px solid ' .. color .. ';">' ..
    '<span class="date-item-title">' .. label .. '</span>' ..
    '<span style="color:#666; font-size:0.82rem;">' .. meta .. '</span>' ..
  '</a>'

    i = i + 1
  end

  local total = i - 1
  local btn = ""
  if preview and total > preview then
    btn = '<button onclick="' ..
  'var cards=this.parentNode.querySelectorAll(\'.navcard-hidden\');' ..
  'cards.forEach(function(c){c.classList.remove(\'navcard-hidden\');});' ..
  'this.style.display=\'none\';' ..
  '" style="margin-top:0.5rem; background:none; border:none; color:#2774AE; font-weight:600; cursor:pointer; font-size:0.9rem; padding:0;">' ..
  'Show all ' .. total .. ' →</button>'
  end

  return pandoc.RawBlock("html", '<div class="navcard-group">' .. items .. btn .. '</div>')
end