#!/bin/bash

# 로컬 개발 환경 배포 스크립트

set -e

echo "🚀 Deploying microservices to local Kubernetes..."

# Minikube 시작
echo "📦 Starting Minikube..."
minikube start --memory=4096 --cpus=2

# Docker 이미지 빌드
echo "🔨 Building Docker images..."

# User Service
echo "Building user-service..."
cd user-service
./gradlew build -x test
docker build -t user-service:latest .
cd ..

# Sleep Service
echo "Building sleep-service..."
cd sleep-service
./gradlew build -x test
docker build -t sleep-service:latest .
cd ..

# Minikube에 이미지 로드
echo "📦 Loading images to Minikube..."
minikube image load user-service:latest
minikube image load sleep-service:latest

# 네임스페이스 생성
echo "🏗️ Creating namespace..."
kubectl apply -f k8s/infrastructure/namespace.yaml

# 시크릿 생성 (로컬용)
echo "🔐 Creating secrets..."
kubectl create secret generic mysql-secret \
  --from-literal=username=root \
  --from-literal=password=password \
  -n microservices || true

kubectl create secret generic jwt-secret \
  --from-literal=secret=your-jwt-secret-key-here \
  -n microservices || true

kubectl create secret generic smtp-secret \
  --from-literal=username=your-email@example.com \
  --from-literal=password=your-email-password \
  -n microservices || true

# 인프라 배포
echo "🏗️ Deploying infrastructure..."
kubectl apply -f k8s/infrastructure/mysql.yaml -n microservices
kubectl apply -f k8s/infrastructure/redis.yaml -n microservices
kubectl apply -f k8s/infrastructure/mongodb.yaml -n microservices
kubectl apply -f k8s/infrastructure/kafka.yaml -n microservices

# 인프라 대기
echo "⏳ Waiting for infrastructure to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/mysql -n microservices
kubectl wait --for=condition=available --timeout=300s deployment/redis -n microservices
kubectl wait --for=condition=available --timeout=300s deployment/mongodb -n microservices
kubectl wait --for=condition=available --timeout=300s deployment/kafka -n microservices

# 서비스 배포
echo "🚀 Deploying services..."
kubectl apply -f k8s/user-service/ -n microservices
kubectl apply -f k8s/sleep-service/ -n microservices

# 서비스 대기
echo "⏳ Waiting for services to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/user-service -n microservices
kubectl wait --for=condition=available --timeout=300s deployment/sleep-service -n microservices

# 서비스 URL 출력
echo "✅ Deployment complete!"
echo ""
echo "Service URLs:"
echo "User Service: http://$(minikube ip):$(kubectl get service user-service -n microservices -o jsonpath='{.spec.ports[0].nodePort}')"
echo "Sleep Service: http://$(minikube ip):$(kubectl get service sleep-service -n microservices -o jsonpath='{.spec.ports[0].nodePort}')"
echo ""
echo "To access services:"
echo "minikube service user-service -n microservices"
echo "minikube service sleep-service -n microservices"
