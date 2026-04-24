# 🚀 Mid-Level DevOps Project: WordPress on Kubernetes with CI/CD

**"From Compose to Kubernetes: Deploy WordPress with Full Production Readiness"**

Welcome to the mid-level DevOps student project! In this assignment, you will convert a standard Docker Compose application into a fully resilient Kubernetes deployment, complete with a CI/CD pipeline and automated database backups to AWS S3.

## 📋 Project Overview

In this project, you will take a real-world Docker Compose WordPress application and transform it into a fully production-ready Kubernetes deployment. You will build Kubernetes manifests from scratch, configure persistent storage, set up Ingress with a custom domain, implement an automated database backup strategy with S3 cloud storage, and wire everything together with a GitHub Actions CI/CD pipeline.

**Source Reference:** This project is based on the [WordPress + MySQL sample](https://github.com/docker/awesome-compose/tree/master/wordpress-mysql) from Docker's `awesome-compose` repository.

## 🎯 Learning Objectives

By completing this project, you will:

1. **Docker**: Understand multi-container applications defined in Docker Compose.
2. **Kubernetes Manifests**: Write Deployments, Services, ConfigMaps, Secrets, PersistentVolumeClaims, Ingress, and CronJobs from scratch.
3. **Ingress & Networking**: Expose WordPress via an Ingress controller with a custom domain.
4. **Persistent Storage**: Configure volumes for the MySQL database to survive pod restarts.
5. **Cloud Backup Strategy**: Implement an automated MySQL backup solution using `mysqldump` and AWS S3.
6. **GitHub Actions CI/CD**: Build a pipeline that lints, validates, and deploys your Kubernetes manifests.

## 🏗️ Architecture Diagram

```mermaid
graph LR
    Dev[👨‍💻 Developer] -->|Git Push| GitHub[🐙 GitHub Repo]
    GitHub -->|Triggers| Actions[⚙️ GitHub Actions CI/CD]
    Actions -->|kubectl apply| K8s[☸️ Kubernetes Cluster]
    
    subgraph K8s [Kubernetes Cluster <br/>(Namespace: wordpress-app)]
        Ingress[🌐 NGINX Ingress] --> WP_SVC[⚙️ Service: wordpress-service]
        WP_SVC --> WP_Pods[📦 WordPress Pods x2]
        
        WP_Pods --> DB_SVC[⚙️ Service: mysql-service]
        DB_SVC --> DB_Pod[🗄️ MySQL Pod]
        DB_Pod --> PVC1[(💾 PVC: mysql-pvc)]
        
        CronJob[⏰ Backup CronJob] -.->|mysqldump| DB_SVC
        CronJob -->|aws s3 cp| S3[(☁️ AWS S3 Bucket)]
    end
```

## 🛠️ Prerequisites

Before you start, ensure you have the following installed and configured:
- **Kubernetes Cluster**: `minikube`, `kind`, `k3s`, or a cloud provider (EKS/GKE/AKS).
- **CLI Tools**: `kubectl`, `helm`, `git`.
- **Ingress Controller**: An NGINX Ingress Controller running in your cluster.
- **GitHub Account**: To host your repository and run GitHub Actions.
- **AWS Account**: An S3 bucket and an IAM user with `s3:PutObject` permissions for backups.

---

## 📝 Project Requirements

### Phase 1: Repository Structure

```
wordpress-k8s-project/
├── .github/
│   └── workflows/
│       └── deploy.yml
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
│       └── backup-cronjob.yml
├── docker-compose.yml
├── README.md
└── .gitignore
```

### Phase 2: Kubernetes Manifests (Core)

Add YAML comments throughout every manifest explaining each section.

- `namespace.yml`: Creates the `wordpress-app` namespace.
- `secrets.yml`: A base64-encoded `Opaque` secret containing:
  - `MYSQL_ROOT_PASSWORD`, `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD`
  - `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` *(for S3 backups)*
- `configmap.yml`:
  - `WORDPRESS_DB_HOST` → points to `mysql-service`
  - `WORDPRESS_DB_NAME` → database name
  - `AWS_S3_BUCKET` → your S3 bucket name (e.g. `my-wp-backups`)
  - `AWS_DEFAULT_REGION` → your AWS region (e.g. `eu-west-1`)
- `mysql-pvc.yml`: PVC named `mysql-pvc` (5Gi, `ReadWriteOnce`).
- `mysql-deployment.yml`:
  - Image: `mariadb:10.6.4-focal` (1 replica).
  - Command args: `--default-authentication-plugin=mysql_native_password`.
  - Mount `mysql-pvc` at `/var/lib/mysql`.
  - Env from Secret. Resource limits + Liveness/Readiness probes via `mysqladmin ping`.
  - Labels: `app: mysql`.
- `mysql-service.yml`: `ClusterIP` on port `3306`.
- `wordpress-deployment.yml`: `wordpress:latest` (2 replicas), env from ConfigMap + Secret, resource limits.
- `wordpress-service.yml`: `ClusterIP` on port `80`.
- `ingress.yml`: NGINX Ingress routing `wordpress.yourdomain.com` → WordPress Service.

### Phase 3: Database Backup to AWS S3

#### `k8s/backup/backup-cronjob.yml`

Create a Kubernetes CronJob that:

- **Schedule:** Daily at 2 AM (`0 2 * * *`)
- **Image:** `amazon/aws-cli` (it includes both `mysqldump` dependencies and the AWS CLI)
  > 💡 Hint: You may need a custom image or an `initContainer` that runs `mysqldump` first and saves locally, then a second container uploads using the AWS CLI.
  >
  > An alternative simpler approach is to use the `mariadb:10.6.4-focal` image and install the `awscli` inside the job command using `apt-get`.

- **Command logic (shell script to implement):**
  ```bash
  # Step 1: Create a timestamped dump file
  FILE="wordpress-db-$(date +%F-%H%M%S).sql"
  
  # Step 2: Run mysqldump and save locally
  mysqldump --single-transaction \
    -h mysql-service \
    -u $MYSQL_USER \
    -p$MYSQL_PASSWORD \
    $MYSQL_DATABASE > /tmp/$FILE
  
  # Step 3: Upload the dump to S3
  aws s3 cp /tmp/$FILE s3://$AWS_S3_BUCKET/backups/$FILE
  
  # Step 4: (Optional) Remove the local temp file
  rm /tmp/$FILE
  
  echo "Backup $FILE uploaded to s3://$AWS_S3_BUCKET/backups/"
  ```

- **Environment variables** from the same Secret (`MYSQL_USER`, `MYSQL_PASSWORD`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`) and ConfigMap (`MYSQL_DATABASE`, `AWS_S3_BUCKET`, `AWS_DEFAULT_REGION`).
- **restartPolicy:** `OnFailure`
- **successfulJobsHistoryLimit:** `3`, **failedJobsHistoryLimit:** `1`

> 📌 Note: The local PVC (`backup-pvc.yml`) is **no longer needed** since backups go directly to S3. You may remove it from your structure.

### Phase 4: CI/CD Pipeline (`.github/workflows/deploy.yml`)

- Triggered on `push` and `pull_request` to `main`.
- **Job 1: `lint-and-validate`** — install `kubeconform` and validate all manifests.
- **Job 2: `deploy`** — runs only on push to `main`, applies manifests in order, verifies with `kubectl get pods,svc,ingress -n wordpress-app`.
- Store `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` as additional **GitHub Secrets** alongside `KUBECONFIG`.

---

## 🏃 Quick Start

```bash
# Apply manifests in order
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

**Install NGINX Ingress:**
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx && helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace
```

## 🛡️ Backup & Restore Guide

**Trigger a manual backup:**
```bash
kubectl create job --from=cronjob/mysql-backup test-backup -n wordpress-app
kubectl logs -l job-name=test-backup -n wordpress-app
```

**List backups in S3:**
```bash
aws s3 ls s3://<your-bucket>/backups/
```

**Restore from a backup:**
```bash
# Download the backup
aws s3 cp s3://<your-bucket>/backups/wordpress-db-YYYY-MM-DD-HHMMSS.sql ./restore.sql

# Pipe it into the running MySQL pod
kubectl exec -i deploy/mysql-deployment -n wordpress-app -- \
  mysql -u wordpress -pwordpress wordpress < ./restore.sql
```

## 🚑 Troubleshooting

- **PVC stuck in `Pending`**: Run `kubectl get sc` — ensure a default StorageClass exists.
- **Pod in `CrashLoopBackOff`**: Check `kubectl logs <pod> -n wordpress-app` and `kubectl describe pod <pod> -n wordpress-app`.
- **Ingress not routing**: Run `kubectl get ingress -n wordpress-app`. Ensure `/etc/hosts` maps the domain locally.
- **MySQL connection refused**: Check `kubectl get endpoints mysql-service -n wordpress-app`.
- **S3 upload failing**: Verify `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are correctly set in Secrets and the IAM user has `s3:PutObject` on the target bucket.

---

## 🏆 Bonus Challenges (Optional)

| Challenge | Description |
|-----------|-------------|
| **S3 Lifecycle Rule** | Configure an S3 Lifecycle Policy to automatically delete backups older than 30 days. |
| **HTTPS/TLS** | Use `cert-manager` + Let's Encrypt to add HTTPS to your Ingress. |
| **WordPress PVC** | Add a PVC for WordPress uploads at `/var/www/html/wp-content/uploads`. |
| **HPA** | HorizontalPodAutoscaler for WordPress (min: 2, max: 5, CPU target: 70%). |
| **Network Policy** | Restrict MySQL access to only WordPress pods. |
| **Helm Chart** | Package the whole deployment as a Helm chart with a `values.yaml`. |

---

## 📊 Grading Rubric

| Criteria | Points | Description |
| :--- | :---: | :--- |
| **Namespace & Configs** | 10 | Proper Namespaces, Secrets (incl. AWS keys), ConfigMaps. No hardcoded credentials. |
| **Storage (PVCs)** | 10 | Correct PVC definition and volume mount for MySQL. |
| **Deployments & Services** | 20 | Correct images, replicas, ClusterIP services, resource limits, and health probes. |
| **Ingress Routing** | 10 | Functional Ingress routing to WordPress. |
| **S3 Backup CronJob** | 20 | Working `mysqldump` → S3 upload schedule with correct env wiring. |
| **CI/CD Pipeline** | 20 | GitHub Actions with lint + deploy stages and correct triggers. |
| **Documentation & Quality** | 10 | YAML comments, consistent labels, clean commit history. |
| **Total** | **100** | |

---

## ⏳ Submission

- **Deadline:** [INSERT DATE]
- **Submission:** A public GitHub repository link.
- At least one successful GitHub Actions run must be visible.
- Provide a screenshot of an S3 backup file listed in your bucket.

---

## 📚 Helpful Resources

- [Kubernetes – Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Kubernetes – Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Kubernetes – CronJobs](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)
- [Kubernetes – Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [AWS CLI s3 cp Reference](https://docs.aws.amazon.com/cli/latest/reference/s3/cp.html)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [Docker awesome-compose WordPress sample](https://github.com/docker/awesome-compose/tree/master/wordpress-mysql)

---

*Good luck! 🎯 Remember: The goal is not just to make it work, but to make it production-ready.*
