local shell = require("shell")

local nginx = {
  name = "Nginx",
}

function nginx.run(config, ctx)
  ctx.ui.step_info("Installing mainline Nginx")

  local domain = config.nginx.domain
  local conf_path = "/etc/nginx/conf.d/" .. domain .. ".conf"
  local keyring_path = "/usr/share/keyrings/nginx-archive-keyring.gpg"
  local repo_path = "/etc/apt/sources.list.d/nginx.list"
  local pin_path = "/etc/apt/preferences.d/99nginx"

  if ctx.backup then
    ctx.backup:save(conf_path)
    ctx.backup:save(keyring_path)
    ctx.backup:save(repo_path)
    ctx.backup:save(pin_path)
  end

  assert(shell.run("apt-get update"))
  local os_info = shell.capture(". /etc/os-release && echo $ID") or ""
  local is_ubuntu = os_info:match("ubuntu")
  local prereqs = is_ubuntu and "curl gnupg2 ca-certificates lsb-release ubuntu-keyring" or "curl gnupg2 ca-certificates lsb-release debian-archive-keyring"
  assert(shell.run("apt-get install -y " .. prereqs))

  assert(shell.run("curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee " .. shell.quote(keyring_path) .. " >/dev/null"))

  local dist = is_ubuntu and "ubuntu" or "debian"
  assert(shell.run("echo \"deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://nginx.org/packages/mainline/" .. dist .. " $(. /etc/os-release && echo $VERSION_CODENAME) nginx\" | tee " .. shell.quote(repo_path)))

  assert(shell.run("printf 'Package: *\\nPin: origin nginx.org\\nPin: release o=nginx\\nPin-Priority: 900\\n' | tee " .. shell.quote(pin_path)))

  assert(shell.run("apt-get update"))
  assert(shell.run("apt-get install -y nginx"))

  local template = shell.read("./templates/nginx/nginx.conf") or ""
  if template == "" then
    error("Nginx template is missing or empty: ./templates/nginx/nginx.conf")
  end

  if domain == "localhost" then
    template = template:gsub("/etc/letsencrypt/live/{{domain}}/fullchain%.pem", "/etc/ssl/certs/nginx-selfsigned.crt")
    template = template:gsub("/etc/letsencrypt/live/{{domain}}/privkey%.pem", "/etc/ssl/private/nginx-selfsigned.key")
  end

  template = template:gsub("{{domain}}", domain)
  assert(shell.write(conf_path, template))

  assert(shell.run("nginx -t"))
  assert(shell.run("systemctl enable nginx"))

  assert(shell.run("systemctl restart nginx"))

  ctx.ui.step_ok("Mainline Nginx installed and configured for " .. domain)
end

function nginx.rollback(config, ctx)
  local domain = config.nginx.domain
  shell.run("rm -f " .. shell.quote("/etc/nginx/conf.d/" .. domain .. ".conf"))
  shell.run("systemctl disable --now nginx")
  shell.run("apt-get remove -y nginx")
  shell.run("rm -f /etc/apt/sources.list.d/nginx.list /etc/apt/preferences.d/99nginx /usr/share/keyrings/nginx-archive-keyring.gpg")
end

return nginx
