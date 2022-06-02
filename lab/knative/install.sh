#!/bin/bash

KNATIVE_VERSION="1.5.0"
USER_BINARIES_FOLDER="${HOME}/bin"
KN_BINARY="${USER_BINARIES_FOLDER?}/kn"
KN_QUICKSTART_PLUGIN_BINARY="${USER_BINARIES_FOLDER?}/kn-quickstart"

mkdir -p "${USER_BINARIES_FOLDER?}"

if which kn > /dev/null; then
  kn version --output yaml
else
  wget --output-document ${KN_BINARY} https://github.com/knative/client/releases/download/knative-v${KNATIVE_VERSION?}/kn-linux-amd64
  chmod +x ${KN_BINARY}
  kn version --output yaml
fi

if which kn-quickstart > /dev/null; then
  kn-quickstart version
else
  wget --output-document ${KN_QUICKSTART_PLUGIN_BINARY} https://github.com/knative-sandbox/kn-plugin-quickstart/releases/download/knative-v${KNATIVE_VERSION?}/kn-quickstart-linux-amd64
  chmod +x ${KN_QUICKSTART_PLUGIN_BINARY}
  kn-quickstart version
fi

kn quickstart kind

kn service create hello \
  --image gcr.io/knative-samples/helloworld-go \
  --port 8080 \
  --env TARGET=World

while true; do
  curl -s http://hello.default.127.0.0.1.sslip.io
  sleep 3
done
