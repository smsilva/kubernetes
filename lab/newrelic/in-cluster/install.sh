#!/bin/bash

cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: Namespace
metadata:
  name: newrelic
---
apiVersion: v1
kind: Secret
metadata:
  namespace: newrelic
  name: nri-bundle
  labels:
    app: newrelic-infrastructure
type: Opaque
stringData:
  license: ${NEW_RELIC_LICENSE_KEY?}
  api: ${NEW_RELIC_API_KEY?}
EOF

helm repo add newrelic https://helm-charts.newrelic.com

helm repo update

helm search repo newrelic/nri-bundle

helm install \
  --namespace newrelic \
  --set global.cluster="kind-101" \
  --set global.customSecretName=nri-bundle \
  --set global.customSecretLicenseKey=license \
  --set newrelic-infrastructure.privileged=true \
  --set kube-state-metrics.image.tag=v2.7.0 \
  --set kube-state-metrics.enabled=true \
  --set newrelic-prometheus-agent.enabled=true \
  --set newrelic-prometheus-agent.lowDataMode=true \
  --set newrelic-prometheus-agent.config.kubernetes.integrations_filter.enabled=false \
  newrelic-bundle "${HOME}/git/wasp-gitops/infrastructure/charts/nri-bundle" \
  --wait

helm install \
  --namespace newrelic \
  --set global.cluster="kind-101" \
  --set newrelic-infrastructure.privileged=true \
  --set kube-state-metrics.image.tag=v2.7.0 \
  --set kube-state-metrics.enabled=true \
  --set newrelic-prometheus-agent.enabled=true \
  --set newrelic-prometheus-agent.lowDataMode=true \
  --set newrelic-prometheus-agent.config.kubernetes.integrations_filter.enabled=false \
  newrelic-bundle "${HOME}/git/wasp-gitops/infrastructure/charts/nri-bundle" \
  --wait
