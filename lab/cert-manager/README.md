# Usando cert-manager com AKS e Istio

## 1. Crie um AKS Cluster

Você pode usar [este](../../install/aks/create-cluster.sh) Script que usa o Azure CLI.

## 2. Instale o Istio Operator

Instale o Istio executando [este](../istio/04-istio-operator-install.sh) script.

Verifique a annotation ```service.beta.kubernetes.io/azure-dns-label-name``` pois o valor especificado irá criar um registro DNS nesse formato:

```bash
silvios-dev.eastus2.cloudapp.azure.com
```

Ative o injection no namespace desejado:

```bash
kubectl label namespace default istio-injection=enabled
```

## 3. Instale o cert-manager

Instale o cert-manager executando [este](install.sh) script.

## 4. Execute o Deployment do httpbin e demais objetos Istio

Abra um terminal na pasta ```helm``` e execute um Helm Template aplicando no Cluster:

```bash
helm template . | kubectl apply -f -
```

## 5. Obtendo os Arquivos gerados

```bash
kubectl --namespace istio-system get secret istio-ingress-tls -o json | jq '.data."tls.key"' -r | base64 -d > istio-ingress-tls.key.pem

kubectl --namespace istio-system get secret istio-ingress-tls -o json | jq '.data."tls.crt"' -r | base64 -d > istio-ingress-tls.crt.pem
```
## 6. Gerando nova TLS Secret

```bash
kubectl create secret tls \
  tls-apps-silvios-me \
  --key istio-ingress-tls.key.pem \
  --cert istio-ingress-tls.crt.pem
```
