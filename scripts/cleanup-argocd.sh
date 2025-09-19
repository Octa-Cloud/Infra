#!/bin/bash

# ArgoCD 완전 삭제 스크립트
# 이 스크립트는 ArgoCD와 관련된 모든 리소스를 삭제합니다.

set -e

echo "🧹 ArgoCD 완전 삭제를 시작합니다..."

# 1. Helm 릴리스 삭제
echo "📦 Helm 릴리스 삭제 중..."
if helm list -A | grep -q argocd; then
    echo "  - ArgoCD Helm 릴리스 삭제 중..."
    helm uninstall argocd -n argocd --no-hooks 2>/dev/null || true
    echo "  ✅ Helm 릴리스 삭제 완료"
else
    echo "  ℹ️  삭제할 Helm 릴리스가 없습니다"
fi

# 2. ArgoCD 관련 ClusterRole 및 ClusterRoleBinding 삭제 (네임스페이스 삭제 전)
echo "🔐 RBAC 리소스 삭제 중..."
echo "  - ClusterRole 삭제 중..."
kubectl get clusterrole | grep argocd | awk '{print $1}' | xargs -r kubectl delete clusterrole 2>/dev/null || true

echo "  - ClusterRoleBinding 삭제 중..."
kubectl get clusterrolebinding | grep argocd | awk '{print $1}' | xargs -r kubectl delete clusterrolebinding 2>/dev/null || true

echo "  - ServiceAccount 삭제 중..."
kubectl get serviceaccount -n argocd 2>/dev/null | grep argocd | awk '{print $1}' | xargs -r kubectl delete serviceaccount -n argocd 2>/dev/null || true

echo "  ✅ RBAC 리소스 삭제 완료"

 # 3. ArgoCD Application finalizer 제거
echo "🗂️  ArgoCD Application finalizer 제거 중..."
if kubectl get namespace argocd >/dev/null 2>&1; then
    echo "  - Application finalizer 제거 중..."
    kubectl get applications -n argocd -o name 2>/dev/null | xargs -r kubectl patch -n argocd --type merge --patch '{"metadata":{"finalizers":[]}}' 2>/dev/null || true
    
    echo "  - Application 강제 삭제 중..."
    kubectl delete applications --all -n argocd --force --grace-period=0 2>/dev/null || true
fi

# 4. Kubernetes 네임스페이스 삭제
echo "🏗️  Kubernetes 네임스페이스 삭제 중..."
if kubectl get namespace argocd >/dev/null 2>&1; then
    echo "  - 일반 삭제 시도 중..."
    kubectl delete namespace argocd 2>/dev/null || true
    
    # 일반 삭제가 실패한 경우 강제 삭제
    if kubectl get namespace argocd >/dev/null 2>&1; then
        echo "  - 일반 삭제 실패. finalizer 제거 중..."
        kubectl patch namespace argocd -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
        
        echo "  - 강제 삭제 시도 중..."
        kubectl delete namespace argocd --force --grace-period=0 2>/dev/null || true
    fi
    
    echo "  - 네임스페이스 완전 삭제 확인 중..."
    TIMEOUT=60  # 60초 타임아웃
    ELAPSED=0
    while kubectl get namespace argocd >/dev/null 2>&1; do
        if [ $ELAPSED -ge $TIMEOUT ]; then
            echo "  ⚠️  타임아웃: 네임스페이스 삭제에 ${TIMEOUT}초가 걸렸습니다"
            echo "  💡 수동으로 확인하세요: kubectl get namespace argocd"
            break
        fi
        echo "  ⏳ 네임스페이스 삭제 대기 중... (${ELAPSED}/${TIMEOUT}초)"
        sleep 5
        ELAPSED=$((ELAPSED + 5))
    done
    
    if ! kubectl get namespace argocd >/dev/null 2>&1; then
        echo "  ✅ 네임스페이스 삭제 완료 (${ELAPSED}초 소요)"
    fi
else
    echo "  ℹ️  삭제할 네임스페이스가 없습니다"
fi

# 5. 추가 정리 작업
echo "🧹 추가 정리 작업 중..."

# CustomResourceDefinition 정리
echo "  - CustomResourceDefinition 정리 중..."
kubectl get crd | grep argocd | awk '{print $1}' | xargs -r kubectl delete crd 2>/dev/null || true

# MutatingWebhookConfiguration, ValidatingWebhookConfiguration 정리
echo "  - WebhookConfiguration 정리 중..."
kubectl get mutatingwebhookconfiguration | grep argocd | awk '{print $1}' | xargs -r kubectl delete mutatingwebhookconfiguration 2>/dev/null || true
kubectl get validatingwebhookconfiguration | grep argocd | awk '{print $1}' | xargs -r kubectl delete validatingwebhookconfiguration 2>/dev/null || true

# ConfigMap, Secret 정리 (네임스페이스 외부)
echo "  - 글로벌 ConfigMap, Secret 정리 중..."
kubectl get configmap -A | grep argocd | awk '{print $2 " -n " $1}' | xargs -r kubectl delete configmap 2>/dev/null || true
kubectl get secret -A | grep argocd | awk '{print $2 " -n " $1}' | xargs -r kubectl delete secret 2>/dev/null || true

echo "  ✅ 추가 정리 작업 완료"

# 6. ArgoCD 관련 모든 리소스 삭제 (혹시 남아있는 것들)
echo "🗑️  남은 ArgoCD 리소스 정리 중..."
kubectl get all -A | grep argocd | awk '{print $2 " -n " $1}' | xargs -r kubectl delete 2>/dev/null || true

# 7. Docker 컨테이너 및 이미지 삭제
echo "🐳 Docker 리소스 삭제 중..."

# ArgoCD 관련 실행 중인 컨테이너 중지 및 삭제
echo "  - ArgoCD 컨테이너 중지 및 삭제 중..."
docker ps -a | grep argocd | awk '{print $1}' | xargs -r docker stop 2>/dev/null || true
docker ps -a | grep argocd | awk '{print $1}' | xargs -r docker rm 2>/dev/null || true

# ArgoCD 관련 이미지 삭제
echo "  - ArgoCD 이미지 삭제 중..."
docker images | grep argocd | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true

echo "  ✅ Docker 리소스 삭제 완료"

# 7. Helm 캐시 정리
echo "💾 Helm 캐시 정리 중..."
rm -rf ~/.cache/helm 2>/dev/null || true
echo "  ✅ Helm 캐시 정리 완료"

# 8. 최종 확인
echo "🔍 최종 확인 중..."

# Helm 릴리스 확인
if helm list -A | grep -q argocd; then
    echo "  ⚠️  아직 남아있는 Helm 릴리스가 있습니다:"
    helm list -A | grep argocd
else
    echo "  ✅ Helm 릴리스 정리 완료"
fi

# 네임스페이스 확인
if kubectl get namespace argocd >/dev/null 2>&1; then
    echo "  ⚠️  아직 남아있는 네임스페이스가 있습니다"
    kubectl get namespace argocd
else
    echo "  ✅ 네임스페이스 정리 완료"
fi

# Docker 이미지 확인
if docker images | grep -q argocd; then
    echo "  ⚠️  아직 남아있는 Docker 이미지가 있습니다:"
    docker images | grep argocd
else
    echo "  ✅ Docker 이미지 정리 완료"
fi

echo ""
echo "🎉 ArgoCD 완전 삭제가 완료되었습니다!"
echo ""
echo "📋 정리된 항목:"
echo "  - Helm 릴리스"
echo "  - Kubernetes 네임스페이스"
echo "  - ClusterRole 및 ClusterRoleBinding"
echo "  - Docker 컨테이너 및 이미지"
echo "  - Helm 캐시"
echo ""
echo "💡 이제 새로운 ArgoCD를 설치할 수 있습니다:"
echo "   helm install argocd k8s/argocd/helm -n argocd --create-namespace"
