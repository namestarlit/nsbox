# Nginx Site Management

Purpose: enable or disable Nginx site config files by renaming them inside `/etc/nginx/conf.d`.

Problem solved: a lightweight way to toggle site configs without maintaining a separate `sites-enabled` and `sites-available` layout.

Script in this guide:

- `site.sh`: list, enable, or disable Nginx config files in `/etc/nginx/conf.d`

How it works:

- `example.com.conf` is treated as enabled
- `example.com.conf.disabled` is treated as disabled
- enabling/disabling is implemented by renaming the file
- Nginx config is tested before reload
- failed changes are rolled back automatically

Usage:

```bash
sudo bash guides/nginx-site-management/site.sh list
sudo bash guides/nginx-site-management/site.sh enable example.com
sudo bash guides/nginx-site-management/site.sh disable example.com
sudo bash guides/nginx-site-management/site.sh --conf-dir /etc/nginx/conf.d --suffix .disabled enable example.com
sudo bash guides/nginx-site-management/site.sh --conf-dir /etc/nginx/conf.d --suffix .disabled --dry-run enable example.com
```

Assumptions:

- Nginx configs live in `/etc/nginx/conf.d`
- the naming convention is `site-name.conf` and `site-name.conf.disabled`
- reloading Nginx is acceptable after each change
- the config directory and disabled suffix can be overridden if needed

Side effects:

- renames files in `/etc/nginx/conf.d`
- reloads Nginx after a successful config test

Risks:

- this is specific to one config layout and not a generic Nginx workflow
- it still assumes `/etc/nginx/conf.d` is the active config directory

Suggested verification:

```bash
sudo nginx -t
ls /etc/nginx/conf.d
```

Last Reviewed: 2026-03-11
