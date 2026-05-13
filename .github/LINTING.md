# Kubernetes Manifest Linting

This repository uses automated GitHub Actions workflows to validate and lint Kubernetes manifests before they're merged.

## Linting Tools

### 1. **Kustomize Build Validation**

- **Purpose**: Ensures all kustomization files can be built successfully
- **When it runs**: On every pull request and push to main
- **What it checks**: Validates kustomize build process completes without errors

### 2. **kubeval**

- **Purpose**: Validates Kubernetes manifests against OpenAPI schemas
- **When it runs**: On every pull request and push to main
- **What it checks**:
  - Manifest structure and required fields
  - API version compatibility
  - Custom resource definitions (CRDs)

### 3. **kube-linter**

- **Purpose**: Security scanning and best practices enforcement
- **When it runs**: On every pull request and push to main
- **What it checks**:
  - Security policies (privileged containers, root user, etc.)
  - Best practices (resource limits, health checks, etc.)
  - Kubernetes standards compliance
- **Configuration**: Customizable via `.kube-linter.yaml`

### 4. **yamllint**

- **Purpose**: YAML syntax and style validation
- **When it runs**: On every pull request and push to main
- **What it checks**:
  - YAML syntax errors
  - Indentation consistency
  - Line length and formatting

## Customizing Linting Rules

### Excluding kube-linter Checks

Edit `.kube-linter.yaml` to exclude specific checks:

```yaml
excludedChecks:
  - "privileged-ports"
  - "run-as-non-root"
```

See [kube-linter documentation](https://docs.kubelinter.io/) for all available checks.

### Ignoring Files from yamllint

Create a `.yamllint` file in the repository root to customize YAML linting:

```yaml
extends: default

ignore: |
  .git
  node_modules

rules:
  line-length:
    max: 120
  indentation:
    spaces: 2
```

## Running Linting Locally

### Validate kustomize builds:

```bash
for kustomization in $(find applications -name "kustomization.yaml" -type f | sort); do
  dir=$(dirname "$kustomization")
  echo "Building: $dir"
  kustomize build "$dir" > /dev/null
done
```

### Install and run kubeval:

```bash
# Install kubeval
wget https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz
tar xf kubeval-linux-amd64.tar.gz && sudo mv kubeval /usr/local/bin/

# Run validation
find applications -name "*.yaml" -type f ! -name "kustomization.yaml" | xargs kubeval
```

### Install and run kube-linter:

```bash
# Install kube-linter
curl -L https://github.com/stackrox/kube-linter/releases/latest/download/kube-linter-linux.tar.gz | tar xz
sudo mv kube-linter /usr/local/bin/

# Run checks
kube-linter lint applications/ --config .kube-linter.yaml
```

### Install and run yamllint:

```bash
pip install yamllint
yamllint applications/
```

## Workflow Execution Order

The linting workflow runs jobs in a specific order to fail fast:

1. **yamllint** (runs first) - Validates YAML syntax
2. **kustomize-build**, **kubeval**, **kube-linter** (run in parallel after yamllint succeeds)

This ensures that if YAML files are malformed, the workflow fails immediately without wasting time on Kubernetes-specific validations.

## Workflow Triggers

The linting workflow runs on:

- **Pull requests** to `main` or `master` branches
- **Pushes** to `main` or `master` branches
- **Changes to** files in the `applications/` directory or the workflow itself
