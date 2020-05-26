# Configure PATH
echo "PATH=${PATH}:${HOME}/bin/" >> ~/.bashrc && \
  source ~/.bashrc && \
  mkdir "${HOME}/bin"

# Custom Columns Template
CUSTOM_COLUMNS_TEMPLATE_DIRECTORY="${HOME}/.kube/templates"
CUSTOM_COLUMNS_NODES_FILE="custom-columns-nodes.template"

mkdir -p "${CUSTOM_COLUMNS_TEMPLATE_DIRECTORY}"

cat <<EOF > ~/bin/custom-columns-config-templates
#!/bin/bash
TEMPLATE_DIRECTORY="${CUSTOM_COLUMNS_TEMPLATE_DIRECTORY}"
CUSTOM_COLUMNS_NODES_FILE="\${TEMPLATE_DIRECTORY}/${CUSTOM_COLUMNS_NODES_FILE}"
EOF

cat <<EOF > "${CUSTOM_COLUMNS_TEMPLATE_DIRECTORY}/${CUSTOM_COLUMNS_NODES_FILE}"
NAME           STATUS                                               INTERNAL_IP                                        VERSION
.metadata.name .status.conditions[?(@.type=="Ready")].reason .status.addresses[?(@.type=="InternalIP")].address .status.nodeInfo.kubeletVersion
EOF

# Kubectl Plugin
cat <<EOF > ~/bin/kubectl-nodes
#!/bin/bash
. custom-columns-config-templates

NODES=\$*

kubectl get nodes \${NODES} \\
  --output custom-columns-file="\${CUSTOM_COLUMNS_NODES_FILE}" | sed 's/KubeletReady/Ready/;s/NodeStatusUnknown/NotReady/;' | column -t
EOF

chmod +x ~/bin/*
