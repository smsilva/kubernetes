# Usando cert-manager com AKS e Istio

## 1. Crie um AKS Cluster

Você pode usar [este](../../install/aks/00-creation.sh) Script que usa o Azure CLI.

## 2. Instale o Istio Operator

Instale o Istio executando [este](../istio/04-istio-operator-install.sh) script.

Verifique a annotation ```service.beta.kubernetes.io/azure-dns-label-name``` pois o valor especificado irá criar um registro DNS nesse formato:

```bash
silvios-dev.eastus2.cloudapp.azure.com
```

## 3. Instale o cert-manager

Instale o cert-manager executando [este](install.sh) script.

## 4. Execute o Deployment do httpbin e demais objetos Istio

Abra um terminal na pasta ```helm``` e execute um Helm Template aplicando no Cluster:

```bash
helm template . | kubectl apply -f -
```
