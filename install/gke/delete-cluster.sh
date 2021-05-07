#!/bin/bash

. ./load-config.sh

gcloud container clusters delete ${GKE_CLUSTER_NAME?}
