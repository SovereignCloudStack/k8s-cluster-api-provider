#!/usr/bin/env bash
KIND_VERSION=0.14.0
sudo wget -O /usr/local/bin/kind https://github.com/kubernetes-sigs/kind/releases/download/v${KIND_VERSION}/kind-linux-amd64
sudo chmod +x /usr/local/bin/kind
kind create cluster

