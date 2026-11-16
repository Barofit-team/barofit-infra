# BaroFit Infra-Centric GitOps CD Design

## Architecture

Service repositories (identity, routine, workout, analytics, report)
    |
    | CI: tests and Docker builds
    v
Amazon ECR (AWS account 373514675861, ap-northeast-2)
    |
    | Immutable image versions selected by Git review
    v
barofit-infra Git repository (dev)
    |
    | Helm charts and infra/values-ecr-dev.yaml
    v
Argo CD Application: barofit-dev
    |
    | Manual synchronization after readiness review
    v
Kubernetes cluster / EKS

## Repository responsibilities

- Service repositories own source code, tests, and image publishing.
- barofit-infra owns deployment configuration and image version selection.
- Argo CD reads approved configuration from barofit-infra/dev.
- The infra repository is the desired-state source of truth.

## Existing deployment assets

- infra/umbrella/Chart.yaml
- infra/charts/{identity,routine,workout,analytics,report}
- infra/charts/{gateway,postgres}
- infra/values-ecr-dev.yaml
- terraform/ecr/
- .github/workflows/helm-validate.yml

## Deployment sequence

1. Service CI completes successfully.
2. Approved workflow publishes an image to the team ECR.
3. Confirm the ECR image digest and supported CPU architecture.
4. Open a PR updating the image tag in infra/values-ecr-dev.yaml.
5. Helm validation passes and the PR receives team approval.
6. Merge the configuration PR into infra/dev.
7. Review the Argo CD Application diff.
8. Manually synchronize the approved Application.
9. Confirm pod readiness, service health and smoke tests.
10. Record the deployed image digest and rollback reference.

## Pre-deployment requirements

- Confirm team IAM/OIDC roles and least-privilege ECR permissions.
- Confirm EKS cluster name, access and namespace ownership.
- Confirm Argo CD installation and Git repository credentials.
- Confirm Helm file dependencies resolve in Argo CD.
- Confirm EKS nodes can pull ECR images.
- Confirm supported CPU architecture (amd64 versus arm64).
- Replace local-development database assumptions with approved RDS configuration.
- Review gateway exposure, DNS, TLS and service routing.
- Provision runtime secrets securely outside Git.
- Confirm Kubernetes storage classes and resource limits.

## Safety and rollout policy

- This PR is design-only and does not deploy resources.
- Automatic synchronization is intentionally disabled.
- No IAM credentials or secrets are committed.
- Do not apply the current umbrella chart to production as-is.
- The existing umbrella chart includes a PostgreSQL subchart
  and local gateway assumptions that require environment review.
- Use image digests or immutable tags for deployed releases.
- Perform rollback by reverting the approved image version commit.
- Never run Terraform apply or kubectl apply without team approval.

## Completion criteria

Design complete:
- Application manifest reviewed.
- Existing Helm validation successful.
- GitOps source and responsibilities documented.

Production deployment complete:
- ECR push verified.
- Argo CD Application healthy and synchronized.
- EKS workloads healthy.
- Smoke tests and rollback verified.