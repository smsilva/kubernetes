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
│   ├── kubeadm/      # Bare metal / VM installations
│   └── ...
├── lab/              # Hands-on labs for Kubernetes tools
│   ├── argo/         # ArgoCD and Argo Rollouts
│   ├── istio/        # Service mesh examples
│   ├── crossplane/   # Infrastructure as Code
│   ├── vault/        # HashiCorp Vault on k8s
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

### Script Execution Pattern

Most installation scripts follow a sourcing pattern:
```bash
# AKS example - config file passed as argument
./create-cluster.sh my-config

# Scripts typically source:
# - load-config.sh (loads environment variables)
# - show-config.sh (displays current configuration)
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

## Commit Message Convention

This repository uses Conventional Commits format enforced by a git hook:

```
<type>(<scope>): <description>
```

Types: `bump`, `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`

Examples:
- `feat(lab/argo): add new sync example`
- `fix(install/k3d): correct port mapping`
- `docs(lab/istio): update traffic management docs`

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
- Generated certificates (`*.pem`)
- Cloud-init files and environment configs
- Vagrant/machines directories

## This file evolution

Update this file as needed to provide guidance to Claude when working with this codebase. It should serve as a living document to help maintain consistency and best practices across all contributions.
