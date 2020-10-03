#!/bin/bash

istioctl proxy-status

NAME                                                   CDS        LDS        EDS        RDS        ISTIOD                     VERSION
demo-57d496c7dd-477px.dev                              SYNCED     SYNCED     SYNCED     SYNCED     istiod-5d884bcc7-4rmh7     1.7.2
demo-57d496c7dd-5bmsb.dev                              SYNCED     SYNCED     SYNCED     SYNCED     istiod-5d884bcc7-4rmh7     1.7.2
demo-57d496c7dd-cdxv7.dev                              SYNCED     SYNCED     SYNCED     SYNCED     istiod-5d884bcc7-4rmh7     1.7.2
istio-ingressgateway-56b8d79bfc-kmdxg.istio-system     SYNCED     SYNCED     SYNCED     SYNCED     istiod-5d884bcc7-4rmh7     1.7.2

# Envoy Configuration Examples
#   https://www.envoyproxy.io/docs/envoy/latest/configuration/overview/examples

# Cluster Discovery Service (CDS)
#   https://www.envoyproxy.io/docs/envoy/latest/configuration/upstream/cluster_manager/cds

# Listener Discovery Service (LDS)
#   https://www.envoyproxy.io/docs/envoy/latest/configuration/listeners/lds

# Endpoint Discovery Service (EDS)
#   https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/upstream/service_discovery#endpoint-discovery-service-eds

# Route Discovery Service (RDS)
#   https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/rds#route-discovery-service-rds

istioctl proxy-config bootstrap demo-57d496c7dd-bwj89.dev | yq r -P -

istioctl profile dump demo

kubectl get cm istio-sidecar-injector -o yaml | kubectl neat | grep policy:

kubectl apply -f - <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: istio-operator
  namespace: istio-system
spec:
  profile: default
  values:
    global:
      proxy:
        autoInject: disabled
EOF
