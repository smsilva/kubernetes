echo loadbalancer
multipass exec loadbalancer -- sudo /shared/setup-resolv.conf.sh 10.45.144.238
echo master-1
multipass exec master-1 -- sudo /shared/setup-resolv.conf.sh 10.45.144.238
echo master-2
multipass exec master-2 -- sudo /shared/setup-resolv.conf.sh 10.45.144.238
echo master-3
multipass exec master-3 -- sudo /shared/setup-resolv.conf.sh 10.45.144.238
echo worker-1
multipass exec worker-1 -- sudo /shared/setup-resolv.conf.sh 10.45.144.238
echo worker-2
multipass exec worker-2 -- sudo /shared/setup-resolv.conf.sh 10.45.144.238
echo worker-3
multipass exec worker-3 -- sudo /shared/setup-resolv.conf.sh 10.45.144.238
