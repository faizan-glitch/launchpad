local shell = require("shell")

local backup = {}
backup.__index = backup

local function timestamp()
  return os.date("%Y%m%d-%H%M%S")
end

local function dirname(path)
  return path:match("^(.*)/[^/]+$") or "."
end

function backup.new(root_dir)
  local self = setmetatable({}, backup)
  self.root_dir = root_dir or "/var/backups/launchpad"
  self.saved = {}
  self.created = {}

  if shell.is_dry_run() then
    self.backup_dir = "[dry-run: no backups created]"
  else
    self.backup_dir = self.root_dir .. "/" .. timestamp()
    shell.run("mkdir -p " .. shell.quote(self.backup_dir))
  end

  return self
end

function backup:save(path)
  if shell.is_dry_run() then
    return false
  end

  if not shell.exists(path) then
    return false
  end

  local destination = self.backup_dir .. path
  shell.run("mkdir -p " .. shell.quote(dirname(destination)))
  local ok = shell.run("cp -a " .. shell.quote(path) .. " " .. shell.quote(destination))
  if ok then
    self.saved[#self.saved + 1] = { original = path, backup = destination }
    return true
  end

  return false
end

function backup:track_created(path)
  if shell.is_dry_run() then
    return
  end

  self.created[#self.created + 1] = path
end

function backup:restore()
  if shell.is_dry_run() then
    return
  end

  for i = #self.saved, 1, -1 do
    local item = self.saved[i]
    shell.run("mkdir -p " .. shell.quote(dirname(item.original)))
    shell.run("cp -a " .. shell.quote(item.backup) .. " " .. shell.quote(item.original))
  end

  for i = #self.created, 1, -1 do
    shell.run("rm -f " .. shell.quote(self.created[i]))
  end
end

return backup
