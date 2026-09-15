## Hướng dẫn bootstrapping một cụm Kubernetes mới

Tài liệu ngắn này hướng dẫn các bước cần thiết để bootstrap (khởi tạo) một cụm mới bằng repo GitOps trong project này. Nội dung bao gồm: kiểm tra quyền truy cập, cài Argo CD (nếu cần), validate kustomize và apply bootstrap overlay — cùng cách chỉ apply 1 file bootstrap-strategic nếu muốn.

### Yêu cầu trước
- Có quyền truy cập tới cluster (kubeconfig, context chính xác).
- `kubectl` (>= v1.18) trong PATH.
- `kustomize` trong PATH hoặc dùng `kubectl kustomize`.
- `helm` nếu bạn cài Argo CD bằng Helm.
- Script trợ giúp (tuỳ chọn): `0-bootstrap/overlays/oracle2/bootstrap.sh` (bash) và `bootstrap.ps1` (PowerShell) — có sẵn trong repo.

Trước khi làm, kiểm tra kết nối tới cluster:

```bash
kubectl version --short
kubectl cluster-info
kubectl get nodes
```

### 1) (Tuỳ chọn) Cài Argo CD bằng Helm
Nếu bạn muốn Argo CD quản lý các Application, cài Argo CD vào namespace `argocd`:

```bash
kubectl create namespace argocd
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argo-cd argo/argo-cd \
  --namespace argocd \
  --set server.service.type=ClusterIP
```

Kiểm tra:

```bash
kubectl -n argocd get pods
helm -n argocd status argo-cd
```

Lấy mật khẩu admin mặc định của Argo CD (nếu cần để login UI):

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o go-template='{{printf "%s" (index .data "password" | base64decode)}}'
```

Mở UI (port-forward):

```bash
kubectl -n argocd port-forward svc/argo-cd-argocd-server 8080:80
# rồi mở http://localhost:8080
```

### 2) Validate kustomize cho overlay bootstrap
Bạn cần validate trước khi apply. Giả sử path overlay của bạn là `0-bootstrap/overlays/oracle2`:

```bash
kustomize build "0-bootstrap/overlays/oracle2"
```

Nếu lệnh trên chạy thành công (output là YAML hợp lệ), bạn có thể apply toàn bộ overlay.

### 3) Apply toàn bộ overlay (cách thông dụng)
Dùng `kubectl apply -k` để apply toàn bộ overlay:

```bash
kubectl apply -k "0-bootstrap/overlays/oracle2"
```

Lưu ý: không dùng `kustomize apply` — dùng `kubectl apply -k` để thực tế áp resource lên cluster.

### 4) Chỉ apply một file bootstrap (ví dụ: `patches/bootstrap-cluster-strategic.yaml`)
Nếu bạn chỉ muốn apply riêng file bootstrap-strategic (ví dụ để tạo Application bootstrap) thay vì toàn bộ overlay, có 2 cách chính:

- Cách an toàn, không cần công cụ bên ngoài: tạo tạm `kustomization.yaml` chỉ chứa file đó và chạy `kubectl apply -k` trên thư mục tạm. Repo đã kèm 2 script tiện lợi để làm điều này tự động:

  - Bash (Linux/macOS/WSL/Git Bash):

    ```bash
    ./0-bootstrap/overlays/oracle2/bootstrap.sh --file patches/bootstrap-cluster-strategic.yaml
    ```

  - PowerShell (Windows):

    ```powershell
    .\0-bootstrap\overlays\oracle2\bootstrap.ps1 -File patches/bootstrap-cluster-strategic.yaml
    ```

  Hai script này sẽ: validate `kustomize build` trên overlay, tạo thư mục tạm, copy file bạn chỉ định vào đó, sinh `kustomization.yaml` minimal và chạy `kubectl apply -k` trên thư mục tạm — rồi tự xoá thư mục tạm.

- Cách khác (cần công cụ): dùng `kustomize build` + `yq` để lọc document theo `.metadata.name`/`.kind`. Cách này yêu cầu `yq` và phức tạp hơn nên chỉ dùng khi cần lọc theo trường metadata.

### 5) Kiểm tra sau khi apply
Kiểm tra các resource đã tạo:

```bash
# Kiểm tra Application bootstrap (nếu dùng Argo CD)
kubectl -n argocd get applications.argoproj.io -o wide

# Kiểm tra pods / deployments liên quan
kubectl -n argocd get pods
kubectl get all -n <namespace-các-ứng-dụng>  # thay namespace nếu cần
```

### 6) Rollback / Remove
Xoá toàn bộ overlay nếu cần rollback:

```bash
kubectl delete -k "0-bootstrap/overlays/oracle2"
```

Hoặc chỉ xoá Application bootstrap cụ thể:

```bash
kubectl -n argocd delete application bootstrap-cluster
```

### Ghi chú và mẹo
- Nếu `kustomize build` thất bại, đọc lỗi kỹ — thường do đường dẫn `resources`/`patches` sai hoặc 1 file YAML hỏng/thiếu trường required.
- Kiểm tra `spec.source.repoURL` và `targetRevision` trong file `patches/bootstrap-cluster-strategic.yaml` để đảm bảo ArgoCD sẽ trỏ đúng repository/branch.
- Sử dụng script `bootstrap.sh` / `bootstrap.ps1` để giảm rủi ro khi chỉ apply 1 file.
- Nếu bạn dùng CI/CD để bootstrap, đảm bảo kubeconfig được inject an toàn và chạy các bước tương tự (validate trước, apply sau).

---

Nếu bạn muốn, tôi có thể: kiểm tra lại `patches/bootstrap-cluster-strategic.yaml` trong overlay của bạn, hoặc thêm ví dụ cụ thể cho overlay `oracle2` (ví dụ: lệnh cụ thể chạy từ repo root). Bạn muốn tôi thêm bước đó không?