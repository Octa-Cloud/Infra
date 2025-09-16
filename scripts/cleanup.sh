#!/bin/bash

# 환경 정리 스크립트

set -e

echo "🧹 Cleaning up microservices environment..."

# Kubernetes 리소스 삭제
echo "🗑️ Deleting Kubernetes resources..."
kubectl delete namespace microservices --ignore-not-found=true

# Minikube 정리
if command -v minikube &> /dev/null; then
    echo "🗑️ Cleaning up Minikube..."
    minikube delete || true
fi

# Docker 이미지 정리
echo "🗑️ Cleaning up Docker images..."
docker rmi user-service:latest sleep-service:latest || true

# Terraform 상태 정리 (로컬)
if [ -d "terraform/environments/production" ]; then
    echo "🗑️ Cleaning up Terraform state..."
    cd terraform/environments/production
    terraform destroy -auto-approve || true
    cd ../../..
fi

echo "✅ Cleanup complete!"
