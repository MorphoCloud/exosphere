#!/bin/bash
# Triage a batch of instances for the unhealthy-GPU-host problem.
#
#   MC_JUMP=exouser@<runner-fip> ./triage-hosts.sh <name-pattern>
#
# The verdict comes from time-to-"running" on the console, which needs no SSH:
#   healthy host -> "starting" -> "running" in ~30s
#   sick host    -> stalls at "starting" while apt retries against a dead route
# Anything still at "starting" after ~90s is not worth waiting on; delete it and
# launch another. Egress is then confirmed over a jump host, since JS2
# instances are not reachable from outside JS2.
PATTERN="${1:-mc-}"
JUMP="${MC_JUMP:?set MC_JUMP to exouser@<runner-floating-ip>}"
SSHOPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o BatchMode=yes -o LogLevel=ERROR"

NOW=$(date -u +%s)
printf '%-24s %-8s %-6s %-26s %s\n' NAME STATUS AGE CONSOLE EGRESS
openstack server list --name "$PATTERN" -f value -c ID -c Name -c Status 2>/dev/null \
  | sed 's/\x1b\[[0-9;]*m//g' | while read -r id name status; do
  [ -z "$id" ] && continue

  created=$(openstack server show "$id" -f value -c created 2>/dev/null | tr -d '[:space:]')
  cts=$(python3 -c "import datetime;print(int(datetime.datetime.strptime('$created','%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=datetime.timezone.utc).timestamp()))" 2>/dev/null || echo "$NOW")

  log=$(openstack console log show "$id" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')
  st=$(echo "$log" | grep -o '{"status":"[a-z]*"' | tail -1 | cut -d'"' -f4)
  t0=$(echo "$log" | grep -o '"status":"starting", "epoch": [0-9]*' | head -1 | grep -o '[0-9]*$')
  t1=$(echo "$log" | grep -o '"status":"running", "epoch": [0-9]*'  | head -1 | grep -o '[0-9]*$')
  delta=""
  [ -n "$t0" ] && [ -n "$t1" ] && delta=" (+$(( (t1 - t0) / 1000 ))s)"

  ip=$(openstack server show "$id" -f json 2>/dev/null | sed -n '/^{/,$p' | python3 -c "
import json,sys
a=json.load(sys.stdin).get('addresses') or {}
v=[x for vv in a.values() for x in vv if x.startswith('10.')]
print(v[0] if v else '')" 2>/dev/null)

  egress="-"
  if [ -n "$ip" ]; then
    code=$(ssh $SSHOPTS -J "$JUMP" exouser@"$ip" \
      'curl -s -o /dev/null -w "%{http_code}" --max-time 6 https://github.com' 2>/dev/null)
    case "$code" in 200) egress=OK ;; ""|000) egress=DEAD ;; *) egress="$code" ;; esac
  fi

  printf '%-24s %-8s %-6s %-26s %s\n' \
    "$name" "$status" "$(( (NOW - cts) / 60 ))m" "${st}${delta}" "$egress"
done
