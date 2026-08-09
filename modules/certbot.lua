local shell = require("shell")

local certbot = {
  name = "Certbot SSL",
}

function certbot.run(config, ctx)
  local domain = config.nginx.domain
  local email = config.email or ("admin@" .. domain)

  if domain == "localhost" then
    local cert_path = "/etc/ssl/certs/nginx-selfsigned.crt"
    local key_path = "/etc/ssl/private/nginx-selfsigned.key"

    ctx.ui.step_info("Preparing self-signed SSL for localhost")
    assert(shell.run("apt-get update"))
    assert(shell.run("apt-get install -y openssl"))
    assert(shell.run("mkdir -p /etc/ssl/private /etc/ssl/certs"))

    if not shell.exists(cert_path) or not shell.exists(key_path) then
      ctx.ui.step_info("Generating new self-signed SSL for localhost")
      assert(shell.run(
        "openssl req -x509 -nodes -days 365 -newkey rsa:2048 " ..
        "-keyout " .. shell.quote(key_path) .. " " ..
        "-out " .. shell.quote(cert_path) .. " " ..
        "-subj '/C=US/ST=State/L=City/O=Development/CN=localhost'"
      ))

      assert(shell.run("chmod 600 " .. shell.quote(key_path)))
      assert(shell.run("chmod 644 " .. shell.quote(cert_path)))
      ctx.state.certbot_created_self_signed = true
      ctx.ui.step_ok("Self-signed SSL generated for localhost")
    else
      ctx.ui.step_ok("Self-signed SSL already exists for localhost")
    end
    return
  end

  local live_cert = "/etc/letsencrypt/live/" .. domain .. "/fullchain.pem"
  ctx.state.certbot_created_certificate = not shell.exists(live_cert)
  if not ctx.state.certbot_created_certificate then
    ctx.ui.step_ok("Existing SSL certificate found for " .. domain)
    return
  end

  ctx.ui.step_info("Installing Certbot and generating standalone SSL for " .. domain)

  assert(shell.run("apt-get update"))
  assert(shell.run("apt-get install -y certbot"))

  if shell.run("systemctl is-active --quiet nginx") then
    assert(shell.run("systemctl stop nginx"))
  end

  assert(shell.run(
    "certbot certonly --standalone -d " .. shell.quote(domain) ..
    " --email " .. shell.quote(email) ..
    " --agree-tos --non-interactive --preferred-challenges http"
  ))

  ctx.ui.step_ok("SSL certificate generated for " .. domain)
end

function certbot.rollback(config, ctx)
  local domain = config.nginx.domain

  if domain == "localhost" then
    if ctx.state and ctx.state.certbot_created_self_signed then
      shell.run("rm -f /etc/ssl/certs/nginx-selfsigned.crt /etc/ssl/private/nginx-selfsigned.key")
    end
    return
  end

  if ctx.state and ctx.state.certbot_created_certificate then
    shell.run("certbot delete --cert-name " .. shell.quote(domain) .. " --non-interactive")
  end
end

return certbot
