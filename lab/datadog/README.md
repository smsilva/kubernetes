# Datadog

```bash
helm install datadog datadog/datadog \
  --namespace datadog \
  --create-namespace \
  --values datadog-values.yaml \
  --set datadog.site='us5.datadoghq.com' \
  --set datadog.apiKey="${DATADOG_APIKEY}"
```
