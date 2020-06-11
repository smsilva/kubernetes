
if grep --quiet "There is no local cluster named" <<< $(minikube status); then
  minikube start --driver=docker
fi

kubectl config use-context minikube

kubectl create namespace dev

kubectl config set-context minikube --namespace dev

eval $(minikube docker-env)

docker pull datawire/hello-world
docker pull datawire/telepresence-k8s:0.105-30-g8a9aa4e
docker pull yauritux/busybox-curl

watch -n 2 kubectl get deploy,cm,rs,pods,svc,ep -o wide
