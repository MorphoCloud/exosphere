#!/usr/bin/env bash
# MorphoCloud: add the browser upload page ("drop zone") to an existing instance.
#
# Run on the instance, in the web shell or a desktop terminal:
#
#   curl -fsSL https://raw.githubusercontent.com/MorphoCloud/exosphere/dropzone-prototype/ansible/roles/dropzone/files/install-dropzone.sh | sudo bash
#
# It runs the same ansible role a new instance runs at first boot (from the
# exosphere checkout every instance already has), creates the Uploads folder
# on MyData, and prints the upload URL. Safe to run more than once.
#
# Run it again after an unshelve to get the new address: when the upload page
# is already installed it only prints the address. Options (append after
# "sudo bash -s --"):  url        print the address only
#                      reinstall  install again even if present
set -euo pipefail

REF="${DROPZONE_EXOSPHERE_REF:-dropzone-prototype}"
CFG=/opt/instance-config-mgt
VENV=/opt/ansible-venv
DATA=/media/volume/MyData
PORT=49529
MODE="${1:-auto}"

fail() { echo "install-dropzone: $*" >&2; exit 1; }

show_url() {
  local ip
  ip="$(curl -sf --max-time 5 http://169.254.169.254/latest/meta-data/public-ipv4 || true)"
  echo
  echo "Upload page (same passphrase as the desktop):"
  if [ -n "$ip" ]; then
    echo "  https://https-${ip//./-}-$PORT.proxy-js2-iu.exosphere.app/Uploads/"
  else
    echo "  https://https-<instance IP with dashes>-$PORT.proxy-js2-iu.exosphere.app/Uploads/"
  fi
  echo "Files you drop there land in the Uploads folder on the desktop."
}

case "$MODE" in
  url)
    systemctl is-active --quiet dropzone 2>/dev/null || echo "Note: the upload page is not running on this instance; run without 'url' to install it." >&2
    show_url; exit 0 ;;
  auto)
    if [ -x /opt/dropzone/copyparty-sfx.py ] && systemctl is-active --quiet dropzone 2>/dev/null; then
      echo "The upload page is already installed."
      show_url; exit 0
    fi ;;
  reinstall) ;;
  *) fail "unknown option '$MODE' (use: url, reinstall)" ;;
esac

[ "$(id -u)" = 0 ] || fail "run with sudo"
[ -d "$CFG/.git" ] && [ -x "$VENV/bin/ansible-playbook" ] || fail "this does not look like a MorphoCloud instance"
mountpoint -q "$DATA" || fail "the MyData volume is not mounted"

# The passphrase was posted to the OpenStack metadata service at first boot;
# reuse it if it can be read back, otherwise ask for it.
PW="$(curl -sf --max-time 5 http://169.254.169.254/openstack/latest/password 2>/dev/null || true)"
case "$PW" in
  ""|*'$'*|*'<'*) PW="" ;;
esac
if [ -z "$PW" ]; then
  echo "Enter the instance passphrase (the one from your email; it is not shown while typing)."
  read -r -s -p "Passphrase: " PW < /dev/tty
  echo
  [ -n "$PW" ] || fail "no passphrase entered"
fi

echo "Fetching the instance configuration ($REF)..."
git -C "$CFG" fetch -q origin "$REF"
git -C "$CFG" checkout -q FETCH_HEAD

VARS="$(mktemp)"
trap 'rm -f "$VARS"' EXIT
chmod 600 "$VARS"
printf '{"dropzone_enabled": true, "exouser_passphrase": %s, "ansible_python_interpreter": "%s/bin/python"}\n' \
  "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$PW")" "$VENV" > "$VARS"

echo "Installing the upload page..."
"$VENV/bin/ansible-playbook" -i "$CFG/ansible/hosts" --tags dropzone -e "@$VARS" "$CFG/ansible/playbook.yml" > /var/log/install-dropzone.log 2>&1 \
  || { tail -20 /var/log/install-dropzone.log >&2; fail "ansible failed; see /var/log/install-dropzone.log"; }

mkdir -p "$DATA/Uploads" /home/exouser/Desktop
chown exouser:exouser "$DATA/Uploads"
ln -sfn "$DATA/Uploads" /home/exouser/Desktop/Uploads
chown -h exouser:exouser /home/exouser/Desktop/Uploads

systemctl restart dropzone
for _ in $(seq 1 30); do
  curl -sk -o /dev/null "https://127.0.0.1:$PORT/" && break
  sleep 1
done
curl -sk -o /dev/null "https://127.0.0.1:$PORT/" || fail "the upload service did not start; see: journalctl -u dropzone"

echo "Done."
show_url
