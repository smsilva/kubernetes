#!/bin/bash

kind/create-cluster.sh

external-secrets/install.sh

argocd/install.sh
