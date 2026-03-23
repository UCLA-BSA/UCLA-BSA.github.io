function hexboard(args, kwargs)
  local items = {}
  local i = 1
  local perrow_raw = kwargs["perrow"]
  local perrow = perrow_raw and tonumber(pandoc.utils.stringify(perrow_raw)) or 3

  while true do
    local href = kwargs["href" .. i]
    if not href then break end
    href = pandoc.utils.stringify(href)
    if href == "" then break end

    local name = pandoc.utils.stringify(kwargs["name" .. i] or "")
    local role = pandoc.utils.stringify(kwargs["role" .. i] or "")
    local img  = pandoc.utils.stringify(kwargs["img"  .. i] or "")

    items[i] = {href=href, name=name, role=role, img=img}
    i = i + 1
  end

  local total = #items

  local function make_hex(item)
    return '<div class="hex-wrap">' ..
      '<a href="' .. item.href .. '" class="hex-link">' ..
        '<div class="hex-border">' ..
          '<div class="hex-shape">' ..
            '<img src="' .. item.img .. '" alt="' .. item.name .. '"/>' ..
            '<div class="hex-label">' ..
              '<div class="hex-name">' .. item.name .. '</div>' ..
              '<div class="hex-role">' .. item.role .. '</div>' ..
            '</div>' ..
          '</div>' ..
         '</div>' ..
      '</a>' ..
    '</div>'
  end

  local row_data = {}
  local idx = 1
  while idx <= total do
    local row_items = {}
    for j = 1, perrow do
      if items[idx] then
        table.insert(row_items, items[idx])
        idx = idx + 1
      end
    end
    table.insert(row_data, row_items)
  end

  local rows = {}
  for r, row_items in ipairs(row_data) do
    local is_last = (r == #row_data)
    local is_full = (#row_items == perrow)
    local use_offset = (r % 2 == 0) and (not is_last or is_full)
    local cls = use_offset and 'hex-row hex-row-offset' or 'hex-row'
    local row_hexes = ""
    for _, item in ipairs(row_items) do
      row_hexes = row_hexes .. make_hex(item)
    end
    table.insert(rows, '<div class="' .. cls .. '">' .. row_hexes .. '</div>')
  end

  local grid = '<div class="hex-grid">' .. table.concat(rows) .. '</div>'
  return pandoc.RawBlock("html", grid)
end