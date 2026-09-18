#!/usr/bin/env bash
# Works out what to announce for a push-triggered notification.
#
# Reads:  BEFORE, AFTER  (commit SHAs from the push event)
# Writes: variant / required / message  as KEY=value lines on stdout
#
# Test locally:
#   BEFORE=HEAD~1 AFTER=HEAD bash .github/scripts/resolve-context.sh
set -euo pipefail

BEFORE="${BEFORE:-}"
AFTER="${AFTER:-HEAD}"

SUBJECT="$(git log -1 --pretty=%s "$AFTER")"
# The workflow's trigger condition looks at the whole commit message, so marker
# detection has to as well, or a marker in the body would fire a run that then
# ignored it. The announcement text still comes from the subject alone.
FULL_MESSAGE="$(git log -1 --pretty=%B "$AFTER")"

# [notify-optional] means a green "when convenient" notice; [notify] means required.
if [[ "$FULL_MESSAGE" == *"[notify-optional]"* ]]; then
  REQUIRED=false
else
  REQUIRED=true
fi

# The announcement text is the commit subject with the marker stripped out.
MESSAGE="$(printf '%s' "$SUBJECT" \
  | sed -E 's/\[notify(-optional)?\]//g' \
  | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"

# Which pack changed? Fall back to the single commit if the previous SHA is
# unavailable (first push to a branch, or a force push).
if [ -n "$BEFORE" ] && git cat-file -e "${BEFORE}^{commit}" 2>/dev/null; then
  FILES="$(git diff --name-only "$BEFORE" "$AFTER")"
else
  FILES="$(git show --name-only --pretty=format: "$AFTER")"
fi

TOUCHED_LATEST=false
TOUCHED_FULL=false
printf '%s\n' "$FILES" | grep -q '^latest/' && TOUCHED_LATEST=true
printf '%s\n' "$FILES" | grep -q '^full/'   && TOUCHED_FULL=true

if   [ "$TOUCHED_LATEST" = true ] && [ "$TOUCHED_FULL" = true ]; then VARIANT=both
elif [ "$TOUCHED_FULL"   = true ];                                then VARIANT=full
else                                                                   VARIANT=latest
fi

echo "variant=$VARIANT"
echo "required=$REQUIRED"
echo "message=$MESSAGE"
