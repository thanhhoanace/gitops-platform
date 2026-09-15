export DOCKER_BUILDKIT=1

# 2. Build multi-arch (AMD64 + ARM64)
docker-buildx create --use
docker-buildx build --platform linux/amd64,linux/arm64 \
  -t nhs-registry.pvcb.vn/nhs/cicd-template/k8s-tools-helm:latest \
  --load .

docker push nhs-registry.pvcb.vn/nhs/cicd-template/k8s-tools-helm:latest

docker-buildx imagetools inspect nhs-registry.pvcb.vn/nhs/cicd-template/k8s-tools-helm:latest