# Personalizer

```bash
PERSONALIZER_RESOURCE_GROUP_NAME="personalizer"
PERSONALIZER_RESOURCE_GROUP_REGION="eastus2"
PERSONALIZER_LEARNING_LOOP_NAME="learning-loop-example"

az group create \
  --name ${PERSONALIZER_RESOURCE_GROUP_NAME?} \
  --location ${PERSONALIZER_RESOURCE_GROUP_REGION?}

az cognitiveservices account create \
  --name ${PERSONALIZER_LEARNING_LOOP_NAME?} \
  --resource-group ${PERSONALIZER_RESOURCE_GROUP_NAME?} \
  --location ${PERSONALIZER_RESOURCE_GROUP_REGION?} \
  --kind Personalizer \
  --sku F0 \
  --yes

az cognitiveservices account keys list \
  --name ${PERSONALIZER_LEARNING_LOOP_NAME?} \
  --resource-group ${PERSONALIZER_RESOURCE_GROUP_NAME?}

pip install azure-cognitiveservices-personalizer

python3 personalizer-quickstart.py

for i in range(0,1000):
    run_personalizer_cycle()
```
