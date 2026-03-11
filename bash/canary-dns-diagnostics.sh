#!/usr/bin/env bash
set -u

DOMAIN_HASH="6b42426d"
DNS_SERVER=""
VERBOSE=0

usage() {
  cat <<'EOF'

    Discovers and analyses the DNS environment to ensure it's ripe for Canary communication.

    Canaries don't communicate directly with a Canary Console and instead make use of DNS Tunnelling.
    This means that they exclusively generate DNS lookups to alert, update and get new settings.

    A typical communication path would originate from the Canary, sent to your internal DNS server
    which then recursively makes its way out to the internet.

    For more information:
    - DNS Communication Overview: https://resources.canary.tools/documents/canary-dns-communication.pdf
    - Communications and Cryptography Whitepaper: https://resources.canary.tools/documents/canary-whitepaper-communications-and-cryptography-v.1.9.pdf

Usage:
  ./canary-dns-diagnostics.sh [--dns-server <ip>] [--domain-hash <hash>] [--verbose]

Options:
  --dns-server    Query a specific DNS resolver (default: auto-detect from this host)
  --domain-hash   Canary DNS domain hash to test against (default: 6b42426d)
  --verbose       Show the raw command output for each DNS query
  -h, --help      Show this help text

Examples:
  ./canary-dns-diagnostics.sh
  ./canary-dns-diagnostics.sh --dns-server 10.0.0.53
  ./canary-dns-diagnostics.sh --domain-hash 6b42426d --verbose

Notes:
- No sudo required.
- If you are running this for a support case, run it from the same network where the Canary is deployed and include the full output in your ticket.
EOF
}

log() { printf "%s\n" "$*"; }
vlog() { if [[ "$VERBOSE" -eq 1 ]]; then printf " > %s\n" "$*"; fi; }

have() { command -v "$1" >/dev/null 2>&1; }

# Last DNS query failure reason (best-effort)
DNS_LAST_ERROR=""

# Best-effort DNS query helper.
# Outputs result text to stdout, exit 0 on success.
dns_query() {
  local qtype="$1" qname="$2" server="${3:-}"

  DNS_LAST_ERROR=""

  if ! have nslookup; then
    DNS_LAST_ERROR="missing nslookup"
    log "ERROR: Missing required DNS tool: nslookup"
    log "       Install 'dnsutils' (Debian/Ubuntu) or 'bind-utils' (Fedora/RHEL)."
    return 127
  fi

  local cmd
  if [[ -n "$server" ]]; then
    cmd="nslookup -timeout=2 -retry=1 -type=${qtype} ${qname} ${server}"
  else
    cmd="nslookup -timeout=2 -retry=1 -type=${qtype} ${qname}"
  fi
  vlog "Query via nslookup: $cmd"

  local _raw rc
  _raw="$(bash -c "$cmd" 2>&1)"; rc=$?
  if [[ $rc -eq 0 ]]; then
    printf "%s\n" "$_raw"
    return 0
  fi
  DNS_LAST_ERROR="$(echo "$_raw" | head -n 1 | tr -d '\r')"
  [[ -z "$DNS_LAST_ERROR" ]] && DNS_LAST_ERROR="query failed"
  return 1
}


# Lightweight DNS helpers used by upstream/public-IP checks.
# These avoid non-standard query types (e.g. TXT-CH) and reduce dependence on wrapper output formats.
dns_txt() { # dns_txt <name> <server>
  local name="$1" server="$2"

  DNS_LAST_ERROR=""

  if ! have nslookup; then
    DNS_LAST_ERROR="missing nslookup"
    log "ERROR: Missing required DNS tool: nslookup"
    log "       Install 'dnsutils' (Debian/Ubuntu) or 'bind-utils' (Fedora/RHEL)."
    return 127
  fi

  local _raw rc
  _raw="$(nslookup -timeout=2 -retry=1 -type=txt "$name" "$server" 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]]; then
    DNS_LAST_ERROR="$(echo "$_raw" | head -n 1 | tr -d '\r')"
    return 1
  fi
  printf "%s\n" "$_raw" | sed -n 's/.*text = "\(.*\)".*/\1/p'
  return 0
}


dns_a() { # dns_a <name> <server>
  local name="$1" server="$2"

  DNS_LAST_ERROR=""

  if ! have nslookup; then
    DNS_LAST_ERROR="missing nslookup"
    log "ERROR: Missing required DNS tool: nslookup"
    log "       Install 'dnsutils' (Debian/Ubuntu) or 'bind-utils' (Fedora/RHEL)."
    return 127
  fi

  local _raw rc
  _raw="$(nslookup -timeout=2 -retry=1 -type=a "$name" "$server" 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]]; then
    DNS_LAST_ERROR="$(echo "$_raw" | head -n 1 | tr -d '\r')"
    return 1
  fi
  printf "%s\n" "$_raw" | awk '/^Address: / {print $2}' | tail -n 1
  return 0
}

ptr_best_effort() { # ptr_best_effort <ip> [server]
  local ip="$1" server="${2:-}"

  DNS_LAST_ERROR=""

  if ! have nslookup; then
    DNS_LAST_ERROR="missing nslookup"
    log "ERROR: Missing required DNS tool: nslookup"
    log "       Install 'dnsutils' (Debian/Ubuntu) or 'bind-utils' (Fedora/RHEL)."
    return 127
  fi

  local _raw rc
  if [[ -n "$server" ]]; then
    _raw="$(nslookup -timeout=2 -retry=1 "$ip" "$server" 2>&1)"; rc=$?
  else
    _raw="$(nslookup -timeout=2 -retry=1 "$ip" 2>&1)"; rc=$?
  fi
  if [[ $rc -ne 0 ]]; then
    DNS_LAST_ERROR="$(echo "$_raw" | head -n 1 | tr -d '\r')"
    return 1
  fi
  printf "%s\n" "$_raw" | awk -F'= ' '/name =/ {print $2}' | sed 's/\.$//' | head -n 1
  return 0
}

public_ip_http() {
  local ip=""
  if have curl; then
    ip="$(curl -fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)"
    [[ -z "$ip" ]] && ip="$(curl -fsS --max-time 5 https://icanhazip.com 2>/dev/null | tr -d '
' || true)"
    [[ -z "$ip" ]] && ip="$(curl -fsS --max-time 5 https://ifconfig.me/ip 2>/dev/null | tr -d '
' || true)"
  elif have wget; then
    ip="$(wget -qO- --timeout=5 https://api.ipify.org 2>/dev/null || true)"
    [[ -z "$ip" ]] && ip="$(wget -qO- --timeout=5 https://icanhazip.com 2>/dev/null | tr -d '
' || true)"
  fi
  printf "%s" "$ip"
}
discover_dns_servers() {
  local servers=()

  if [[ -n "$DNS_SERVER" ]]; then
    servers+=("$DNS_SERVER")
    printf "%s\n" "${servers[@]}"
    return 0
  fi

  # resolvectl dns outputs per-link DNS servers if systemd-resolved is in play
  if have resolvectl; then
    # Extract IPv4 addresses from resolvectl dns
    while read -r line; do
      # Example: "Link 2 (eth0): 10.0.0.53 10.0.0.54"
      for tok in $line; do
        if [[ "$tok" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
          servers+=("$tok")
        fi
      done
    done < <(resolvectl dns 2>/dev/null || true)
  fi

  # /etc/resolv.conf
  if [[ "${#servers[@]}" -eq 0 && -r /etc/resolv.conf ]]; then
    while read -r _ ip _rest; do
      if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        servers+=("$ip")
      fi
    done < <(grep -E '^\s*nameserver\s+' /etc/resolv.conf 2>/dev/null || true)
  fi

  # Unique
  awk '!seen[$0]++' < <(printf "%s\n" "${servers[@]}") | grep -v '^$' || true
}

ms_since() {
  # Return a timestamp in nanoseconds where possible.
  # GNU date supports %N. BSD/macOS date prints a literal 'N' for %N.
  local ts
  ts="$(date +%s%N 2>/dev/null || true)"
  if [[ -n "$ts" && "$ts" != *N* ]]; then
    echo "$ts"
    return 0
  fi

  # Fallbacks for older shells/OSes (macOS bash-3.2, busybox, etc.)
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import time
print(int(time.time() * 1e9))
PY
    return 0
  fi

  if command -v python >/dev/null 2>&1; then
    python - <<'PY'
import time
print(int(time.time() * 1e9))
PY
    return 0
  fi

  if command -v perl >/dev/null 2>&1; then
    perl -MTime::HiRes=time -e 'printf("%d\n", int(time()*1e9))'
    return 0
  fi

  # Last resort: seconds only
  date +%s
}

ms_diff() {
  local start="$1" end="$2"
  # If we got seconds-only timestamps, treat them as seconds.
  if [[ ${#start} -le 10 || ${#end} -le 10 ]]; then
    echo $(( (end - start) * 1000 ))
  else
    echo $(( (end - start) / 1000000 ))
  fi
}

rand_label() {
  local n="$1"
  # DNS-safe (lowercase letters + digits), no locale surprises.
  if [[ -r /dev/urandom ]] && have tr && have head; then
    LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c "$n"
  else
    printf "%0.sx" $(seq 1 "$n")
  fi
}

http_get_title() {
  local url="$1"
  if have curl; then
    curl -m 10 -sL "$url" | sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p' | head -n 1
    return 0
  fi
  if have wget; then
    wget -T 10 -qO- "$url" | sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p' | head -n 1
    return 0
  fi
  return 1
}

https_trace_ip() {
  if have curl; then
    curl -m 10 -sL "https://1.1.1.1/cdn-cgi/trace" | awk -F= '$1=="ip"{print $2; exit}'
    return 0
  fi
  if have wget; then
    wget -T 10 -qO- "https://1.1.1.1/cdn-cgi/trace" | awk -F= '$1=="ip"{print $2; exit}'
    return 0
  fi
  return 1
}

cert_issuer() {
  # Optional. If openssl exists, we can show issuer without sudo.
  if have openssl; then
    # Connect and print issuer line
    echo | openssl s_client -connect 1.1.1.1:443 -servername 1.1.1.1 2>/dev/null \
      | openssl x509 -noout -issuer 2>/dev/null \
      | sed 's/^issuer=//'
    return 0
  fi
  return 1
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dns-server) DNS_SERVER="${2:-}"; shift 2 ;;
    --domain-hash) DOMAIN_HASH="${2:-}"; shift 2 ;;
    --verbose) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) log "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

log "=== DNS Environment Discovery ==="
log "Reviewing your DNS configuration on this host..."
if [[ "$VERBOSE" -eq 1 ]]; then
  log ""
  log "Running in verbose mode (--verbose enabled)"
fi
log ""

DNS_SERVERS=()
while IFS= read -r _dns; do
  [[ -n "${_dns}" ]] && DNS_SERVERS+=("${_dns}")
done < <(discover_dns_servers)
if [[ "${#DNS_SERVERS[@]}" -eq 0 ]]; then
  log "ERROR: No DNS servers found on this system"
  exit 1
fi

log "Using ${#DNS_SERVERS[@]} DNS server(s): ${DNS_SERVERS[*]}"
log ""

for dnsIP in "${DNS_SERVERS[@]}"; do
  log "================================================"
  log "DNS Server: $dnsIP"
  log "================================================"

  # [1] PTR hostname
  printf "\n[1] Hostname:"
  if out="$(dns_query PTR "$dnsIP" "$dnsIP")"; then
    # Try to extract a hostname from common outputs
    hn="$(echo "$out" | awk '/PTR/ {print $NF}' | sed 's/\.$//' | head -n 1)"
    [[ -z "$hn" ]] && hn="$(echo "$out" | awk '/name =/ {print $NF}' | sed 's/\.$//' | head -n 1)"
    [[ -z "$hn" ]] && hn="(unparsed)"
    printf " %s\n" "$hn"
    [[ "$VERBOSE" -eq 1 ]] && printf "%s\n" "$out" | sed 's/^/ < /'
  else
    printf " Not resolvable\n"
  fi

  # [2] Response time example.com A
  printf "[2] Response Time:"
  start="$(ms_since)"
  if dns_query A "example.com" "$dnsIP" >/dev/null; then
    end="$(ms_since)"
    rt="$(ms_diff "$start" "$end")"
    printf " %sms\n" "$rt"
  else
    printf " Failed to query\n"
  fi

  # [3] DNS Software VERSION.BIND (CHAOS TXT)
  printf "[3] DNS Software:"
  if out="$(dns_query TXT-CH "version.bind" "$dnsIP")"; then
    ver="$(echo "$out" | sed -n 's/.*"\(.*\)".*/\1/p' | head -n 1)"
    if [[ -n "$ver" ]]; then
      printf " BIND Version Check: (%s)\n" "$ver"
    else
      printf " %s\n" "$dnsIP"
    fi
  else
    printf " %s\n" "$dnsIP"
  fi

  # [4] NSID id.server (CHAOS TXT)
  printf "[4] Name Server ID:"
  if out="$(dns_query TXT-CH "id.server" "$dnsIP")"; then
    nsid="$(echo "$out" | sed -n 's/.*"\(.*\)".*/\1/p' | head -n 1)"
    if [[ -n "$nsid" ]]; then
      printf " %s\n" "$nsid"
    else
      printf " Not available\n"
    fi
  else
    printf " Not available\n"
  fi

  # [4b] Resolver self hostname (PTR via itself)
  printf "[4b] Resolver Self-Hostname:"
  if out="$(dns_query PTR "$dnsIP" "$dnsIP")"; then
    selfhn="$(echo "$out" | awk '/PTR/ {print $NF}' | sed 's/\.$//' | head -n 1)"
    [[ -z "$selfhn" ]] && selfhn="Not available"
    printf " %s\n" "$selfhn"
  else
    printf " Not available\n"
  fi

  # [5] Recursion check
  printf "[5] Recursion:"
  rnd="test-recursion-$RANDOM.example.com"
  if out="$(dns_query A "$rnd" "$dnsIP" 2>&1)"; then
    printf " Enabled\n"
  else
    # Best-effort: classify "refused"/"recursion" as disabled, otherwise assume enabled (NXDOMAIN implies recursion worked)
    if echo "$out" | grep -qiE 'refused|recursion'; then
      printf " Disabled\n"
    else
      printf " Enabled\n"
    fi
  fi
# Helpers (DNS tooling)

dns_txt() { # dns_txt <name> <server>
  local name="$1" server="$2"
  DNS_LAST_ERROR=""
  if ! command -v nslookup >/dev/null 2>&1; then
    DNS_LAST_ERROR="missing nslookup"
    return 127
  fi
  local _raw rc
  _raw="$(nslookup -timeout=2 -retry=1 -type=txt "$name" "$server" 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]]; then
    DNS_LAST_ERROR="$(echo "$_raw" | head -n 1 | tr -d '\r')"
    return 1
  fi
  printf "%s\n" "$_raw" | sed -n 's/.*text = "\(.*\)".*/\1/p'
  return 0
}

dns_a() { # dns_a <name> <server>
  local name="$1" server="$2"
  DNS_LAST_ERROR=""
  if ! command -v nslookup >/dev/null 2>&1; then
    DNS_LAST_ERROR="missing nslookup"
    return 127
  fi
  local _raw rc
  _raw="$(nslookup -timeout=2 -retry=1 -type=a "$name" "$server" 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]]; then
    DNS_LAST_ERROR="$(echo "$_raw" | head -n 1 | tr -d '\r')"
    return 1
  fi
  printf "%s\n" "$_raw" | awk '/^Address: / {print $2}' | tail -n 1
  return 0
}

ptr_best_effort() { # ptr_best_effort <ip> [server]
  local ip="$1" server="${2:-}"
  DNS_LAST_ERROR=""
  if ! command -v nslookup >/dev/null 2>&1; then
    DNS_LAST_ERROR="missing nslookup"
    return 127
  fi
  local _raw rc
  if [[ -n "$server" ]]; then
    _raw="$(nslookup -timeout=2 -retry=1 "$ip" "$server" 2>&1)"; rc=$?
  else
    _raw="$(nslookup -timeout=2 -retry=1 "$ip" 2>&1)"; rc=$?
  fi
  if [[ $rc -ne 0 ]]; then
    DNS_LAST_ERROR="$(echo "$_raw" | head -n 1 | tr -d '\r')"
    return 1
  fi
  printf "%s\n" "$_raw" | awk -F'= ' '/name =/ {print $2}' | sed 's/\.$//' | head -n 1
  return 0
}

# [6] Upstream resolver (Google special TXT)
printf "[6] Upstream DNS Check (Google):"
if out="$(dns_txt "o-o.myaddr.l.google.com" "$dnsIP")"; then
  upip="$(printf "%s
" "$out" | grep -E '^[0-9A-Fa-f:.]+$' | head -n 1)"
  if [[ -n "$upip" ]]; then
    printf " %s
" "$upip"
  else
    printf " Unable to detect (no IP in response)
"
  fi
else
  if ! have nslookup; then
    printf " Unable to detect (missing DNS tooling: nslookup)
"
  else
    reason="$(nslookup -timeout=2 -retry=1 -type=txt o-o.myaddr.l.google.com "$dnsIP" 2>&1 | head -n 1 | tr -d '
')"
    if [[ -n "$reason" ]]; then
      printf " Unable to detect (%s)
" "$reason"
    else
      printf " Unable to detect (query failed)
"
    fi
  fi
fi

# [7] Upstream resolver (Akamai)
printf "[7] Upstream DNS Check (Akamai):"
if have dig; then
  out="$(dig +short TXT whoami.ds.akahelp.net @"$dnsIP" 2>&1)"
  akip="$(printf "%s
" "$out" | sed 's/^"//; s/"$//' | awk -F'" "' '$1 == "ns" && $2 ~ /^[0-9A-Fa-f:.]+$/ { print $2; exit }')"
  if [[ -n "$akip" ]]; then
    printf " %s
" "$akip"
  else
    printf " Unable to detect (no IP in response)
"
  fi
else
  printf " Unable to detect (missing DNS tooling: dig)
"
fi

# [8] Public IP (HTTP, best effort)
printf "[8] Public IP:"
pub=""
if command -v curl >/dev/null 2>&1; then
  pub="$(curl -fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)"
  [[ -z "$pub" ]] && pub="$(curl -fsS --max-time 5 https://icanhazip.com 2>/dev/null | tr -d '\r\n' || true)"
  [[ -z "$pub" ]] && pub="$(curl -fsS --max-time 5 https://ifconfig.me/ip 2>/dev/null | tr -d '\r\n' || true)"
elif command -v wget >/dev/null 2>&1; then
  pub="$(wget -qO- --timeout=5 https://api.ipify.org 2>/dev/null || true)"
  [[ -z "$pub" ]] && pub="$(wget -qO- --timeout=5 https://icanhazip.com 2>/dev/null | tr -d '\r\n' || true)"
fi

if [[ -n "$pub" ]]; then
  printf " %s\n" "$pub"
else
  printf " Unable to detect\n"
fi



  # [9] Basic resolution example.com
  printf "\n[9] Basic Resolution (example.com):"
  if out="$(dns_query A "example.com" "$dnsIP")"; then
    ip="$(echo "$out" | awk '/\sA\s/ {print $NF}' | head -n 1)"
    [[ -z "$ip" ]] && ip="$(echo "$out" | awk 'NR==1{print $1; exit}')"
    printf " %s\n" "${ip:-OK}"
  else
    printf " Failed\n"
  fi

  # [10] CNR.io ping TXT
  printf "[10] CNR.io Ping Test:"
  if out="$(dns_query TXT "ping.cnr.io" "$dnsIP")"; then
    pong="$(echo "$out" | sed -n 's/.*"\(.*\)".*/\1/p' | head -n 1)"
    printf " %s\n" "${pong:-OK}"
  else
    printf " Failed\n"
  fi

  # [11] Progressive TXT length test
  log "[11] Progressive TXT Length Test:"
  sizes=(1 2 4 8 16 32 64 128 250)
  for sz in "${sizes[@]}"; do
    printf " %s chars:" "$sz"
    qname="test.${sz}.prb.${DOMAIN_HASH}.cnr.io"
    start="$(ms_since)"
    if out="$(dns_query TXT "$qname" "$dnsIP")"; then
      end="$(ms_since)"
      qt="$(ms_diff "$start" "$end")"
      # crude returned length of first quoted string
      txt="$(echo "$out" | sed -n 's/.*"\(.*\)".*/\1/p' | head -n 1)"
      printf " %sms (%s chars returned)\n" "$qt" "${#txt}"
      [[ "$VERBOSE" -eq 1 ]] && printf "%s\n" "$out" | sed 's/^/ < /'
    else
      printf " Failed\n"
    fi
  done

  # [12] Rate limit test: 20 queries at 250 chars 
  printf "[12] Rate Limit Test (20 queries @ 250 chars): "
  success=0; fail=0; total_ms=0
  qname="test.250.prb.${DOMAIN_HASH}.cnr.io"

  for i in $(seq 1 20); do
    start="$(ms_since)"
    out="$(dns_query TXT "$qname" "$dnsIP" 2>&1 || true)"
    rc=$?
    end="$(ms_since)"
    ms="$(ms_diff "$start" "$end")"

    if [[ "$rc" -eq 0 ]]; then
      # Extract TXT payload across common resolver outputs by concatenating quoted chunks
      # (handles: text = "..." , TXT "..." , and split TXT strings)
      txt="$(printf "%s" "$out" | grep -oE '"[^"]*"' | tr -d '"' | tr -d '\r\n')"
      if [[ -n "$txt" && "${#txt}" -ge 250 ]]; then
        total_ms=$(( total_ms + ms ))
        success=$((success+1))
      else
        fail=$((fail+1))
        [[ "$VERBOSE" -eq 1 ]] && printf " < rate-test parse failed (len=%s)\n" "${#txt}"
      fi
    else
      fail=$((fail+1))
      [[ "$VERBOSE" -eq 1 ]] && printf "%s\n" "$out" | head -n 1 | sed 's/^/ < /'
    fi
  done

  avg=0
  if [[ "$success" -gt 0 ]]; then avg=$(( total_ms / success )); fi
  printf "%s succeeded, %s failed (avg %sms)\n" "$success" "$fail" "$avg"

  # [13] HTTP test to <hash>.cnr.io
  printf "[13] HTTP Test (%s.cnr.io):" "$DOMAIN_HASH"
  title="$(http_get_title "http://${DOMAIN_HASH}.cnr.io" || true)"
  if [[ -n "$title" ]]; then
    printf " %s\n" "$title"
  else
    # If no title, still count as "connected" if we can fetch something
    if have curl; then
      if curl -m 10 -sL "http://${DOMAIN_HASH}.cnr.io" >/dev/null; then
        printf " Connected (no title found)\n"
      else
        printf " Failed\n"
      fi
    elif have wget; then
      if wget -T 10 -qO- "http://${DOMAIN_HASH}.cnr.io" >/dev/null; then
        printf " Connected (no title found)\n"
      else
        printf " Failed\n"
      fi
    else
      printf " Failed (curl/wget not available)\n"
    fi
  fi

  # [14] Public IP via HTTPS trace (Cloudflare)
  printf "[14] Public IP (HTTPS - Cloudflare):"
  ip="$(https_trace_ip || true)"
  if [[ -n "$ip" ]]; then
    printf " %s" "$ip"
    printf "\n"
  else
    printf " Failed\n"
  fi

  log ""
done

log ""
log "This tool is best paired with a support query. Feel free to reach out to support@canary.tools if your Canaries are having trouble communicating."
log ""
log "================================================"
log "Analysis Complete"
log "================================================"
