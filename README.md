# gitops-platform

Argo CD **app-of-apps** repository that bootstraps and operates my Oracle Cloud Kubernetes clusters (RKE2). One `kubectl apply` of the bootstrap overlay installs Argo CD, then Argo CD installs and keeps in sync everything else: cert-manager with Let's Encrypt DNS-01 through Cloudflare, ingress-nginx, Longhorn storage and Rancher.

Two clusters (`oracle`, `oracle2`) share the same base and differ only by overlay. A `local` overlay exists for testing the bootstrap on kind/k3d.

## Layout

```
0-bootstrap/                 # what Argo CD needs to take over the cluster
├── base/
│   ├── bootstrap-cluster.yaml     # root Application (app-of-apps)
│   ├── app-projects/              # AppProjects: platform, applications
│   ├── applications/              # Applications: argocd, cert-manager, cert-manager-config, longhorn, rancher
│   ├── app-generator/             # ApplicationSet: git directory generator over 1-cluster-scoped/*
│   ├── repositories/              # repo credentials Secret (placeholder, see Secrets)
│   └── argocd/                    # argocd-cm, argocd-rbac-cm, helper script
└── overlays/{local,oracle,oracle2}/   # strategic-merge patches per cluster
1-cluster-scoped/            # cluster add-ons, one folder per namespace
├── argocd/overlays/<cluster>/         # ingress + certificate for the Argo CD UI
├── cert-manager/{base,overlays}/      # ClusterIssuers (staging + prod), Cloudflare token Secret
├── ingress-nginx/base/                # controller config + Cloudflare origin cert
├── longhorn-system/overlays/<cluster>/ # ingress, basic-auth, node disk patch
└── cattle-system/overlays/<cluster>/  # Rancher ingress, cluster-agent
Dockerfile, dockerbuild-amd64.sh        # k8s-tools image (kubectl, kustomize, helm) used by CI
bootstrap.md                            # step-by-step bootstrap notes (Vietnamese)
```

Sync order is controlled with `argocd.argoproj.io/sync-wave`: repositories (0) → AppProjects (5) → Applications (10). Applications use `automated` sync with `prune` and `selfHeal`, so a manual `kubectl edit` is reverted on the next reconcile.

## Bootstrap a cluster

```bash
# 1. Argo CD itself (once)
kubectl create namespace argocd
helm repo add argo https://argoproj.github.io/argo-helm
helm upgrade --install argo-cd argo/argo-cd -n argocd --set server.service.type=ClusterIP

# 2. Validate, then hand the cluster to Argo CD
kubectl kustomize --enable-helm 0-bootstrap/overlays/oracle2
kubectl apply -k 0-bootstrap/overlays/oracle2

# 3. Watch it converge
kubectl -n argocd get applications -w
```

Full notes, including how to apply only the root Application, are in [bootstrap.md](bootstrap.md).

## Secrets

Every `Secret` manifest in this repo carries the value `REPLACE_ME`. Real values are applied out of band before bootstrap and are **not** committed:

| Secret | Namespace | Used by |
|---|---|---|
| `platform-gitops` (repo credentials) | `argocd` | Argo CD to read this repository |
| `cloudflare-api-token` | `cert-manager` | DNS-01 solver for Let's Encrypt |
| `cloudflare-origin-cert` | `ingress-nginx` | default TLS certificate |
| `longhorn-basic-auth` | `longhorn-system` | htpasswd for the Longhorn UI |

Next step on the roadmap is to replace the out-of-band apply with Sealed Secrets so the encrypted form can live in git.

## CI

`.github/workflows/kustomize-build.yml` (and the original `.gitlab-ci.yml`) run `kustomize build --enable-helm` on every kustomization so a broken overlay fails before Argo CD sees it.

## Things I learned the hard way

- Argo CD rejects Helm repos that are not listed in the AppProject `sourceRepos`; the error only shows up in the Application status, not at apply time.
- Longhorn on Oracle free-tier VMs needs a node disk patch, otherwise every PVC stays `Pending` because the root disk is too small.
- Rancher behind ingress-nginx needs `cacerts` removed from the chart values when cert-manager already issues the certificate, or the UI loops on TLS errors.
