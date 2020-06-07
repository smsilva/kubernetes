#!/bin/bash

# Pulling Images
sudo crictl pull k8s.gcr.io/coredns:1.6.7
sudo crictl pull k8s.gcr.io/etcd:3.4.3-0
sudo crictl pull k8s.gcr.io/kube-apiserver:v1.18.3
sudo crictl pull k8s.gcr.io/kube-controller-manager:v1.18.3
sudo crictl pull k8s.gcr.io/kube-proxy:v1.18.3
sudo crictl pull k8s.gcr.io/kube-scheduler:v1.18.3
sudo crictl pull k8s.gcr.io/pause:3.2
sudo crictl pull nginx:1.19
sudo crictl pull nginx:1.18
sudo crictl pull yauritux/busybox-curl
sudo crictl pull weaveworks/weave-npc:2.6.4
sudo crictl pull weaveworks/weave-kube:2.6.4
sudo crictl pull quay.io/jcmoraisjr/haproxy-ingress:latest

# Pull for All Platforms
# https://github.com/containerd/containerd/issues/3340
sudo crictl images | awk '{ print "sudo ctr image pull --all-platforms " $1 ":" $2 }' | sed '1d' | sh

# Export images to tar files
sudo crictl images | awk '{ print $1 ":" $2 }' | sed '1d' | while read line; do
FILE_NAME=$(echo $(sed 's/\//_/g; s/:/#/' <<< ${line}).tar)
echo "${line} --> ${FILE_NAME}"
sudo ctr image export ${FILE_NAME} $line
done

# Remove
sudo ctr images ls | sed '1d' | awk '{ print $1 }' | while read line; do sudo ctr images remove ${line}; done
sudo crictl images | sed '1d' | awk '{ print $3 }' | while read line; do sudo crictl rmi ${line}; done
sudo ctr images ls
sudo crictl images
