# Kubernetes Install using Multipass

# Install Multipass

```
sudo snap install multipass
```

# Create `controlplane` node

```
multipass launch \
  --name controlplane \
  --cpus 2 \
  --memory 3G \
  --disk 80G
```

# Create `worker` node

```
multipass launch \
  --name node1 \
  --cpus 2 \
  --memory 3G \
  --disk 80G
```

# Retrieve the IP addresses of the nodes

```
controlplane_ip=$(multipass info controlplane | grep IPv4 | awk '{print $2}')
node1_ip=$(multipass info node1 | grep IPv4 | awk '{print $2}')

cat <<EOC
sudo sed -i '/controlplane/d' /etc/hosts
sudo sed -i '/node1/d' /etc/hosts
cat <<EOF | sudo tee -a /etc/hosts
${controlplane_ip} controlplane
${node1_ip} node1
EOF
EOC
```

# Update the `/etc/hosts` file on each node

```
ping -c 3 controlplane
ping -c 3 node1
```

# System update

```
sudo apt update
sudo apt upgrade -y
```

# Installing kubeadm

## Swap configuration 

As mentioned [here](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#swap-configuration).

```bash
# Disable SWAP
sudo swapoff -a

# Update /etc/fstab remove lines with 'swap'
sudo sed '/swap/d' /etc/fstab -i

# Enable Configuration
sudo sysctl --system

# Remove OS Prober
sudo apt-get \
  --purge remove os-prober \
  --yes
```

## Kernel Settings

As mentioned [here](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#install-and-configure-prerequisites).

```bash
cat <<EOF | sudo tee /etc/modules-load.d/10-kubernetes.conf
br_netfilter
ip_vs
ip_vs_rr
ip_vs_sh
ip_vs_wrr
nf_conntrack
overlay
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

sudo systemctl restart systemd-modules-load.service
sudo systemctl status systemd-modules-load

# Setup required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/10-kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.ipv6.conf.all.disable_ipv6      = 1
net.ipv6.conf.default.disable_ipv6  = 1
net.ipv6.conf.lo.disable_ipv6       = 1
EOF

sudo sysctl --system
```

## container runtime installation


```bash
### Install packages to allow apt to use a repository over HTTPS
sudo apt-get remove \
  containerd \
  docker \
  docker-compose-plugin \
  docker-engine \
  docker.io \
  runc

sudo apt-get update --quiet

sudo apt-get install --quiet \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg-agent \
  software-properties-common \
  --yes

sudo install -m 0755 -d /etc/apt/keyrings

curl \
  --fail \
  --silent \
  --show-error \
  --location \
  --url "https://download.docker.com/linux/ubuntu/gpg" \
| sudo gpg \
  --dearmor \
  --yes \
  --output "/etc/apt/keyrings/docker.gpg"

sudo chmod a+r "/etc/apt/keyrings/docker.gpg"

architecture=$(dpkg --print-architecture)
  
source /etc/os-release

cat <<EOF | sudo tee /etc/apt/sources.list.d/docker.list
deb [arch=${architecture?} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME?} stable
EOF

## Install containerd
sudo apt-get update --quiet && \
sudo apt-get install --yes --quiet containerd.io

# Configure containerd
sudo mkdir --parents /etc/containerd && \
containerd config default | sudo tee /etc/containerd/config.toml

# Configuring the systemd cgroup driver
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

# Restart containerd
sudo systemctl restart containerd

containerd --version | awk '{ print $2, $3 }'
```

## Install net-tools

```bash
sudo apt-get install --yes --quiet net-tools
```
