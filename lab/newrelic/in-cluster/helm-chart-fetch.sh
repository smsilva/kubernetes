helm repo add newrelic https://helm-charts.newrelic.com

HELM_CHART_NEWEST_VERSION=$(helm search repo newrelic/nri-bundle -l | sed 1d | awk '{ print $2 }' | sort --version-sort | tail --lines 1)

helm fetch newrelic/nri-bundle \
  --version "${HELM_CHART_NEWEST_VERSION?}" \
  --untar
