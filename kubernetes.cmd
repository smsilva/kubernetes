openstack_public_network_id=$(openstack network show public_network -c id -f value)

openstack_internal_network_id=$(openstack network show devel_net -c id -f value)

openstack_internal_subnet_id=$(openstack subnet show devel_subnet -c id -f value)

openstack_project_id=devel

openstack port create \
--disable-port-security \
--network $openstack_internal_network_id \
--fixed-ip subnet=$openstack_internal_subnet_id,ip-address=10.0.0.31 \
port-master-01

for node in {1..2}; do
  openstack port create \
  --disable-port-security \
  --network $openstack_internal_network_id \
  --fixed-ip subnet=$openstack_internal_subnet_id,ip-address=10.0.0.4$node \
  port-node-0$node;
done

openstack floating ip create \
--project $openstack_project_id \
--port port-master-01 \
--floating-ip-address 192.168.1.31 \
$openstack_public_network_id;

for node in {1..2}; do
  openstack floating ip create \
  --project $openstack_project_id \
  --port port-node-0$node \
  --floating-ip-address 192.168.1.4$node \
  $openstack_public_network_id;
done

for node in {1..2}; do
  openstack server create \
  --image centos7 \
  --flavor m1.large \
  --key-name director \
  --nic port-id=port-node-0$node \
  node-0$node;
done

openstack server create \
--image centos7 \
--flavor m1.large \
--key-name director \
--nic port-id=port-master-01 \
master-01

########################################################################################################

openstack security group create \
--description "Security Group for Kubernetes Node" \
--project $openstack_project_id \
sg-node

openstack security group rule create \
--description "ICMP Ingress Traffic" \
--ingress \
--remote-ip 0.0.0.0/0 \
--protocol icmp \
--project $openstack_project_id \
sg-node

openstack security group rule create \
--description "ICMP Ingress Traffic" \
--ingress \
--remote-ip 0.0.0.0/0 \
--dst-port 22 \
--protocol tcp \
--project $openstack_project_id \
sg-node

openstack floating ip create \
--project $openstack_project_id \
--floating-ip-address 192.168.1.31 \
$openstack_public_network_id;

for sequence in {1..2}; do
  openstack floating ip create \
  --project $openstack_project_id \
  --floating-ip-address 192.168.1.4$sequence \
  $openstack_public_network_id;
done

for node in {1..2}; do
  openstack server create \
  --image centos7 \
  --flavor m1.large \
  --key-name director \
  --nic net-id=$openstack_internal_network_id,v4-fixed-ip=10.0.0.4$node \
  --security-group sg-node \
  node-$node;
done

openstack server create \
--image centos7 \
--flavor m1.large \
--key-name director \
--nic net-id=$openstack_internal_network_id,v4-fixed-ip=10.0.0.31 \
--security-group sg-node \
master-1
  
openstack server add floating ip master-1 192.168.1.31

for node in {1..2}; do
  openstack server add floating ip node-$node 192.168.1.4$node;
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

ansible -i hosts.ini master-1 -m command -a "hostnamectl set-hostname master-1.example.com"
ansible -i hosts.ini node-1 -m command -a "hostnamectl set-hostname node-1.example.com"
ansible -i hosts.ini node-2 -m command -a "hostnamectl set-hostname node-2.example.com"

ansible -i hosts.ini master-1 -m command -a "hostnamectl"

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

sudo systemctl enable kubelet && \
sudo systemctl start kubelet && \
sudo systemctl status kubelet

sudo vim /etc/sysctl.d/k8s.conf

net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1

sudo sysctl --system && \
sudo docker info | grep -i cgroup

sudo sed -i "s/cgroup-driver=systemd/cgroup-driver=cgroupfs/g" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

sudo systemctl daemon-reload && \
sudo systemctl restart kubelet && \
sudo systemctl status kubelet

sudo swapoff -a

sudo vim /etc/fstab

# a partir daqui só no master e o join nos nodes

sudo hostnamectl set-hostname master-1.example.com

ip=$(ip -4 a | grep inet | grep eth0 | awk '{ print $2 }' | awk -F "/" '{ print $1 }') && \
hostname=$(hostname | awk -F "." '{ print $1 }') && \
fqdn=$(hostname) && \
line=$(echo $ip $hostname $fqdn) && \
echo $line

sudo vim /etc/hosts

10.0.0.31 master-1 master-1.example.com

  - lineinfile:
      path: /etc/hosts
      regexp: '^127\.0\.0\.1'
      line: '127.0.0.1 localhost'
      owner: root
      group: root
      mode: 0644

sudo kubeadm init --apiserver-advertise-address $(hostname -i)

# saída do comando kubeadm init para rodar nos nodes:
  
  kubeadm join 10.0.0.31:6443 --token 4d5jp6.pqw7dfvvtusni0sj --discovery-token-ca-cert-hash sha256:6592cf1582e34d8248ba71766c25cf0c9797c436fca3a4455c429a479d9e7800

mkdir -p $HOME/.kube

sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

kubectl get pods -n kube-system

kubectl run nginx --image nginx --replicas 4

kubectl get pods -o wide
