#!/bin/bash
# provider-terraform-examples
# https://github.com/negz/provider-terraform-examples.git

CONTAINER_REGISTRY="docker.io/silviosilva"
CROSSPLANE_PACKAGE_DIRECTORY="kubernetes/lab/crossplane/terraform-provider/package"
CROSSPLANE_CONFIGURATION_PACKAGE="${CONTAINER_REGISTRY}/migrating-from-terraform-example:0.1.3"

# 1. Create a Kind Cluster
# 2. Create GCP Service Account
# 3. Set Permissions to a Bucket
# 4. Get Service Account Key

# 5. Create a Secret into crossplane-system Namespace
BASE64ENCODED_GCP_PROVIDER_CREDS=$(base64 "${GOOGLE_CREDENTIALS_FILE?}" | tr -d "\n") && \
kubectl apply -f - <<EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: gcp-credentials
  namespace: crossplane-system
type: Opaque
data:
  credentials: ${BASE64ENCODED_GCP_PROVIDER_CREDS?}
EOF

# 6. Build Crossplane Configuration
cd "${CROSSPLANE_PACKAGE_DIRECTORY?}" || $(echo "Directory \"${CROSSPLANE_PACKAGE_DIRECTORY?}\" not found."; echo "exit 1")

kubectl crossplane build configuration

kubectl crossplane push configuration ${CROSSPLANE_CONFIGURATION_PACKAGE?}

kubectl crossplane install configuration ${CROSSPLANE_CONFIGURATION_PACKAGE?}

cd ..

kubectl get provider.pkg

kubectl get xrd

kubectl get composition

#kubectl apply -f providerconfig/providerconfig-gcp.yaml
kubectl apply -f providerconfig/providerconfig-terraform.yaml

kubectl apply -f bucket.yaml

kubectl delete -f providerconfig-terraform.yaml

kubectl delete configuration.pkg --all
kubectl delete providers.pkg --all
