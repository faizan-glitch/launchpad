local ui = {}

function ui.banner()
  print("")
  print("=====================================")
  print("   VM Hardening Wizard (Launchpad)  ")
  print("=====================================")
  print("")
end

function ui.ask(prompt, default)
  io.write(prompt)
  if default ~= nil and default ~= "" then
    io.write(" [" .. tostring(default) .. "]")
  end
  io.write(": ")

  local answer = io.read()
  if answer == nil then
    return default
  end

  answer = answer:gsub("^%s+", ""):gsub("%s+$", "")
  if answer == "" then
    return default
  end

  return answer
end

function ui.ask_yes_no(prompt, default)
  local hint = "[y/N]"
  local default_value = false

  if default == true then
    hint = "[Y/n]"
    default_value = true
  end

  while true do
    io.write(prompt .. " " .. hint .. ": ")
    local answer = io.read()

    if answer == nil or answer == "" then
      return default_value
    end

    answer = answer:lower():gsub("^%s+", ""):gsub("%s+$", "")

    if answer == "y" or answer == "yes" then
      return true
    end

    if answer == "n" or answer == "no" then
      return false
    end

    print("Please answer yes or no.")
  end
end

function ui.choose(prompt, choices, default_index)
  print(prompt)
  for i, choice in ipairs(choices) do
    print(string.format("%d) %s", i, choice.label))
  end
  io.write("> ")

  while true do
    local answer = io.read()
    if answer == nil or answer == "" then
      return choices[default_index or 1]
    end

    local index = tonumber(answer)
    if index and choices[index] then
      return choices[index]
    end

    print("Please enter a valid choice number.")
    io.write("> ")
  end
end

function ui.multiselect(title, items)
  local function render()
    ui.section(title)
    for i, item in ipairs(items) do
      local mark = item.enabled and "[x]" or "[ ]"
      print(string.format("%d) %s %s", i, mark, item.label))
    end
    print("Enter numbers to toggle, comma-separated, or press Enter to continue.")
    io.write("> ")
  end

  while true do
    render()
    local answer = io.read()
    if answer == nil or answer == "" then
      return items
    end

    for token in answer:gmatch("[^,%s]+") do
      local index = tonumber(token)
      if index and items[index] then
        items[index].enabled = not items[index].enabled
      end
    end
  end
end

function ui.section(title)
  print("")
  print(title)
  print(string.rep("-", #title))
end

function ui.step_ok(message)
  print("[✓] " .. message)
end

function ui.step_fail(message)
  print("[x] " .. message)
end

function ui.step_info(message)
  print("[·] " .. message)
end

function ui.print_kv(key, value)
  print(string.format("%-20s %s", key .. ":", value))
end

return ui
