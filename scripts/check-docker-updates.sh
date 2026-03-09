#!/usr/bin/env bash
set -euo pipefail

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

echo "=== Docker Image Update Check ==="
echo "Date: $(date)"
echo ""

updates=()
errors=()

images=$(docker ps --format '{{.Image}}' | sort -u)

for image in $images; do
  echo "Checking: $image"
  if pull_output=$(docker pull "$image" 2>&1); then
    if echo "$pull_output" | grep -qi "newer image\|Downloaded newer"; then
      updates+=("$image")
      echo "  → UPDATE AVAILABLE"
    else
      echo "  → Up to date"
    fi
  else
    errors+=("$image")
    echo "  → ERROR: pull failed"
  fi
done

echo ""
echo "=== Summary ==="
echo "Updates available: ${#updates[@]}"
if (( ${#updates[@]} > 0 )); then
  echo "Services to update:"
  for img in "${updates[@]}"; do echo "  - $img"; done
fi
if (( ${#errors[@]} > 0 )); then
  echo "Pull errors:"
  for err in "${errors[@]}"; do echo "  - $err"; done
fi
(( ${#updates[@]} == 0 && ${#errors[@]} == 0 )) && echo "All images are up to date."
