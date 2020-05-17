# On another Server
sudo sed '/192.168.10/a \      nameservers: \n        addresses: [192.168.10.2]' /etc/netplan/50-vagrant.yaml -i
sudo netplan apply

sudo vim /etc/netplan/50-vagrant.yaml

network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s8:
      addresses:
      - 192.168.10.10/24
      nameservers:
        addresses: [192.168.10.2]

sudo netplan apply

sudo mkdir -p /etc/resolvconf/resolv.conf.d/
echo nameserver 192.168.10.2 | sudo tee -a /etc/resolvconf/resolv.conf.d/head
resolvconf --enable-updates

sudo service resolvconf restart

sudo vi /etc/resolv.conf
search example.com
nameserver 192.168.0.40

dig primary.example.com

dig -x 192.168.10.2

nslookup primary.example.com

sudo apt-get install dnsutils -y

sudo hostnamectl set-hostname loadbalancer.example.com

hostnamectl
