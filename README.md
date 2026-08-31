# KinD Cluster on AWS EC2

A local, multi-node Kubernetes cluster built with [KinD](https://kind.sigs.k8s.io/) (Kubernetes in Docker), running on a Docker host provisioned on AWS EC2. Useful for development, testing, and learning Kubernetes without needing a full managed cluster (EKS/GKE/AKS).

## Architecture

```
AWS EC2 (Ubuntu, "docker-host")
  └── Docker Engine
        └── KinD cluster
              ├── control-plane node (container)
              └── worker node (container)
```

## What's in this repo

| File                | Purpose                                                                 |
|---------------------|--------------------------------------------------------------------------|
| `install-docker.sh` | EC2 user-data script — installs Docker automatically on first boot      |
| `config.yaml`        | KinD cluster config — defines a control-plane + worker node, with a NodePort mapping (30000) |

## Prerequisites

- AWS CLI configured with credentials
- An existing EC2 key pair
- An existing VPC with at least one subnet and an attached internet gateway

## Setup

### 1. Launch the EC2 instance

```bash
aws ec2 run-instances \
  --image-id ami-020cba7c55df1f615 \
  --count 1 \
  --instance-type t2.medium \
  --key-name <your-key-pair> \
  --subnet-id <your-subnet-id> \
  --security-group-ids <your-security-group-id> \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":30}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=docker-host}]' \
  --user-data file://install-docker.sh
```

> **Note:** `--subnet-id` and `--security-group-ids` are required if your target VPC doesn't have a default subnet available (see Troubleshooting below).

### 2. SSH into the instance

```bash
ssh ubuntu@<instance-public-ip>
```

### 3. Install kubectl and KinD

```bash
sudo usermod -aG docker $USER
newgrp docker

sudo apt update
sudo apt install -y golang

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

### 4. Create the cluster

```bash
kind create cluster --config=config.yaml
kubectl cluster-info --context kind-kind
```

### 5. Verify

```bash
kubectl get nodes
kubectl get pods
kubectl get services
```

Expected: two `Ready` nodes (`kind-control-plane`, `kind-worker`).

## Troubleshooting

### `MissingInput: No subnets found for the default VPC`

**Cause:** the target VPC had no subnets available, so EC2 couldn't auto-select one for instance placement.

**Fix:**
1. List existing subnets in the VPC:
   ```bash
   aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>"
   ```
2. If none exist, create one:
   ```bash
   aws ec2 create-subnet --vpc-id <vpc-id> --cidr-block 172.31.0.0/20 --availability-zone <az>
   ```
3. Enable auto-assign public IP on the new subnet:
   ```bash
   aws ec2 modify-subnet-attribute --subnet-id <subnet-id> --map-public-ip-on-launch
   ```
4. Confirm an internet gateway is attached to the VPC and the route table has a `0.0.0.0/0` route pointing to it.
5. Re-run `run-instances` with `--subnet-id` and `--security-group-ids` (security groups must be referenced by ID, not name, once a subnet is specified).

## Cleanup

```bash
kind delete cluster
```

Then stop or terminate the EC2 instance to avoid ongoing charges:

```bash
aws ec2 stop-instances --instance-ids <instance-id>
```
