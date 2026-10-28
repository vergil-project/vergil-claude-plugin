#!/usr/bin/env bash
# mask-hook-guard.sh — test helper: a PATH with one tool hidden.
#
# block-raw-git-commit.sh delegates to vrg-hook-guard when it is on
# PATH, so its fallback can only be tested with the guard masked; the
# fail-closed tests (#776) also need a PATH without jq. Dropping every
# PATH directory that holds the tool is not enough: on an agent VM the
# packaged guard lives in /usr/bin, so that would drop bash, jq and git
# too. Instead each such directory is replaced by a scratch mirror of
# symlinks to everything in it except the masked tool.
#
# This file is meant to be `source`d, not executed directly.
#
# Usage:
#   source "$SCRIPT_DIR/lib/mask-hook-guard.sh"
#   mask_hook_guard_path "$scratch_dir"        # sets CLEAN_PATH
#   mask_tool_path "$scratch_dir" jq           # sets MASKED_PATH

# mask_tool_path <scratch-dir> <tool>
#
# Sets MASKED_PATH to $PATH with each directory holding <tool>
# replaced by a mirror under <scratch-dir> that lacks it.
mask_tool_path() {
	local scratch="$1" tool="$2" dir entry mirror n=0 old_ifs="$IFS"
	MASKED_PATH=""
	IFS=':'
	for dir in $PATH; do
		if [ -x "$dir/$tool" ]; then
			n=$((n + 1))
			mirror="$scratch/masked-$tool-$n"
			mkdir -p "$mirror"
			for entry in "$dir"/* "$dir"/.[!.]*; do
				[ -e "$entry" ] || continue
				[ "${entry##*/}" = "$tool" ] && continue
				ln -s "$entry" "$mirror/${entry##*/}"
			done
			dir="$mirror"
		fi
		MASKED_PATH="${MASKED_PATH:+$MASKED_PATH:}$dir"
	done
	IFS="$old_ifs"
}

# mask_hook_guard_path <scratch-dir>
#
# Sets CLEAN_PATH to $PATH with vrg-hook-guard masked.
mask_hook_guard_path() {
	mask_tool_path "$1" vrg-hook-guard
	CLEAN_PATH="$MASKED_PATH"
}
