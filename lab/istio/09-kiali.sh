# Kiali Operator
bash <(curl -L https://raw.githubusercontent.com/kiali/kiali-operator/master/deploy/deploy-kiali-operator.sh)

KIALI_OPERATOR_POD=$(
  kubectl -n kiali-operator \
    get pods \
      -l app=kiali-operator \
      -o jsonpath='{.items[0].metadata.name}') && \
  kubectl -n kiali-operator wait --for condition=Ready pod "${KIALI_OPERATOR_POD}" && \
  kubectl -n kiali-operator logs -f "${KIALI_OPERATOR_POD}" | tee "${KIALI_OPERATOR_POD}".log

# Kiali Secret
CLIENT_SECRET='' && \
kubectl \
  --namespace "istio-system" \
  create secret generic "kiali" \
  --from-literal="oidc-secret=$CLIENT_SECRET"

# Kiali Role Binding
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: kiali-view-smsilva-openid-binding
  namespace: istio-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kiali-viewer
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: smsilva@gmail.com
EOF

# OpenID Configuration
https://login.microsoftonline.com/45242aaf-b0d7-4105-b030-293dce770300/v2.0/.well-known/openid-configuration

kubectl apply -f - <<EOF
apiVersion: kiali.io/v1alpha1
kind: Kiali
metadata:
  name: kiali
  namespace: istio-system
spec:
  auth:
    strategy: openid
    openid:
      authentication_timeout: 300
      authorization_endpoint: "https://login.microsoftonline.com/45242aaf-b0d7-4105-b030-293dce770300/oauth2/v2.0/authorize"
      client_id: "a80694e7-1656-4446-ad00-e566d722add1"
      insecure_skip_verify_tls: true
      issuer_uri: "https://login.microsoftonline.com/45242aaf-b0d7-4105-b030-293dce770300/v2.0"
      scopes: ["openid", "profile", "email"]
      username_claim: email
  deployment:
    accessible_namespaces:
    - '**'
    namespace: istio-system
    view_only_mode: true
    verbose_mode: "5"
  version: default
EOF

KIALI_POD=$(
  kubectl -n istio-system \
    get pods \
      -l app=kiali \
      -o jsonpath='{.items[0].metadata.name}') && \
  kubectl -n istio-system wait --for condition=Ready pod ${KIALI_POD} && \
  kubectl logs -f ${KIALI_POD} | tee ${KIALI_POD}.log

# OpenID - Test with curl
CLIENT_ID="a80694e7-1656-4446-ad00-e566d722add1"
CLIENT_SECRET=''
REDIRECT_URI='https%3A%2F%2Foidcdebugger.com%2Fdebug'

CODE=""

curl \
  --location \
  --silent \
  --request POST "https://login.microsoftonline.com/45242aaf-b0d7-4105-b030-293dce770300/oauth2/v2.0/token" \
  --header "Content-Type: application/x-www-form-urlencoded" \
  --data "grant_type=authorization_code&code=${CODE}&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&redirect_uri=${REDIRECT_URI}&session_state=41374bb5-9440-4ed2-aff9-dedbe8a17678" | jq '.'
