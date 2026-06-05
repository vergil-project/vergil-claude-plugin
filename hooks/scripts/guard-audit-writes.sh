#!/usr/bin/env bash
# guard-audit-writes.sh — PreToolUse hook for Write|Edit|NotebookEdit.
#
# Enforces the AUDIT identity's write discipline from the 2.1 workflow
# spec: AUDIT may write only its own artifacts (.vergil/audit-*) and
# scratch space (build/). Everything else in a managed repo is denied —
# including .vergil/pr-template.yml, which is the USER agent's artifact.
#
# SOFT GATE (by design): identity comes from VRG_IDENTITY_MODE, which a
# misbehaving agent can unset. Every in-VM guard is soft; it steers a
# correctly behaving agent. Hard enforcement lives outside the VM
# (per-identity GitHub App credentials, the pinned vergil-audit/approved
# required check, the VM sandbox). Keeping the guard simple is the
# accepted trade-off. See the reconciliation design spec sections 2-3.3.
#
# Fail-closed inside the audit identity (unresolvable path -> deny),
# fail-open outside it. Bash-command writes are out of scope (documented
# gap). Gated on managed-repo detection (#87).
set -euo pipefail

# Identity gate first — this guard constrains only the AUDIT identity.
if [ "${VRG_IDENTITY_MODE:-}" != "audit" ]; then
  exit 0
fi

input=$(cat)
file_path=$(echo "$input" \
  | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
cwd=$(echo "$input" | jq -r '.tool_input.cwd // .cwd // "."')

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# Fail-closed: a write with no checkable target cannot be allowed.
if [ -z "$file_path" ]; then
  deny "AUDIT write-guard: this tool call has no file path to check, so it is denied for the audit identity. AUDIT may write only .vergil/audit-* and build/ inside the worktree. See issue #442."
fi

# Resolve to an absolute candidate path (relative paths resolve against
# the payload cwd; a relative cwd resolves against the hook's PWD).
case "$file_path" in
  /*) candidate="$file_path" ;;
  *) candidate="$cwd/$file_path" ;;
esac
case "$candidate" in
  /*) ;;
  *) candidate="$PWD/$candidate" ;;
esac

# Best-effort symlink resolution for existing files; lexical
# normalization (.. resolution) otherwise. Same python3 idiom as
# block-worktree-bypass-write.
if [ -e "$candidate" ]; then
  resolved=$(python3 -c \
    "import os,sys; print(os.path.realpath(sys.argv[1]))" \
    "$candidate" 2>/dev/null || echo "")
else
  resolved=$(python3 -c \
    "import os,sys; print(os.path.normpath(sys.argv[1]))" \
    "$candidate" 2>/dev/null || echo "")
fi
if [ -z "$resolved" ]; then
  deny "AUDIT write-guard: could not normalize the path '$file_path'; denied for the audit identity (fail-closed). See issue #442."
fi

# Nearest existing ancestor (the target may be a new file in a new dir).
check_dir="$resolved"
while [ -n "$check_dir" ] && [ "$check_dir" != "/" ] && [ ! -d "$check_dir" ]; do
  check_dir="${check_dir%/*}"
done
if [ -z "$check_dir" ]; then
  check_dir="/"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/managed-repo-check.sh"

# Outside managed repos the guard does not apply (standard gating —
# scratch in /tmp etc. is not repo content).
if ! is_managed_repo "$check_dir"; then
  exit 0
fi

# The worktree root is the checkout the target lives in (git resolves
# .worktrees/<name>/ members to their own toplevel).
toplevel=$(git -C "$check_dir" rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -z "$toplevel" ]; then
  deny "AUDIT write-guard: cannot determine the worktree root for '$file_path'; denied for the audit identity (fail-closed). See issue #442."
fi

case "$resolved" in
  "$toplevel"/*)
    rel="${resolved#"$toplevel"/}"
    ;;
  *)
    deny "AUDIT write-guard: '$file_path' resolves outside the worktree root; denied for the audit identity. See issue #442."
    ;;
esac

case "$rel" in
  .vergil/audit-* | build | build/*)
    exit 0
    ;;
esac

deny "AUDIT write-guard: the audit identity may write only .vergil/audit-* (its feedback artifacts) and build/ (scratch space). '$rel' is outside that allowlist — in particular, .vergil/pr-template.yml belongs to the USER agent. This is a soft gate per the 2.1 soft-gate doctrine; the hard gates are the credentials and the merge check. See issue #442."
