openstack_public_network_id=$(openstack network show public_network -c id -f value)

openstack_internal_network_id=$(openstack network show devel_net -c id -f value)

openstack_internal_subnet_id=$(openstack subnet show devel_subnet -c id -f value)

openstack_project_id=devel

openstack port create \
--disable-port-security \
--fixed-ip subnet=$openstack_internal_subnet_id,ip-address=10.0.0.31 \
--network $openstack_internal_network_id \
port-master-1

openstack port create \
--disable-port-security \
--fixed-ip subnet=$openstack_internal_subnet_id,ip-address=10.0.0.41 \
--network $openstack_internal_network_id \
port-node-1

openstack port create \
--disable-port-security \
--fixed-ip subnet=$openstack_internal_subnet_id,ip-address=10.0.0.42 \
--network $openstack_internal_network_id \
port-node-2

openstack floating ip create \
--project $openstack_project_id \
--port port-master-1 \
--floating-ip-address 192.168.1.31 \
$openstack_public_network_id

openstack floating ip create \
--project $openstack_project_id \
--port port-node-1 \
--floating-ip-address 192.168.1.41 \
$openstack_public_network_id

openstack floating ip create \
--project $openstack_project_id \
--port port-node-2 \
--floating-ip-address 192.168.1.42 \
$openstack_public_network_id

for server in master-1 node-1 node-2; do
  openstack server create \
  --image centos7 \
  --flavor m1.large \
  --key-name director \
  --port port-$server \
  $server;
done

cat <<EOF > hosts.ini
[nodes]
master-1 ansible_host=192.168.1.31
node-1   ansible_host=192.168.1.41
node-2   ansible_host=192.168.1.42

[nodes:vars]
ansible_user=centos
ansible_become=yes
EOF

ansible -i hosts.ini all -m ping

sudo yum update -y

sudo curl -fsSL https://get.docker.com | bash

sudo systemctl start docker && \
sudo systemctl enable docker && \
sudo systemctl status docker

sudo vim /etc/yum.repos.d/kubernetes.repo

[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg

sudo setenforce 0 && \
sudo systemctl stop firewalld && \
sudo systemctl disable firewalld && \
sudo systemctl status firewalld

sudo yum install -y kubelet kubeadm kubectl

sudo systemctl enable kubelet

sudo systemctl start kubelet

sudo systemctl status kubelet

sudo vim /etc/sysctl.d/k8s.conf

net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1

sudo sysctl --system

sudo docker info | grep -i cgroup

sudo sed -i "s/cgroup-driver=systemd/cgroup-driver=cgroupfs/g" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

sudo systemctl daemon-reload && \
sudo systemctl restart kubelet && \
sudo systemctl status kubelet

sudo swapoff -a

sudo vim /etc/fstab

# a partir daqui só no master e o join nos nodes

sudo hostnamectl set-hostname master-1.example.com

sudo vim /etc/hosts

10.0.0.31 master-1 master-1.example.com

sudo kubeadm init --apiserver-advertise-address $(hostname -i)

# saída do comando kubeadm init para rodar nos nodes:
  
    sudo kubeadm join 10.0.0.31:6443 --token j6y4jw.108z11ajzaygo6zb --discovery-token-ca-cert-hash sha256:0812a180c5a4e60203e99f6cfa3bb2a3e6b77fb73fa0dec2d017b2816a65d147

mkdir -p $HOME/.kube

sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

kubectl get pods -n kube-system

kubectl run nginx --image nginx --replicas 10

kubectl get pods -o wide
