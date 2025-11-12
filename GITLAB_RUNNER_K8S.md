# Local GitLab Runner on Kubernetes

This guide sets up a GitLab Runner using the Kubernetes executor on a local cluster (Kind recommended; works with Minikube or k3d).

## 1. Prerequisites
- GitLab.com account (or self-managed GitLab instance).
- Project or Group-level Runner registration token (NOT a Personal Access Token).
- Local Kubernetes cluster:
  - Kind (recommended): lightweight, fast, minimal overhead.
  - Alternatives: Minikube (VM-based), k3d (Docker + k3s).
- `kubectl` installed.
- `helm` v3.

## 2. Create a Local Cluster (Kind example)
```bash
cat <<'EOF' > kind-cluster.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            max-pods: "150"
    extraPortMappings:
      - containerPort: 32000
        hostPort: 32000
        protocol: TCP
EOF
kind create cluster --name gitlab-ci --config kind-cluster.yaml
kubectl cluster-info
```

To delete later: `kind delete cluster --name gitlab-ci`.

## 3. Add Helm Repo & Update
```bash
helm repo add gitlab https://charts.gitlab.io
helm repo update
```

## 4. Prepare Values File
Edit `gitlab-runner-values.yaml` and replace:
```
runnerRegistrationToken: PLACEHOLDER_REGISTRATION_TOKEN
```
with your real token from:
Project (or Group) → Settings → CI/CD → Runners → "New project (or group) runner" → Copy registration token.

## 5. Install the Runner
Create a namespace (optional but cleaner):
```bash
kubectl create namespace gitlab-runner
```
Install chart:
```bash
helm upgrade --install local-gitlab-runner gitlab/gitlab-runner \
  --namespace gitlab-runner \
  -f gitlab-runner-values.yaml
```
Check pods:
```bash
kubectl get pods -n gitlab-runner
```
You should see a `local-gitlab-runner-*` pod Running.

## 6. Verify Registration
In GitLab project/group Runners UI your runner should appear with tags `local,k8s` and status "online" after a few seconds.

## 7. Test CI
Add to your project's `.gitlab-ci.yml`:
```yaml
stages: [test]

k8s_test_job:
  stage: test
  tags: ["local", "k8s"]
  script:
    - echo "Running on Kubernetes"
    - uname -a
```
Commit & push. The job should create a build pod (watch with `kubectl get pods -A`).

## 8. Caching (PVC)
Configured PVC cache (5Gi). To inspect:
```bash
kubectl get pvc -n gitlab-runner
```
Adjust size or switch to object storage if scaling up.

## 9. Docker-in-Docker (Optional)
If you need to build container images inside jobs:
1. Set `privileged: true` under `runners.kubernetes`.
2. Use a DinD sidecar pattern (simpler: switch to a separate build service). For local dev, prefer `kaniko`/`buildah` rootless images.

Example job using Kaniko:
```yaml
build_image:
  stage: test
  tags: ["local", "k8s"]
  image: gcr.io/kaniko-project/executor:latest
  script:
    - /kaniko/executor --context . --dockerfile Dockerfile --destination registry.example.com/your/app:latest
```

## 10. Scaling & Concurrency
`concurrent: 2` limits simultaneous jobs; raise if hardware allows. Edit value and run:
```bash
helm upgrade local-gitlab-runner gitlab/gitlab-runner -n gitlab-runner -f gitlab-runner-values.yaml
```

## 11. Troubleshooting
- Runner not appearing: Check logs: `kubectl logs -n gitlab-runner deploy/local-gitlab-runner`.
- Token issues: Ensure you used a runner registration token (starts with `GR` or plain alphanumeric) not a Personal Access Token (`glpat-`). PATs cannot register runners.
- Pod stuck Pending: Storage class or resource constraints; inspect events: `kubectl describe pod <pod>`.
- Cache PVC not bound: Ensure default StorageClass exists (`kubectl get storageclass`). For Kind create a hostpath provisioner or switch `cacheType` to `s3` with MinIO.

## 12. Security Notes
- NEVER commit real runner registration tokens or PATs.
- Rotate tokens periodically from GitLab UI (remove runner, re-register with new token).
- Limit tags; avoid broad tags like `docker` unless necessary.
- If using privileged mode, audit allowed images and scripts.

## 13. Cleanup
```bash
helm uninstall local-gitlab-runner -n gitlab-runner
kubectl delete namespace gitlab-runner
kind delete cluster --name gitlab-ci
```

## 14. Next Steps
- Add pod template to inject custom tools.
- Enable Prometheus metrics (set `metrics.enabled: true`).
- Integrate object storage cache (MinIO) for larger dependencies.

---
Happy building! Reach out if you want advanced optimizations.
