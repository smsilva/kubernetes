#!/bin/bash
# Create Configuration
# https://crossplane.io/docs/v1.4/getting-started/create-configuration.html

mkdir crossplane-config
cd crossplane-config

curl -OL https://raw.githubusercontent.com/crossplane/crossplane/release-1.4/docs/snippets/package/definition.yaml
curl -OL https://raw.githubusercontent.com/crossplane/crossplane/release-1.4/docs/snippets/package/azure/composition.yaml
curl -OL https://raw.githubusercontent.com/crossplane/crossplane/release-1.4/docs/snippets/package/azure/crossplane.yaml

kubectl crossplane build configuration

CONTAINER_REGISTRY="docker.io/silviosilva"

CROSSPLANE_CONFIGURATION_PACKAGE="${CONTAINER_REGISTRY}/getting-started-with-azure:0.1.1"

kubectl crossplane push configuration ${CROSSPLANE_CONFIGURATION_PACKAGE}

kubectl crossplane install configuration ${CROSSPLANE_CONFIGURATION_PACKAGE}
