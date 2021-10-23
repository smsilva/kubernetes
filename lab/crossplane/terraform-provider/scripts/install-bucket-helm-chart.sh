#!/bin/bash
helm template helm/buckets | kubectl apply --dry-run=server -f - && \
echo "OK" && \
helm template helm/buckets | kubectl apply -f - && \
for BUCKET_NAME in $(kubectl get buckets -o jsonpath='{.items[*].metadata.name}' | xargs -n 1); do
  kubectl wait bucket ${BUCKET_NAME} \
    --for=condition=Ready \
    --timeout=120s && \
  echo "${BUCKET_NAME}: Ready"
done

gcloud alpha storage ls --project "${GOOGLE_PROJECT?}"
