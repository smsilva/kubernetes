# Ingress

## Docker run NGINX

```bash
# NGINX Default Container
docker run \
  --detach \
  --publish 8080:80 \
  --name nginx \
  nginx:1.23.1

# NGINX Customized Container
HTML_FILE="${PWD}/static/index.html"

if [ -e "${HTML_FILE?}" ]; then
  docker run \
    --detach \
    --volume "${HTML_FILE?}:/usr/share/nginx/html/index.html:ro" \
    --publish 8081:80 \
    --name nginx-customized \
    nginx:1.23.1
else
  echo "File \"${HTML_FILE}\" doesn't exists."
fi

# List running NGINX Containers
docker ps | egrep "CONTAINER|nginx"

# Test 1
curl -is http://localhost:8080 \
| egrep "200|title.*Welcome to nginx"

# Test 2
curl -is http://localhost:8081 \
| egrep "200|title.*Static"

# Cleanup
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

```bash
kubectl create namespace example

kubectl apply \
  --namespace example \
  --filename httpbin/deployment.yaml

kubectl apply \
  --namespace example \
  --filename httpbin/service.yaml
```

## Ingress for httpbin (no TLS)

```bash
# Create Ingress
kubectl apply \
  --namespace example \
  --filename httpbin/ingress.yaml

# Test
curl \
  --include \
  --header 'host: app.example.com' \
  http://127.0.0.1:80/get

# Delete Ingress
kubectl delete \
  --namespace example \
  --filename httpbin/ingress.yaml
```

## Ingress with TLS for httpbin with Selfsigned Certificate

```bash
CERTIFICATE_DIRECTORY="${HOME}/certificates/selfsigned/example.com"
CERTIFICATE_PRIVATE_KEY="${CERTIFICATE_DIRECTORY?}/certificate.key.pem"
CERTIFICATE_FILE="${CERTIFICATE_DIRECTORY?}/certificate.pem"

mkdir -p "${CERTIFICATE_DIRECTORY?}"

# Generate a Self Signed Certificate
openssl req \
  -x509 \
  -newkey rsa:4096 \
  -nodes \
  -keyout "${CERTIFICATE_PRIVATE_KEY?}" \
  -out "${CERTIFICATE_FILE?}" \
  -days 365 \
  -subj '/CN=echo.example.com'

# Create a Secret with the Selfsigned Certificate
kubectl \
  --namespace example \
  create secret tls \
  tls-selfsigned \
  --key "${CERTIFICATE_PRIVATE_KEY?}" \
  --cert "${CERTIFICATE_FILE?}"

# Create an Ingress Resource
kubectl apply \
  --namespace example \
  --filename httpbin/ingress-tls-selfsigned.yaml

# Add an entry on /etc/hosts if needed
grep "echo.example.com" /etc/hosts || \
echo "127.0.0.1 echo.example.com" \
| sudo tee -a /etc/hosts

# HTTPS Test Request
curl \
  --insecure \
  --include \
  https://echo.example.com/get

# Delete Ingress
kubectl delete \
  --namespace example \
  --filename httpbin/ingress-tls-selfsigned.yaml
```

## Ingress with TLS for httpbin with a Valid Let's Encrypt Wildcard Certificate

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
  --email "must-be-valid-account@example.com" \
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

# Check TXT Records (alternative method: https://dnschecker.org)
dig @8.8.8.8 +short "_acme-challenge.${BASE_DOMAIN?}" TXT
dig @8.8.8.8 +short "_acme-challenge.apps.${BASE_DOMAIN?}" TXT
dig @8.8.8.8 +short "_acme-challenge.services.${BASE_DOMAIN?}" TXT

# Create a Secret using the Generated Certificate
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
  tls-wildcard-full-chain \
  --key "${CERTIFICATE_PRIVATE_KEY?}" \
  --cert "${CERTIFICATE_FULL_CHAIN?}"

# Create Ingress
kubectl apply \
  --namespace example \
  --filename httpbin/ingress-tls-wildcard.yaml

# Add an entry on /etc/hosts if needed
grep echo.${BASE_DOMAIN?} /etc/hosts || \
echo "127.0.0.1 echo.${BASE_DOMAIN?}" \
| sudo tee -a /etc/hosts

# HTTPS Test Request
curl \
  --include \
  https://echo.${BASE_DOMAIN?}/get

# Generate PFX Certificate file
openssl pkcs12 \
  -export \
  -inkey "${CERTIFICATE_PRIVATE_KEY?}" \
  -in    "${CERTIFICATE_FULL_CHAIN?}" \
  -out   "${CERTIFICATE_DIRECTORY?}/certificate.pfx"

# Retrieve pfx file information
openssl pkcs12 \
  -in "${CERTIFICATE_DIRECTORY?}/certificate.pfx" \
  -info \
  -nokeys
```

## Commands

```bash
# Follow Resource Changes
watch -n 3 'kubectl -n example get deploy,pods,svc,endpoints,ingress -o wide'

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

# Show Certificate Information
openssl x509 \
  -in "cert.pem" \
  -noout \
  -subject \
  -issuer \
  -ext subjectAltName \
  -nameopt lname \
  -nameopt sep_multiline \
  -dates

# Certificate Info
REMOTE_HOST_NAME="echo.example.com" && \
echo \
| openssl s_client \
    -connect "${REMOTE_HOST_NAME?}":443 2>/dev/null \
| openssl x509 \
    -noout \
    -subject \
    -issuer \
    -ext subjectAltName \
    -nameopt lname \
    -nameopt sep_multiline \
    -dates
```

## Cleanup

```bash
# Remove the entry from /etc/hosts
sudo sed -i '/echo.${BASE_DOMAIN?}/d' /etc/hosts

# Delete Kind Cluster
kind delete cluster
```
