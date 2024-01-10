#!/bin/bash
grep '^      limits:' /etc/kubernetes/manifests/kube-apiserver.yaml >/dev/null 2>&1 && exit 0
MEM=$(free -m | grep '^Mem:' | awk '{print $2;}')
CPU=$(grep '^processor' /proc/cpuinfo | wc -l)
sed -i "/^ *requests:/i\      limits:\n        memory: $((10+3*$MEM/4))M\n        cpu: $((750*$CPU))m" /etc/kubernetes/manifests/kube-apiserver.yaml
sed -i "/^ *requests:/a\        memory: 512M" /etc/kubernetes/manifests/kube-apiserver.yaml
