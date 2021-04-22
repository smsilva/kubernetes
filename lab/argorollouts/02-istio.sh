kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-rollouts/master/docs/getting-started/istio/rollout.yaml
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-rollouts/master/docs/getting-started/istio/services.yaml
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-rollouts/master/docs/getting-started/istio/virtualsvc.yaml
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-rollouts/master/docs/getting-started/istio/gateway.yaml

kubectl argo rollouts get rollout rollouts-demo

kubectl argo rollouts set image rollouts-demo rollouts-demo=argoproj/rollouts-demo:yellow

kubectl argo rollouts get rollout rollouts-demo

kubectl argo rollouts get rollout rollouts-demo --watch

kubectl argo rollouts promote rollouts-demo

kubectl argo rollouts set image rollouts-demo rollouts-demo=argoproj/rollouts-demo:red

kubectl get vs rollouts-demo-vsvc -o yaml | k neat | yq e . -
