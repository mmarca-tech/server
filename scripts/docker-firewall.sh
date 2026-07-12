#!/usr/bin/env bash
set -euo pipefail

external_interface="${EXTERNAL_INTERFACE:-$(ip route show default | awk 'NR==1 {print $5}')}"
[[ -n "$external_interface" ]] || {
  echo "Cannot determine external interface" >&2
  exit 1
}

apply_family() {
  local command="$1"
  command -v "$command" >/dev/null 2>&1 || return 0
  "$command" -N DOCKER-USER 2>/dev/null || true
  "$command" -C DOCKER-USER -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null \
    || "$command" -I DOCKER-USER 1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  "$command" -C DOCKER-USER -i "$external_interface" -p tcp -m multiport --dports 80,443 -j ACCEPT 2>/dev/null \
    || "$command" -I DOCKER-USER 2 -i "$external_interface" -p tcp -m multiport --dports 80,443 -j ACCEPT
  "$command" -C DOCKER-USER -i "$external_interface" -p udp --dport 443 -j ACCEPT 2>/dev/null \
    || "$command" -I DOCKER-USER 3 -i "$external_interface" -p udp --dport 443 -j ACCEPT
  "$command" -C DOCKER-USER -i "$external_interface" -j DROP 2>/dev/null \
    || "$command" -A DOCKER-USER -i "$external_interface" -j DROP
  "$command" -C DOCKER-USER -j RETURN 2>/dev/null || "$command" -A DOCKER-USER -j RETURN
}

apply_family iptables
apply_family ip6tables
