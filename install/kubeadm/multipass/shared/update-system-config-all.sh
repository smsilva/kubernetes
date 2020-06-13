multipass exec loadbalancer -- sudo /shared/update-system-config.sh
multipass exec master-1 -- sudo /shared/update-system-config.sh
multipass exec master-2 -- sudo /shared/update-system-config.sh
multipass exec master-3 -- sudo /shared/update-system-config.sh
multipass exec worker-1 -- sudo /shared/update-system-config.sh
multipass exec worker-2 -- sudo /shared/update-system-config.sh
multipass exec worker-3 -- sudo /shared/update-system-config.sh
