# certbot

## Installation

```bash
sudo apt update
sudo apt install --yes python3 python3-venv libaugeas0
sudo python3 -m venv /opt/certbot/
sudo /opt/certbot/bin/pip install --upgrade pip
sudo /opt/certbot/bin/pip install certbot certbot
sudo ln -s /opt/certbot/bin/certbot /usr/bin/certbot

certbot --version
```

## Setup Certificate's Directory

```bash
mkdir --parents "${HOME}/certificates/"
```

## Staging Let's Encrypt Wildcard Certificate

```bash
cat <<'EOF' > /tmp/certbot.env
base_domain="sandbox.wasp.silvios.me"
lets_encrypt_server_staging="acme-staging-v02"
lets_encrypt_server_production="acme-v02"
lets_encrypt_server=${lets_encrypt_server_staging?}
lets_encrypt_alert_email="$(git config --get user.email)"
certificate_directory="${HOME}/certificates/config/live/${base_domain?}"
certificate_private_key="${certificate_directory?}/privkey.pem"
certificate_full_chain="${certificate_directory?}/fullchain.pem"

cat <<EOC
lets_encrypt_server......: ${lets_encrypt_server}
base_domain..............: ${base_domain}
lets_encrypt_alert_email.: ${lets_encrypt_alert_email}
certificate_directory....: ${certificate_directory}
certificate_private_key..: ${certificate_private_key}
certificate_full_chain...: ${certificate_full_chain}
EOC
EOF

source /tmp/certbot.env

certbot certonly \
  --manual \
  --preferred-challenges dns \
  --agree-tos \
  --email "${lets_encrypt_alert_email?}" \
  --no-eff-email \
  --server "https://${lets_encrypt_server?}.api.letsencrypt.org/directory" \
  -d *.${base_domain?} \
  -d *.services.${base_domain?} \
  --config-dir "${HOME}/certificates/config" \
  --work-dir "${HOME}/certificates/work" \
  --logs-dir "${HOME}/certificates/logs"

# Check TXT Records (alternative method: https://dnschecker.org)
source /tmp/certbot.env
dig @8.8.8.8 +short TXT "_acme-challenge.${base_domain?}"
dig @8.8.8.8 +short TXT "_acme-challenge.services.${base_domain?}"

# Show Certificate Files
source /tmp/certbot.env

# Show Certificate Information
openssl x509 \
  -in "${certificate_full_chain?}" \
  -noout \
  -subject \
  -issuer \
  -ext subjectAltName \
  -nameopt lname \
  -nameopt sep_multiline \
  -dates

# Create a TLS Secret using the Certificate
kubectl \
  --namespace example \
  create secret tls \
  tls-wasp-silvios-me \
  --key "${certificate_private_key?}" \
  --cert "${certificate_full_chain?}"

# Show Certificate Information
openssl x509 \
  -in "${certificate_full_chain?}" \
  -noout \
  -subject \
  -issuer \
  -ext subjectAltName \
  -nameopt lname \
  -nameopt sep_multiline \
  -dates

# Generate PFX Certificate file
openssl pkcs12 \
  -export \
  -inkey "${certificate_private_key?}" \
  -in    "${certificate_full_chain?}" \
  -out   "${certificate_directory?}/certificate.pfx"

# Retrieve pfx file information
openssl pkcs12 \
  -in "${certificate_directory?}/certificate.pfx" \
  -info \
  -nokeys
```
