# Deploying a Private MinIO Service on Kubernetes

This document provides a complete guide to deploying a MinIO object storage service within a Kubernetes cluster. The service will be exposed for internal cluster access only via a dedicated, private NGINX Ingress controller.

---

## Table of Contents

- [Deploying a Private MinIO Service on Kubernetes](#deploying-a-private-minio-service-on-kubernetes)
  - [Table of Contents](#table-of-contents)
  - [1. Prerequisites](#1-prerequisites)
  - [2. Project Structure](#2-project-structure)
  - [3. Kubernetes Manifests Overview](#3-kubernetes-manifests-overview)
  - [4. Deployment Steps](#4-deployment-steps)
    - [Step 1: Create the Namespace](#step-1-create-the-namespace)
    - [Step 2: Create the MinIO Secret](#step-2-create-the-minio-secret)
    - [Step 3: Deploy the Internal Ingress Controller](#step-3-deploy-the-internal-ingress-controller)
    - [Step 4: Deploy the MinIO Application](#step-4-deploy-the-minio-application)
  - [5. Accessing MinIO From Other Pods](#5-accessing-minio-from-other-pods)

---

## 1. Prerequisites

- A running Kubernetes cluster.
- `kubectl` configured to interact with your cluster.
- [Helm](https://helm.sh/docs/intro/install/) installed on your local machine.
- A `StorageClass` available for PersistentVolumeClaims. If you don't have one, your cluster's default storage provisioner will be used.

## 2. Project Structure

This project contains the following Kubernetes configuration files:

```
/kubernetes
├── deployment.yaml
├── ingress.yaml
├── pvc.yaml
├── secret.yaml
└── service.yml
```

## 3. Kubernetes Manifests Overview

- **`secret.yaml`**: Stores sensitive data for MinIO, specifically the `MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD`. The values are Base64 encoded.
- **`pvc.yaml` (PersistentVolumeClaim)**: Requests 2Gi of persistent storage for MinIO to store its data. This ensures data survives pod restarts.
- **`service.yml`**: Creates a `ClusterIP` service to provide a stable internal endpoint for the MinIO pods. The Ingress controller will route traffic to this service.
- **`deployment.yaml`**: Defines the MinIO application itself. It specifies the container image, mounts the persistent volume, and consumes the credentials from the `secret.yaml` file.
- **`ingress.yaml`**: Configures the routing rules for accessing the MinIO service. It uses the **internal-only** Ingress controller to make MinIO available at `http://minio.internal.local`.

## 4. Deployment Steps

Follow these steps to deploy the MinIO service.

### Step 1: Create the Namespace

All resources for this application will be isolated in the `api-sql-reports` namespace. We define the namespace in its own manifest for good practice.

```bash
kubectl apply -f kubernetes/namespace.yaml
```

### Step 2: Create the MinIO Secret

First, apply the `secret.yaml` manifest to create the secret that holds the MinIO root user and password.

```bash
kubectl apply -f kubernetes/secret.yaml
```

### Step 3: Deploy the Internal Ingress Controller

For services that should only be accessible from within the Kubernetes cluster, we will deploy a private NGINX Ingress controller. This controller uses a `ClusterIP` service, making it unreachable from outside the cluster.

**1. Add the Helm Repository**

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

**2. Install the Internal NGINX Ingress Controller**

This command installs a new controller with a specific Ingress Class (`nginx-internal`) and ensures its service is not exposed externally.

```bash
helm install ingress-nginx-internal ingress-nginx/ingress-nginx \
  --namespace ingress-nginx-internal \
  --create-namespace \
  --set controller.service.type=ClusterIP \
  --set controller.ingressClassResource.name=nginx-internal \
  --set controller.ingressClassResource.controllerValue="k8s.io/ingress-nginx-internal" \
  --set controller.electionID=ingress-nginx-internal-leader \
  --set controller.ingressClassResource.default=false
```

**3. Verify the Installation**

Check that the new pods are running and that the service has a `CLUSTER-IP` but no `EXTERNAL-IP`.

```bash
kubectl get pods -n ingress-nginx-internal
kubectl get svc -n ingress-nginx-internal
```

### Step 4: Deploy the MinIO Application

Now, deploy the remaining MinIO resources. It is safe to apply them all at once.

```bash
# Apply the Secret, PVC, Service, Deployment, and Ingress manifests
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/secret.yaml
kubectl apply -f kubernetes/pvc.yaml
kubectl apply -f kubernetes/service.yml
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/ingress.yaml
```

After a few moments, your MinIO instance will be running and accessible from within the cluster.

## 5. Accessing MinIO From Other Pods

Once deployed, any application (e.g., a FastAPI backend) running inside the cluster can access the MinIO S3 API at the following stable DNS address:

**`http://minio.internal.local`**

There is no need to include a port number. The internal Ingress controller handles routing from standard HTTP port 80 to MinIO's application port 9000.

For the MinIO console, you can access it via port-forwarding for debugging purposes:

```bash
# Get the name of your MinIO pod
kubectl get pods -n api-sql-reports

# Port-forward to the pod (replace <minio-pod-name>)
kubectl port-forward -n api-sql-reports <minio-pod-name> 9001:9001
```

Now, open your browser and navigate to `http://localhost:9001`. You can log in with the credentials defined in the `secret.yaml` file.
