#!/bin/bash

# 무중단 배포 스크립트

set -e

SERVICE_NAME=$1
NEW_IMAGE_TAG=$2
NAMESPACE=${3:-microservices}

if [ -z "$SERVICE_NAME" ] || [ -z "$NEW_IMAGE_TAG" ]; then
    echo "Usage: $0 <service-name> <new-image-tag> [namespace]"
    echo "Example: $0 user-service v1.2.3 microservices"
    exit 1
fi

echo "🚀 Starting zero-downtime deployment for $SERVICE_NAME with image tag $NEW_IMAGE_TAG"

# 1. 현재 배포 상태 확인
echo "📊 Checking current deployment status..."
kubectl get deployment $SERVICE_NAME -n $NAMESPACE

# 2. 새 이미지로 배포 업데이트
echo "🔄 Updating deployment with new image..."
kubectl set image deployment/$SERVICE_NAME $SERVICE_NAME=$SERVICE_NAME:$NEW_IMAGE_TAG -n $NAMESPACE

# 3. 배포 상태 모니터링
echo "⏳ Monitoring deployment progress..."
kubectl rollout status deployment/$SERVICE_NAME -n $NAMESPACE --timeout=300s

# 4. 헬스 체크
echo "🏥 Performing health check..."
kubectl wait --for=condition=available --timeout=60s deployment/$SERVICE_NAME -n $NAMESPACE

# 5. 배포 완료 확인
echo "✅ Deployment completed successfully!"
kubectl get pods -l app=$SERVICE_NAME -n $NAMESPACE

# 6. 롤백 준비 (필요시)
echo "💾 Rollback command (if needed):"
echo "kubectl rollout undo deployment/$SERVICE_NAME -n $NAMESPACE"
