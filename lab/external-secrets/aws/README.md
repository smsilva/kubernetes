# AWS

## Install

```bash
helm repo add external-secrets https://charts.external-secrets.io

helm repo update

helm search repo external-secrets/external-secrets

helm upgrade \
  --install \
  --namespace external-secrets \
  --create-namespace \
  external-secrets external-secrets/external-secrets \
  --wait
```

## Secret

```bash
cat <<EOF | kubectl --namespace external-secrets apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: aws-credentials
type: Opaque
stringData:
  AWS_ACCESS_KEY: ${AWS_ACCESS_KEY?}
  AWS_SECRET_KEY: ${AWS_SECRET_KEY?}
EOF
```

## Cluster Secret Store

```bash
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager

      region: us-east-2

      auth:
        secretRef:
          accessKeyIDSecretRef:
            namespace: external-secrets
            name: aws-credentials
            key: AWS_ACCESS_KEY

          secretAccessKeySecretRef:
            namespace: external-secrets
            name: aws-credentials
            key: AWS_SECRET_KEY
EOF
```

## External Secret

```bash
kubectl create namespace demo

cat <<EOF | kubectl --namespace demo apply -f -
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: docker-hub
spec:
  refreshInterval: 1h

  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore

  target:
    name: docker-hub
    creationPolicy: Owner

  data:
    - secretKey: values
      remoteRef:
        key: docker-hub

    - secretKey: mypassword
      remoteRef:
        key: docker-hub
        property: password
  
  dataFrom:
    - extract:
        key: docker-hub
EOF
```
