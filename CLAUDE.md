# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Portuguese-language educational repository containing Kubernetes installation scripts and hands-on labs. It provides practical examples for provisioning clusters across multiple platforms (AKS, EKS, GKE, kind, k3d, kubeadm) and experimenting with Kubernetes ecosystem tools (ArgoCD, Istio, Vault, cert-manager, Crossplane, etc.).

## Repository Structure

```
├── install/          # Cluster installation scripts by platform
│   ├── aks/          # Azure Kubernetes Service
│   ├── eks/          # Amazon EKS
│   ├── gke/          # Google GKE
│   ├── kind/         # Kind local clusters
│   ├── k3d/          # k3d local clusters
│   ├── k3s/          # K3s lightweight Kubernetes
│   ├── kubeadm/      # Bare metal / VM installations
│   ├── minikube/     # Minikube local clusters
│   ├── microstack/   # OpenStack-based local clusters
│   ├── openstack/    # OpenStack cloud installations
│   └── rancher/      # Rancher Kubernetes management
├── lab/              # Hands-on labs for Kubernetes tools
│   ├── argo/         # ArgoCD and Argo Rollouts (argocd/, argorollouts/)
│   ├── istio/        # Service mesh examples
│   ├── crossplane/   # Infrastructure as Code (AWS, Azure, GCP providers)
│   ├── vault/        # HashiCorp Vault on k8s
│   ├── cert-manager/ # Certificate management
│   ├── external-secrets/ # External Secrets Operator
│   ├── gateway/      # Kubernetes Gateway API
│   ├── kyverno/      # Policy engine
│   ├── prometheus/   # Monitoring and alerting
│   ├── grafana/      # Observability dashboards
│   └── ...           # 40+ other tools
└── videos/           # Supporting materials for video content
```

## Common Commands

### Cluster Creation (Local Development)

**k3d (recommended for quick testing):**
```bash
# Simple cluster
k3d cluster create --api-port 6550 --port "9080:80@loadbalancer"

# Multi-server cluster with Traefik disabled
k3d cluster create \
  --api-port 6550 \
  --port "9080:80@loadbalancer" \
  --port "9443:443@loadbalancer" \
  --servers 3 \
  --k3s-arg '--disable=traefik@server:*' \
  --wait --timeout 360s
```

**Kind:**
```bash
# See lab/istio/kind/ or install/kind/ for cluster configs
kind create cluster --config kind-cluster.yaml --name <cluster-name>
```

### Environment Configuration

Many scripts (especially in `install/aks/` and `install/kubeadm/multipass/`) require environment variables. Look for:
- `environment.conf` files (sourced via `. ./environment.conf`)
- `check-environment-variables.sh` (validates required vars are set)
- Config files with format: `export VAR_NAME=value`

### Helm-based Installations

Labs using Helm typically follow this pattern:
```bash
helm repo add <repo-name> <url>
helm repo update <repo-name>
helm upgrade --install --namespace <ns> --create-namespace <release> <chart> --values <values-file>
```

## Key Patterns

1. **Wait conditions**: Scripts often wait for resources to be ready:
   ```bash
   kubectl wait deployment <name> --for condition=Available --timeout=360s
   kubectl wait pods --selector <label> --for condition=Ready --timeout=360s
   ```

2. **Port forwarding**: Local testing often uses port mappings like `32080:80` for HTTP and `32443:443` for HTTPS

3. **Ingress patterns**: Many labs configure Ingress resources; common hosts used are `app.example.com`, `localhost`, or `*.local`

4. **TLS**: Self-signed certificates are often generated in `install/kind/` labs using files like `4-generate-self-signed-certificate.sh`

## Important File Types

- `**/*.sh` - Shell scripts (the primary automation method)
- `**/values/*.yaml` - Helm values files
- `**/README.md` - Lab instructions (often in Portuguese)
- `**/*.tf` - Terraform configurations for cloud infrastructure
- `**/*-cluster.yaml` - Kind/k3d cluster configuration files

## .gitignore Considerations

The repository excludes:
- `.terraform/` directories and `.tfstate` files
- `credentials.json` and `password.conf` files
- Generated certificates (`*.pem`) — only in `install/kind/`
- Cloud-init files, environment configs, and multipass network/DNS configs
- Vagrant/machines directories (`.vagrant/`)
- Log files (`**/*.log`) and vim swap files (`**/*.swp`)
- Crossplane package files (`**/*.xpkg`)
- Specific cluster configs: `lab/argocd/kind-cluster.yaml`, `lab/kyverno/kind-cluster.yaml`
- Packer JSON files and Terraform output JSON files

## This file evolution

Update this file as needed to provide guidance to Claude when working with this codebase. It should serve as a living document to help maintain consistency and best practices across all contributions.
