# 🚀 Project: WordPress on Kubernetes with CI/CD

> **"From Compose to Kubernetes: Deploy WordPress with Full Production Readiness"**

---

## 📋 Project Overview

In this project, you will take a real-world Docker Compose WordPress application and transform it into a fully production-ready Kubernetes deployment. You will write Kubernetes manifests from scratch, configure persistent storage, set up Ingress with a custom domain, implement an automated database backup strategy using **`mysqldump` + AWS S3**, and wire everything together with a GitHub Actions CI/CD pipeline.

**Source Reference:** Based on the [WordPress + MySQL sample](https://github.com/docker/awesome-compose/tree/master/wordpress-mysql) from Docker's `awesome-compose` repository.

---

## 🎯 Learning Objectives

| # | Skill Area | What You'll Practice |
|---|---|---|
| 1 | Docker | Reading and understanding Docker Compose multi-service applications |
| 2 | Kubernetes | Writing Deployments, Services, Secrets, ConfigMaps, PVCs, Ingress, CronJobs |
| 3 | Storage | Configuring persistent volumes so data survives pod restarts |
| 4 | Networking | Exposing applications via NGINX Ingress with a custom domain |
| 5 | Cloud Backup | Automating `mysqldump` backups uploaded to AWS S3 |
| 6 | CI/CD | Building a GitHub Actions pipeline that lints and deploys manifests |

---

## 🏗️ Architecture Diagram

![alt text](image-1.png)

---

## 🛠️ Prerequisites

Before starting, ensure you have the following:

| Tool | Purpose |
|------|---------|
| `kubectl` | Communicate with your Kubernetes cluster |
| `helm` | Install the NGINX Ingress Controller |
| `minikube` / `kind` / `k3s` | Run a local Kubernetes cluster |
| `git` | Version control |
| GitHub Account | Host repository & run Actions pipelines |
| AWS Account | S3 bucket for database backups |

---

## 📁 Required Project Structure

```
wordpress-k8s-project/
├── .github/
│   └── workflows/
│       └── deploy.yml          # CI/CD pipeline
├── k8s/
│   ├── namespace.yml
│   ├── secrets.yml
│   ├── configmap.yml
│   ├── mysql-pvc.yml
│   ├── mysql-deployment.yml
│   ├── mysql-service.yml
│   ├── wordpress-deployment.yml
│   ├── wordpress-service.yml
│   ├── ingress.yml
│   └── backup/
│       └── backup-cronjob.yml  # S3 backup job
├── docker-compose.yml          # Provided for reference
├── README.md
└── .gitignore
```

---

## 📝 Phase 1 — Kubernetes Manifests

> **Rule:** All resources must be in the `wordpress-app` namespace. Add YAML comments explaining each section.

### `namespace.yml`
- Create namespace `wordpress-app`.

### `secrets.yml`
- Type: `Opaque`, base64-encoded values.
- Keys required:
  - `MYSQL_ROOT_PASSWORD`, `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD`
  - `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` *(for S3 backup uploads)*

> 💡 Use `echo -n 'value' | base64` to encode each value.

### `configmap.yml`
- Non-sensitive configuration:
  - `WORDPRESS_DB_HOST` → name of the MySQL service (e.g. `mysql-service`)
  - `WORDPRESS_DB_NAME` → database name
  - `AWS_S3_BUCKET` → your S3 bucket name
  - `AWS_DEFAULT_REGION` → your AWS region

### `mysql-pvc.yml`
- PVC name: `mysql-pvc`
- Access Mode: `ReadWriteOnce`
- Storage: `5Gi`

### `mysql-deployment.yml`
- Image: `mariadb:10.6.4-focal` | Replicas: `1`
- Args: `--default-authentication-plugin=mysql_native_password`
- Volume mount: `mysql-pvc` → `/var/lib/mysql`
- Env from Secret
- Resource limits: CPU `500m` / RAM `512Mi` | Requests: CPU `250m` / RAM `256Mi`
- **Liveness probe:** `exec: mysqladmin ping -h localhost` (initialDelay: 30s, period: 10s)
- **Readiness probe:** `exec: mysqladmin ping -h localhost` (initialDelay: 5s, period: 10s)
- Labels: `app: mysql`

### `mysql-service.yml`
- Type: `ClusterIP` | Port: `3306` | Selector: `app: mysql`

### `wordpress-deployment.yml`
- Image: `wordpress:latest` | Replicas: `2`
- Container port: `80`
- Env:
  - `WORDPRESS_DB_HOST`, `WORDPRESS_DB_NAME` → from ConfigMap
  - `WORDPRESS_DB_USER`, `WORDPRESS_DB_PASSWORD` → from Secret
- Resource limits: CPU `500m` / RAM `512Mi` | Requests: CPU `250m` / RAM `256Mi`
- Labels: `app: wordpress`

### `wordpress-service.yml`
- Type: `ClusterIP` | Port: `80` | Selector: `app: wordpress`

### `ingress.yml`
- `ingressClassName: nginx`
- Host: `wordpress.yourdomain.com` → routes to `wordpress-service:80`
- *(Bonus)* Add a commented-out TLS section

---

## 💾 Phase 2 — Database Backup to AWS S3

### `k8s/backup/backup-cronjob.yml`

Create a CronJob that runs **daily at 2 AM** using the following shell logic:


**CronJob requirements:**
| Field | Value |
|-------|-------|
| Schedule | `0 2 * * *` |
| Image | `mariadb:10.6.4-focal` (install `awscli` inside the command) |
| Env Source | Same Secret + ConfigMap as above |
| Restart Policy | `OnFailure` |
| `successfulJobsHistoryLimit` | `3` |
| `failedJobsHistoryLimit` | `1` |

---

## ⚙️ Phase 3 — CI/CD Pipeline

### `.github/workflows/deploy.yml`

- **Triggers:** `push` to `main` and `pull_request` to `main`

| Job | Trigger | Steps |
|-----|---------|-------|
| `lint-and-validate` | PR + Push | Checkout → Install `kubeconform` → Validate all `k8s/*.yml` and `k8s/backup/*.yml` |
| `deploy` | Push to `main` only | Checkout → Setup `kubectl` → Decode `KUBECONFIG` secret → Apply manifests in order → Verify with `kubectl get pods,svc,ingress -n wordpress-app` |

> 🔐 Store `KUBECONFIG`, `AWS_ACCESS_KEY_ID`, and `AWS_SECRET_ACCESS_KEY` as **GitHub Repository Secrets**.

**Apply order:**
```bash
kubectl apply -f k8s/namespace.yml
kubectl apply -f k8s/secrets.yml
kubectl apply -f k8s/configmap.yml
kubectl apply -f k8s/mysql-pvc.yml
kubectl apply -f k8s/mysql-deployment.yml
kubectl apply -f k8s/mysql-service.yml
kubectl apply -f k8s/wordpress-deployment.yml
kubectl apply -f k8s/wordpress-service.yml
kubectl apply -f k8s/ingress.yml
kubectl apply -f k8s/backup/backup-cronjob.yml
```

---

## 🏃 Quick Start

```bash
# 1. Apply all manifests locally
kubectl apply -f k8s/namespace.yml
kubectl apply -f k8s/

# 2. Install NGINX Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx && helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace

# 3. Add to /etc/hosts (get IP from: kubectl get svc -n ingress-nginx)
echo "<INGRESS_IP> wordpress.yourdomain.com" | sudo tee -a /etc/hosts

# 4. Open in browser
open http://wordpress.yourdomain.com
```

---

## 🛡️ Backup & Restore

**Trigger a manual backup:**
```bash
kubectl create job --from=cronjob/mysql-backup test-backup -n wordpress-app
kubectl logs -l job-name=test-backup -n wordpress-app
```

**List backups in S3:**
```bash
aws s3 ls s3://<your-bucket>/backups/
```

**Restore a backup:**
```bash
# Download
aws s3 cp s3://<your-bucket>/backups/wordpress-db-YYYY-MM-DD-HHMMSS.sql ./restore.sql
# Restore
kubectl exec -i deploy/mysql-deployment -n wordpress-app -- \
  mysql -u wordpress -pwordpress wordpress < ./restore.sql
```

---


## 🏆 Bonus Challenges

| Challenge | Description |
|-----------|-------------|
| S3 Lifecycle Rule | Auto-delete backups older than 30 days via S3 policy |
| HTTPS/TLS | Use `cert-manager` + Let's Encrypt on the Ingress |
| WordPress PVC | Add PVC for uploads at `/var/www/html/wp-content/uploads` |
| HPA | HorizontalPodAutoscaler: min 2, max 5, CPU target 70% |
| Network Policy | Restrict MySQL access to WordPress pods only |
| Helm Chart | Package everything as a Helm chart with `values.yaml` |

