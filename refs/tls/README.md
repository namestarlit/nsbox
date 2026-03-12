# TLS References

This directory contains SSL/TLS certificate issuance and renewal scripts.

Use this directory when:

- you need to issue a new Let's Encrypt certificate
- you need to renew an existing certificate
- you want to compare Nginx, standalone, and manual DNS issuance flows before choosing one

Scripts in this directory:

- `create_ssl_cert_nginx.sh`: obtain a certificate through the Nginx plugin
- `create_ssl_cert_standalone.sh`: obtain a certificate with standalone mode
- `create_wildcard_ssl_cert_manually.sh`: obtain a wildcard certificate through manual DNS validation
- `renew_cert.sh`: renew an existing certificate and reload Nginx after validation

Typical usage:

```bash
# Issue a certificate using the nginx plugin
sudo bash refs/tls/create_ssl_cert_nginx.sh example.com admin@example.com

# Issue a certificate in standalone mode
sudo bash refs/tls/create_ssl_cert_standalone.sh example.com admin@example.com

# Issue a wildcard certificate with manual DNS steps
sudo bash refs/tls/create_wildcard_ssl_cert_manually.sh example.com admin@example.com

# Renew an existing certificate
sudo bash refs/tls/renew_cert.sh example.com

# Preview the renewal command even if the local cert path is absent
sudo bash refs/tls/renew_cert.sh example.com --dry-run
```

Notes:

- `create_ssl_cert_nginx.sh`
  Use when Nginx is already serving the site and the certbot Nginx plugin is the easiest path.

- `create_ssl_cert_standalone.sh`
  Use when you can temporarily stop Nginx and let certbot bind directly to port 80.

- `create_wildcard_ssl_cert_manually.sh`
  Use when you need a wildcard certificate and can complete the DNS challenge manually.

- `renew_cert.sh`
  Use when a certificate already exists and you want to renew it and reload Nginx after validation.

- review each script before use because certbot behavior and infrastructure constraints can change

Last Reviewed: 2026-03-11
