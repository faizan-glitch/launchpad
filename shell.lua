local shell = {
  dry_run = false,
}

local function dirname(path)
  return path:match("^(.*)/[^/]+$") or "."
end

local function quote(value)
  return "'" .. tostring(value):gsub("'", [['"'"']]) .. "'"
end

function shell.set_dry_run(flag)
  shell.dry_run = not not flag
end

function shell.is_dry_run()
  return shell.dry_run
end

function shell.quote(value)
  return quote(value)
end

function shell.join(parts)
  local out = {}

  for i, part in ipairs(parts) do
    out[#out + 1] = quote(part)
  end

  return table.concat(out, " ")
end

function shell.exists(path)
  if shell.dry_run and tostring(path):sub(1, 1) == "/" then
    print("> [dry-run] test -e " .. path)
    return false
  end

  local file = io.open(path, "r")
  if file then
    file:close()
    return true
  end

  return false
end

function shell.read(path)
  if shell.dry_run and tostring(path):sub(1, 1) == "/" then
    print("> [dry-run] read " .. path)
    return nil, "dry-run: skipped reading system path"
  end

  local file, err = io.open(path, "r")
  if not file then
    return nil, err
  end

  local content = file:read("*a")
  file:close()
  return content
end

function shell.write(path, content)
  if shell.dry_run then
    print("> [dry-run] write " .. path)
    return true
  end

  local dir = dirname(path)
  local ok = os.execute("mkdir -p " .. quote(dir))
  if ok ~= true and ok ~= 0 then
    return nil, "failed to create directory: " .. dir
  end

  local file, err = io.open(path, "w")
  if not file then
    return nil, err
  end

  file:write(content)
  file:close()
  return true
end

function shell.run(cmd)
  if shell.dry_run then
    print("> [dry-run] " .. cmd)
    return true
  end

  io.write("> ")
  print(cmd)

  local ok, _, code = os.execute(cmd)
  if ok == true or ok == 0 then
    return true
  end

  return nil, code or ok
end

function shell.capture(cmd)
  if shell.dry_run then
    print("> [dry-run] capture " .. cmd)
    return ""
  end

  local pipe, err = io.popen(cmd .. " 2>/dev/null")
  if not pipe then
    return nil, err
  end

  local output = pipe:read("*a")
  pipe:close()
  output = output or ""
  output = output:gsub("%s+$", "")
  return output
end

return shell
