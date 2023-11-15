#!/bin/bash

watch -n 3 kubectl get deploy,pods,services,sc,pv,pvc -o wide

kubectl apply -f - <<EOF
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/no-provisioner
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-volume-1
  labels:
    type: local
spec:
  storageClassName: local-storage

  capacity:
    storage: 10Gi

  accessModes:
    - ReadWriteOnce

  volumeMode: Filesystem

  persistentVolumeReclaimPolicy: Retain

  hostPath:
    path: /volumes/data
EOF

kubectl apply -f - <<EOF
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: local-claim-1
spec:
  storageClassName: local-storage

  accessModes:
    - ReadWriteOnce
  
  resources:
    requests:
      storage: 10Gi
EOF

kubectl apply -f - <<EOF
---
apiVersion: v1
kind: Pod
metadata:
  name: local-pod-1
spec:
  volumes:
    - name: local-volume-1
      persistentVolumeClaim:
        claimName: local-claim-1

  containers:
    - name: app
      image: ubuntu
      volumeMounts:
        - name: local-volume-1
          mountPath: /usr/share/data
      command:
        - sleep
        - infinity
EOF
