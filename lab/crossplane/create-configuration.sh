#!/bin/bash
# Create Configuration
# https://crossplane.io/docs/v1.4/getting-started/create-configuration.html

mkdir crossplane-config
cd crossplane-config

curl -OL https://raw.githubusercontent.com/crossplane/crossplane/release-1.4/docs/snippets/package/definition.yaml
curl -OL https://raw.githubusercontent.com/crossplane/crossplane/release-1.4/docs/snippets/package/azure/composition.yaml
curl -OL https://raw.githubusercontent.com/crossplane/crossplane/release-1.4/docs/snippets/package/azure/crossplane.yaml

kubectl crossplane build configuration

REG=docker.io/silviosilva
kubectl crossplane push configuration ${REG}/getting-started-with-azure:master

# Installing
kubectl crossplane install configuration ${REG}/getting-started-with-azure:master
