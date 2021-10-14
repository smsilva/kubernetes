#!/bin/bash
kubectl delete Bucket                      --all
kubectl delete Composition                 --all
kubectl delete CompositeResourceDefinition --all
kubectl delete ProviderConfig              --all
kubectl delete Configuration               --all
kubectl delete Provider                    --all
