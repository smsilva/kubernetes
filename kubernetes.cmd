# exclui e cria os objetos no OpenStack
ansible-playbook -i ./openstack/hosts.ini all.yml

# a partir daqui só no master e o join nos nodes

ip=$(ip -4 a | grep inet | grep eth0 | awk '{ print $2 }' | awk -F "/" '{ print $1 }') && \
hostname=$(hostname | awk -F "." '{ print $1 }') && \
fqdn=$(hostname) && \
line=$(echo $ip $hostname $fqdn) && \
sudo su -c "echo $line >> /etc/hosts" && \
cat /etc/hosts && \
sudo kubeadm init --apiserver-advertise-address $(hostname -i)

# saída do comando kubeadm init para rodar nos nodes:
  
  sudo kubeadm join 10.0.0.29:6443 --token 2zp0c5.vnd6pic76txkk9hu --discovery-token-ca-cert-hash sha256:fee4b2f226b526a90120fe8b728ecdde47597501f6f89ffb28e47a91eaf368ad
  
  ansible -b -i ./openstack/inventory.ini nodes -m command -a "kubeadm join 10.0.0.29:6443 --token 2zp0c5.vnd6pic76txkk9hu --discovery-token-ca-cert-hash sha256:fee4b2f226b526a90120fe8b728ecdde47597501f6f89ffb28e47a91eaf368ad"

# continuando no Master:
  
mkdir -p $HOME/.kube && \
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && \
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

watch -n 5 kubectl get pods -n kube-system

# deploy do Nginx para teste

kubectl run nginx --image nginx --replicas 4

watch -n 5 kubectl get pods -o wide
