#!/bin/bash

REPO_URL="https://github.com/thanhhoanace/gitops-platform.git"
GIT_USERNAME="thanhhoan2605"

# Sử dụng 'read -s' để không hiển thị ký tự khi gõ
read -s -p "Nhập Personal Access Token (PAT) của bạn: " PAT

argocd repocreds add "$REPO_ROOT_URL" \
  --username "$GIT_USERNAME" \
  --password "$PAT" \
  --type git