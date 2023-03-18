# certbot

## Installation

```bash
sudo apt update
sudo apt install python3 python3-venv libaugeas0
sudo python3 -m venv /opt/certbot/
sudo /opt/certbot/bin/pip install --upgrade pip
sudo /opt/certbot/bin/pip install certbot certbot
sudo ln -s /opt/certbot/bin/certbot /usr/bin/certbot

certbot --version
```

## Setup Certificate's Directory

```bash
mkdir -p "${HOME}/certificates/"
```

## Staging Let's Encrypt Wildcard Certificate

```bash
BASE_DOMAIN="sandbox.wasp.silvios.me"
LETS_ENCRYPT_SERVER_STAGING="acme-staging-v02"
LETS_ENCRYPT_SERVER_PRODUCTION="acme-v02"
LETS_ENCRYPT_SERVER=${LETS_ENCRYPT_SERVER_STAGING?}

certbot certonly \
  --manual \
  --preferred-challenges dns \
  --agree-tos \
  --email "smsilva@gmail.com" \
  --no-eff-email \
  --server "https://${LETS_ENCRYPT_SERVER?}.api.letsencrypt.org/directory" \
  -d *.${BASE_DOMAIN?} \
  -d *.services.${BASE_DOMAIN?} \
  --config-dir "${HOME}/certificates/config" \
  --work-dir "${HOME}/certificates/work" \
  --logs-dir "${HOME}/certificates/logs"

# Check TXT Records (alternative method: https://dnschecker.org)
dig @8.8.8.8 +short "_acme-challenge.${BASE_DOMAIN?}" TXT
dig @8.8.8.8 +short "_acme-challenge.services.${BASE_DOMAIN?}" TXT

# Certificate Files
CERTIFICATE_DIRECTORY="${HOME}/certificates/config/live/${BASE_DOMAIN?}"
CERTIFICATE_PRIVATE_KEY="${CERTIFICATE_DIRECTORY?}/privkey.pem"
CERTIFICATE_FULL_CHAIN="${CERTIFICATE_DIRECTORY?}/fullchain.pem"

# Show Certificate Information
openssl x509 \
  -in "${CERTIFICATE_FULL_CHAIN?}" \
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
  tls-services-sandbox-wasp-silvios-me \
  --key "${CERTIFICATE_PRIVATE_KEY?}" \
  --cert "${CERTIFICATE_FULL_CHAIN?}"
```
