#!/bin/bash

. aks-cluster/create.sh wasp-na-sbx-a

kind/create-cluster.sh

external-secrets/install.sh

argocd/install.sh
