# ============================================================
# Terraform Core Configuration
# ============================================================
# This block declares:
#   - The minimum Terraform CLI version required to run this code
#   - All provider dependencies with pinned version constraints
#   - The remote S3 backend for shared, encrypted state storage
#
# File convention: keep this block in versions.tf (or backend.tf)
# so it is immediately findable and not buried in resource files.
# ============================================================

terraform {

  # ── CLI Version Constraint ─────────────────────────────────────────────
  # Enforces a minimum Terraform version across all engineers and CI runners.
  # ">= 1.5.7" allows any newer GA release; tighten to "~> 1.5.7" (patch-only)
  # if you want to prevent accidental upgrades to 1.6.x until tested.
  required_version = ">= 1.5.7"

  # ── Provider Dependencies ──────────────────────────────────────────────
  # All providers must be declared here with explicit version constraints.
  # Never omit version constraints in production — an unpinned provider
  # can introduce breaking changes silently on the next `terraform init`.
  required_providers {

    aws = {
      source = "hashicorp/aws"

      # "~> 6.20" allows 6.20.x and above within the 6.x minor series,
      # but blocks a jump to 7.x which may contain breaking changes.
      # Review AWS provider changelogs before bumping the minor version.
      # Changelog: https://github.com/hashicorp/terraform-provider-aws/releases
      version = "~> 6.20"
    }

    random = {
      source = "hashicorp/random"

      # Used for generating unique suffixes on resource names (e.g. S3 buckets,
      # IAM roles) to avoid naming collisions across environments.
      # "~> 3.7" pins to the 3.x major series; safe to bump patch versions freely.
      version = "~> 3.7"
    }
  }

  # ── Remote State Backend (S3) ──────────────────────────────────────────
  # Stores terraform.tfstate remotely so all team members and CI pipelines
  # share a single source of truth for infrastructure state.
  #
  # Prerequisites (must exist before `terraform init`):
  #   - S3 bucket with versioning enabled (for state history & rollback)
  #   - S3 bucket with object lock or MFA-delete (recommended for prod)
  #   - DynamoDB table for state locking (add `dynamodb_table` arg below)
  #   - KMS key or SSE-S3 for encryption at rest
  #
  # ⚠ WARNING: Backend config cannot use variables or locals — all values
  #   must be hardcoded here or passed via `-backend-config` flags at init time.
  # ============================================================
  backend "s3" {

    # S3 bucket that holds the state file.
    # Naming convention: <org>-<account-id>-<region>-terraform-remote-state
    # Ensure this bucket is in a separate "ops" account, not the target account,
    # to avoid circular dependency during account bootstrapping.
    bucket = "terraform-082569479120-ap-south-1-terraform-remote-state"

    # Path (key) within the bucket for this environment's state file.
    # Convention: <environment>/terraform.tfstate
    # Use a distinct key per env (dev/staging/prod) to prevent state collisions.
    key = "prod/terraform.tfstate"

    # Region where the S3 bucket itself resides.
    # Must match the bucket's actual region; does not have to match the
    # region where resources are deployed.
    region = "ap-south-1"

    # Enables server-side encryption (SSE-S3 AES-256) for the state file at rest.
    # The state file can contain sensitive values (passwords, keys) in plaintext,
    # so encryption is non-negotiable in production.
    # For stronger guarantees, add: kms_key_id = "arn:aws:kms:..." (SSE-KMS)
    encrypt = true

    # ── RECOMMENDED: add these args for full production hardening ──────────
    # State locking prevents concurrent applies from corrupting state.
    # dynamodb_table = "terraform-state-lock"   # DynamoDB table name (LockID pk)

    # Enforces TLS for all S3 API calls to the backend.
    # force_path_style = false                  # Keep false (default) for AWS
  }
}