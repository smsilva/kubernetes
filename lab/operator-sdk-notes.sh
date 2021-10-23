apiVersion: platform.acme.com/v1
kind: MongoSecretTest
metadata:
  name: orders-test-1
spec:
  cluster: barley-wine
  dabatase: mongodb
  user: orders-admin

# Slack Channel
https://global-bees.slack.com/archives/C02JT8H4YHJ

#Install the Operator SDK CLI
#https://sdk.operatorframework.io/docs/installation/

export ARCH=$(case $(uname -m) in x86_64) echo -n amd64 ;; aarch64) echo -n arm64 ;; *) echo -n $(uname -m) ;; esac)
export OS=$(uname | awk '{print tolower($0)}')

export OPERATOR_SDK_DL_URL=https://github.com/operator-framework/operator-sdk/releases/download/v1.13.1
curl -LO ${OPERATOR_SDK_DL_URL}/operator-sdk_${OS}_${ARCH}

gpg --keyserver keyserver.ubuntu.com --recv-keys 052996E2A20B5C7E

curl -LO ${OPERATOR_SDK_DL_URL}/checksums.txt
curl -LO ${OPERATOR_SDK_DL_URL}/checksums.txt.asc
gpg -u "Operator SDK (release) <cncf-operator-sdk@cncf.io>" --verify checksums.txt.asc

grep operator-sdk_${OS}_${ARCH} checksums.txt | sha256sum -c -

chmod +x operator-sdk_${OS}_${ARCH}
mkdir -p ${HOME}/bin
sudo mv operator-sdk_${OS}_${ARCH} ${HOME}/bin/operator-sdk

operator-sdk version

operator-sdk init \
  --domain acme.com \
  --repo=github.com/secrets-operator

operator-sdk create api \
  --group=secrets \
  --version=v1alpha1 \
  --kind=SecretsOperator \
  --resource \
  --controller

make generate
make manifests
