# Launchpad

An opinionated Debian/Ubuntu blank virtual machine setup wizard for quickly creating my preferred baseline server configuration.

**Warning:** These are "sane defaults" tailored to my personal preferences. This tool will overwrite existing configuration files and is meant only to be used on a fresh, blank virtual machines. This project is a constant work in progress as my preferences and knowledge evolve.

## What it does

- creates an administrative user
- configures SSH hardening (customizable port, key import)
- sets up swap space
- raises configurable open file descriptor limits
- applies conservative kernel/sysctl settings
- enables an nftables firewall (with predefined profiles)
- installs and configures Fail2Ban
- enables unattended upgrades
- installs and enforces AppArmor profiles
- provides integrated support for Caddy (reverse proxy, rate limiting) and Nginx
- manages system hostname
- runs package cleanup
- supports dry-run mode
- saves backups before changing config files

## Current scope

This first version is intentionally Debian/Ubuntu oriented because it uses:

- `apt-get`
- `systemd`
- `nftables`
- `fail2ban`
- `unattended-upgrades`
- `apparmor`

## Run it

Install Lua if it is not already available, then run from this directory:

```bash
sudo apt-get update
sudo apt-get install -y lua5.4
sudo lua5.4 main.lua
```

The wizard must run as root because it writes system configuration under `/etc`, installs packages, manages services, and may update firewall/SSH settings.

## Files

- `main.lua` - interactive wizard and orchestration
- `ui.lua` - prompts, menus, and output helpers
- `shell.lua` - shell/file helpers
- `backup.lua` - backup and rollback support
- `config.lua` - profiles and defaults
- `validate.lua` - input validation helpers
- `modules/` - individual hardening modules:
  - `modules/apparmor.lua` - AppArmor profiles
  - `modules/caddy.lua` - Caddy web server/reverse proxy setup
  - `modules/certbot.lua` - Certbot/SSL certificates
  - `modules/cleanup.lua` - package cleanup
  - `modules/fail2ban.lua` - Fail2Ban configuration
  - `modules/firewall.lua` - nftables management
  - `modules/fstab.lua` - mount point hardening (nodev, nosuid, noexec)
  - `modules/hostname.lua` - system hostname
  - `modules/idle_timeout.lua` - automatic session logout after inactivity
  - `modules/kernel.lua` - sysctl hardening
  - `modules/keys.lua` - SSH key handling
  - `modules/limits.lua` - system limits (`nofile`)
  - `modules/nginx.lua` - Nginx web server setup
  - `modules/ssh.lua` - SSH daemon hardening
  - `modules/swap.lua` - swap file management
  - `modules/updates.lua` - unattended upgrades
  - `modules/users.lua` - administrative user creation

## Safety notes

- SSH uses a drop-in file at `/etc/ssh/sshd_config.d/99-launchpad.conf`.
- If root SSH login or password authentication is disabled, Launchpad requires an SSH public key for the administrative user before continuing. This is intended to reduce lockout risk.
- Firewall rules are written to `/etc/nftables.conf`. Confirm that your selected SSH port is reachable before closing your current session.
- Dry-run mode prints commands and skips writes. It also avoids reading absolute system paths where possible, but it is still a planning aid rather than a full VM simulation.
- Backups are stored under `/var/backups/launchpad/`.

## Web server notes

- Caddy configuration is generated from the wizard prompts and written to `/etc/caddy/Caddyfile`.
- If Caddy rate limiting is enabled, Launchpad builds Caddy with the `github.com/mholt/caddy-ratelimit` module using `xcaddy`.
- Nginx uses the template at `templates/nginx/nginx.conf` and writes a virtual host under `/etc/nginx/conf.d/`.
- For Nginx HTTPS, Launchpad obtains certificates before validating the final Nginx config:
  - `localhost` uses a self-signed certificate under `/etc/ssl/`.
  - real domains use `certbot certonly --standalone`, so DNS must point to the server and port `80` must be reachable.

## Rollback scope

Launchpad saves file backups before overwriting known configuration paths and module rollbacks remove many files created by the wizard. Rollback is useful for failed runs, but it is not yet a complete transaction system.

Current limitations include package installs/removals, some service state changes, and external side effects such as certificate issuance. Review rollback output before assuming the machine is exactly back to its initial state.

## Configuration paths

- Open file descriptor limits are set in `/etc/security/limits.d/99-launchpad.conf` and systemd drop-ins under `/etc/systemd/*.conf.d/`, using the configured `nofile` value.
- Kernel hardening uses `/etc/sysctl.d/99-launchpad.conf`.
- Unattended upgrades use `/etc/apt/apt.conf.d/20auto-upgrades` and `/etc/apt/apt.conf.d/50unattended-upgrades-hardener`.
- Idle timeout uses `/etc/profile.d/launchpad-timeout.sh`.

## Future plans under consideration

- add Billionmail custom mail server setup, current billionmail release has SSL bugs, the patch currently is too complex to handle in this repo, so waiting for it to be fixed upstream 
- add Podman or Docker + compose (though I don't use docker much anymore)
- add hardened Wireguard VPN configurations (not sure how to go about automate Amnezia-WG VPN)
- installation useful tools i used on virtual machines, micro, tmux, zoxide, fzf, ripgrep etc

## FAQ

##### Why "launchpad"?

Because this project acts as a starting point for me to quickly configure virtual machines as per my likings.

##### Why did I build this instead of using something like Ansible?

I set up new VMs all the time and manual setup is tedious and I swanted to experiment with Lua and I had these scripts individually as Bash scripts but reading Bash is torture for me. So i just translated them from Bash to Lua.   

###### Are these modules safe and thoroughly tested?

No.
