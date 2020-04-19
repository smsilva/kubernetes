kubectl -n kube-system describe pod etcd-master-1

etcd
--listen-client-urls=https://127.0.0.1:2379,https://192.168.5.11:2379
--trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
--cert-file=/etc/kubernetes/pki/etcd/server.crt
--key-file=/etc/kubernetes/pki/etcd/server.key

sudo ETCDCTL_API=3 etcdctl \
  snapshot save "etcd-snapshot-file" \
  --endpoints="https://127.0.0.1:2379,https://192.168.5.11:2379" \
  --cacert="/etc/kubernetes/pki/etcd/ca.crt" \
  --cert="/etc/kubernetes/pki/etcd/server.crt" \
  --key="/etc/kubernetes/pki/etcd/server.key"

sudo ETCDCTL_API=3 etcdctl \
  snapshot status "etcd-snapshot-file" \
  --endpoints="https://127.0.0.1:2379,https://192.168.5.11:2379" \
  --cacert="/etc/kubernetes/pki/etcd/ca.crt" \
  --cert="/etc/kubernetes/pki/etcd/server.crt" \
  --key="/etc/kubernetes/pki/etcd/server.key" \
  -w "table"
