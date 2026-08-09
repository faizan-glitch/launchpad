local shell = require("shell")

local fstab = {
  name = "Fstab hardening",
}

local function harden_options(options)
  local seen = {}
  local ordered = {}

  for option in tostring(options):gmatch("[^,]+") do
    if option ~= "" and not seen[option] then
      seen[option] = true
      ordered[#ordered + 1] = option
    end
  end

  for _, option in ipairs({ "nodev", "nosuid", "noexec" }) do
    if not seen[option] then
      seen[option] = true
      ordered[#ordered + 1] = option
    end
  end

  return table.concat(ordered, ",")
end

function fstab.run(config, ctx)
  local fstab_path = "/etc/fstab"

  if ctx.backup then
    ctx.backup:save(fstab_path)
  end

  local content = shell.read(fstab_path) or ""
  local targets = {
    ["/tmp"] = true,
    ["/var/tmp"] = true,
    ["/dev/shm"] = true,
  }
  local lines = {}
  local changed = 0
  local matched = 0

  for line in (content .. "\n"):gmatch("(.-)\n") do
    local prefix = line:match("^(%s*)") or ""
    local first = line:match("^%s*(%S+)")

    if first and first:sub(1, 1) ~= "#" then
      local spec, mount, fstype, options, rest = line:match("^%s*(%S+)%s+(%S+)%s+(%S+)%s+(%S+)(.*)$")
      if spec and targets[mount] then
        matched = matched + 1
        local new_options = harden_options(options)
        if new_options ~= options then
          changed = changed + 1
        end
        line = string.format("%s%s\t%s\t%s\t%s%s", prefix, spec, mount, fstype, new_options, rest or "")
      end
    end

    lines[#lines + 1] = line
  end

  assert(shell.write(fstab_path, table.concat(lines, "\n")))

  if matched == 0 then
    ctx.ui.step_info("No /tmp, /var/tmp, or /dev/shm entries found in /etc/fstab")
  elseif changed == 0 then
    ctx.ui.step_ok("/etc/fstab hardening options were already present")
  else
    ctx.ui.step_ok("Hardened " .. tostring(changed) .. " /etc/fstab entr" .. (changed == 1 and "y" or "ies"))
  end
end

function fstab.rollback(config, ctx)
  -- Rollback handled by backup system
end

return fstab
