# Ingress

## Docker run NGINX

```bash
docker run \
  --rm \
  --detach \
  --publish 8080:80 \
  --name nginx \
  nginx:1.23.1

docker ps | egrep "CONTAINER|nginx"

curl -i http://localhost:8080

HTML_FILE="${PWD}/static/index.html"

if [ -e "${HTML_FILE?}" ]; then
  docker run \
    --rm \
    --detach \
    --volume "${HTML_FILE?}:/usr/share/nginx/html/index.html:ro" \
    --publish 8081:80 \
    --name nginx-customized \
    nginx:1.23.1
else
  echo "File \"${HTML_FILE}\" doesn't exists."
fi

docker ps | egrep "CONTAINER|nginx"

curl -i http://localhost:8081

docker kill nginx nginx-customized
```

## Docker run httpbin

```bash
docker run \
  --rm \
  --detach \
  --publish 8080:80 \
  --name httpbin \
  kennethreitz/httpbin:latest

docker ps | egrep "CONTAINER|httpbin"

curl -i http://localhost:8080/get

docker kill httpbin
```

## Create a Kind Cluster

```bash
kind/creation
```

## NGINX Ingress Controller Install

```bash
nginx/install
```

## Deploy httpbin

Execute it from a new terminal window:

```bash
kubectl create namespace example

kubectl apply \
  --namespace example \
  --filename httpbin/deployment.yaml

kubectl apply \
  --namespace example \
  --filename httpbin/service.yaml
```

## Ingress for httpbin

```bash
kubectl apply \
  --namespace example \
  --filename httpbin/ingress.yaml
```

## Ingress with TLS for httpbin

```bash
BASE_DOMAIN="sandbox.wasp.silvios.me"
DNS_ZONE_NAME="${BASE_DOMAIN}"
DNS_ZONE_RESOURCE_GROUP_NAME="wasp-foundation"

# Install certbot
sudo apt-get install certbot

# Request a valid Wildcard Let's Encrypt Certificate using certbot
certbot certonly \
  --manual \
  --preferred-challenges dns \
  --agree-tos \
  --email "certificates@example.com" \
  --no-eff-email \
  --server "https://acme-v02.api.letsencrypt.org/directory" \
  -d *.${BASE_DOMAIN?} \
  -d *.apps.${BASE_DOMAIN?} \
  -d *.services.${BASE_DOMAIN?} \
  --config-dir "${HOME}/certificates/config" \
  --work-dir "${HOME}/certificates/work" \
  --logs-dir "${HOME}/certificates/logs"

# Azure DNS
az network dns record-set txt \
  add-record \
  --zone-name ${DNS_ZONE_NAME?} \
  --resource-group ${DNS_ZONE_RESOURCE_GROUP_NAME?} \
  --record-set-name "_acme-challenge.apps" \
  --value "TXT_VALUE_HERE"

az network dns record-set txt \
  add-record \
  --zone-name ${DNS_ZONE_NAME?} \
  --resource-group ${DNS_ZONE_RESOURCE_GROUP_NAME?} \
  --record-set-name "_acme-challenge" \
  --value "TXT_VALUE_HERE"

az network dns record-set txt \
  add-record \
  --zone-name ${DNS_ZONE_NAME?} \
  --resource-group ${DNS_ZONE_RESOURCE_GROUP_NAME?} \
  --record-set-name "_acme-challenge.services" \
  --value "TXT_VALUE_HERE"

# Check TXT Records
dig @8.8.8.8 +short "_acme-challenge.apps.${BASE_DOMAIN?}" TXT
dig @8.8.8.8 +short "_acme-challenge.${BASE_DOMAIN?}" TXT
dig @8.8.8.8 +short "_acme-challenge.services.${BASE_DOMAIN?}" TXT

# Create a Secret from the Generated Certificate
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

# Create a TLS Secret with the Certificate
kubectl \
  --namespace example \
  create secret tls \
  tls-wildcard-full-chain \
  --key "${CERTIFICATE_PRIVATE_KEY?}" \
  --cert "${CERTIFICATE_FULL_CHAIN?}"

kubectl apply \
  --namespace example \
  --filename httpbin/ingress-tls.yaml

# Add an entry on /etc/hosts if needed
grep echo.${BASE_DOMAIN?} /etc/hosts || \
echo "127.0.0.1 echo.${BASE_DOMAIN?}" \
| sudo tee -a /etc/hosts

# HTTPS Test Request
curl \
  --include \
  https://echo.${BASE_DOMAIN?}/get
```

## Commands

```bash
# Use netcat to check port 80 availability
nc -dv 127.0.0.1 80

# Show IPv4 information
ip -4 a

# List Docker Networks
docker network ls

# Inspect Docker Network for Kind Cluster
docker network inspect <docker-network-bridge-id>

# Test non TLS Ingress
curl \
  --include \
  --header 'host: xpto.example.com' \
  http://127.0.0.1:80/get
```

## Cleanup

```bash
# Remove the entry from /etc/hosts
sudo sed -i '/echo.${BASE_DOMAIN?}/d' /etc/hosts

# Delete Kind Cluster
kind delete cluster
```
