#!/usr/bin/env bash
# host-container-tools.sh — the container-only tool list (#96, #993).
#
# Source of truth for which tools run in the dev container. Consumed
# by enforce-host-container-split.sh, which warns when one is invoked
# bare on the host.
#
# This file is meant to be `source`d, not executed directly.

# Container-only: language toolchain validators.
# shellcheck disable=SC2034 # read by enforce-host-container-split.sh, which sources this file
CONTAINER_TOOLS=(
  ruff
  mypy
  ty
  black
  isort
  markdownlint
  yamllint
  actionlint
  shellcheck
  shfmt
)
