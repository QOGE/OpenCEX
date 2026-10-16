#!/bin/bash
set -euo pipefail

IPV4_FILE=/etc/opencex/ssh-allow.ipv4
IPV6_FILE=/etc/opencex/ssh-allow.ipv6
SSH_CHAIN=SSH_ALLOW
IN_CHAIN=OPENCEX_IN

read_cidrs() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$f" | awk 'NF'
}

ensure_chain() {
  local ipt="$1" chain="$2"
  if $ipt -nL "$chain" >/dev/null 2>&1; then
    $ipt -F "$chain"
  else
    $ipt -N "$chain"
  fi
}

apply_family() {
  local ipt="$1" loopback_src="$2" allow_file="$3"

  ensure_chain "$ipt" "$SSH_CHAIN"
  $ipt -A "$SSH_CHAIN" -s "$loopback_src" -j ACCEPT
  while read -r cidr; do
    $ipt -A "$SSH_CHAIN" -s "$cidr" -j ACCEPT
  done < <(read_cidrs "$allow_file")
  $ipt -A "$SSH_CHAIN" -j DROP

  ensure_chain "$ipt" "$IN_CHAIN"
  $ipt -A "$IN_CHAIN" -i lo -j ACCEPT
  $ipt -A "$IN_CHAIN" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  if [[ "$ipt" == "iptables" ]]; then
    $ipt -A "$IN_CHAIN" -p icmp -m icmp --icmp-type destination-unreachable -j ACCEPT
    $ipt -A "$IN_CHAIN" -p icmp -m icmp --icmp-type time-exceeded -j ACCEPT
    $ipt -A "$IN_CHAIN" -p icmp -m icmp --icmp-type parameter-problem -j ACCEPT
  else
    $ipt -A "$IN_CHAIN" -p ipv6-icmp -j ACCEPT
  fi
  $ipt -A "$IN_CHAIN" -p tcp --dport 22 -j "$SSH_CHAIN"
  $ipt -A "$IN_CHAIN" -p tcp --dport 80 -j ACCEPT
  $ipt -A "$IN_CHAIN" -p tcp --dport 443 -j ACCEPT
  $ipt -A "$IN_CHAIN" -p tcp --dport 42069 -j ACCEPT
  # Docker-bridge to host QOGE RPC. Daemon binds 172.17.0.1/172.18.0.1, not the public IP.
  if [[ "$ipt" == "iptables" ]]; then
    $ipt -A "$IN_CHAIN" -p tcp -s 172.16.0.0/12 --dport 8332 -j ACCEPT
  fi

  if $ipt -C INPUT -p tcp --dport 22 -j "$SSH_CHAIN" >/dev/null 2>&1; then
    $ipt -D INPUT -p tcp --dport 22 -j "$SSH_CHAIN"
  fi
  if ! $ipt -C INPUT -j "$IN_CHAIN" >/dev/null 2>&1; then
    $ipt -I INPUT 1 -j "$IN_CHAIN"
  fi
  $ipt -P INPUT DROP
}


write_nginx_admin_allow() {
  local out=/etc/opencex/nginx-admin-allow.conf
  {
    echo "# generated from /etc/opencex/ssh-allow.ipv4 and ssh-allow.ipv6"
    echo "allow 127.0.0.1;"
    echo "allow ::1;"
    while read -r cidr; do
      echo "allow $cidr;"
    done < <(read_cidrs /etc/opencex/ssh-allow.ipv4)
    while read -r cidr; do
      echo "allow $cidr;"
    done < <(read_cidrs /etc/opencex/ssh-allow.ipv6)
    echo "deny all;"
  } > "$out"
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx frontend; then
    docker exec frontend nginx -t
    docker exec frontend nginx -s reload
  fi
}

apply_family iptables 127.0.0.1 "$IPV4_FILE"
apply_family ip6tables ::1 "$IPV6_FILE"

write_nginx_admin_allow
echo "Host INPUT policy is DROP. Allowed: SSH allowlist, 80, 443, QOGE P2P 42069, Docker 8332 from 172.16.0.0/12."
echo "==== IPv4 INPUT ===="
iptables -nL INPUT
echo "==== IPv4 $IN_CHAIN ===="
iptables -nL "$IN_CHAIN"
echo "==== IPv4 $SSH_CHAIN ===="
iptables -nL "$SSH_CHAIN"
echo "==== IPv6 INPUT ===="
ip6tables -nL INPUT
echo "==== IPv6 $IN_CHAIN ===="
ip6tables -nL "$IN_CHAIN"
