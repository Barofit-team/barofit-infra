# BaroFit EKS Network Design — Proposed

## AWS environment

- Account: 373514675861
- Region: ap-northeast-2
- Existing VPC: vpc-04a571ac6f367a80a
- Existing VPC CIDR: 172.31.0.0/16
- Existing subnet count: 4 across 4 AZs
- Existing NAT gateways: 0
- Existing EKS clusters: 0

## Proposed architecture

Use a dedicated development VPC for BaroFit EKS,
subject to team approval.

Network:
- Two availability zones
- Two public subnets for internet-facing ALB
- Two private subnets for EKS worker nodes
- Internet gateway for public subnet routing
- NAT gateway or approved VPC endpoints for outbound access
- Private node networking and restricted security groups

Kubernetes:
- One development EKS cluster
- Managed node group in private subnets
- Amazon ECR for container images
- Argo CD for GitOps synchronization
- Helm charts stored in barofit-infra

## GitOps responsibility

Service repositories:
- Build and test applications
- Publish container images to ECR

barofit-infra:
- Own Terraform infrastructure definitions
- Own Helm manifests and deployment values
- Own Argo CD Application configuration
- Track approved image versions

## Deployment blockers

- Infra PR #11 requires review approval
- Service ECR workflow PRs require review and merge
- GitHub OIDC IAM resources are not yet applied
- EKS cluster does not yet exist
- Argo CD has not been installed
- Helm charts require production-like AWS configuration review
- Application database and secret management need decisions

## Required decisions

1. Approve dedicated VPC versus reuse of default VPC
2. Approve EKS cluster name and node instance types
3. Approve network CIDR allocation with no overlaps
4. Approve NAT gateway count, cost, and alternatives
5. Approve EKS cluster and load balancer budget
6. Approve cluster endpoint access restrictions
7. Approve infrastructure Terraform state ownership
8. Approve deployment environment and runtime secrets

## Safety

This document is design-only.

Do not execute terraform apply, eksctl create cluster,
or kubectl apply until the team approves the infrastructure.

Existing bootstrap Terraform state must remain unchanged.