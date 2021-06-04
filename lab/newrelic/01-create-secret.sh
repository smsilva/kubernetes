export NEWRELIC_API_KEY_BASE64="$(echo -n ${NEWRELIC_API_KEY?} | base64)"

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
  name: newrelic-bundle
  labels:
    app: newrelic-infrastructure
type: Opaque
data:
  license: ${NEWRELIC_API_KEY_BASE64?}
EOF
