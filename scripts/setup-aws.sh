#!/bin/bash

# AWS CLI 설치 및 설정 스크립트

set -e

echo "🚀 Setting up AWS CLI and EKS tools..."

# AWS CLI 설치 확인
if ! command -v aws &> /dev/null; then
    echo "📦 Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
else
    echo "✅ AWS CLI already installed"
fi

# kubectl 설치 확인
if ! command -v kubectl &> /dev/null; then
    echo "📦 Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
else
    echo "✅ kubectl already installed"
fi

# eksctl 설치 확인
if ! command -v eksctl &> /dev/null; then
    echo "📦 Installing eksctl..."
    curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    sudo mv /tmp/eksctl /usr/local/bin
else
    echo "✅ eksctl already installed"
fi

# Helm 설치 확인
if ! command -v helm &> /dev/null; then
    echo "📦 Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
    echo "✅ Helm already installed"
fi

echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Configure AWS credentials: aws configure"
echo "2. Update kubeconfig: aws eks update-kubeconfig --region ap-northeast-2 --name microservices-cluster"
echo "3. Deploy infrastructure: kubectl apply -f k8s/infrastructure/"
