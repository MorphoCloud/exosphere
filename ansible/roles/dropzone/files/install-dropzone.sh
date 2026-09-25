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
set -euo pipefail

REF="${DROPZONE_EXOSPHERE_REF:-dropzone-prototype}"
CFG=/opt/instance-config-mgt
VENV=/opt/ansible-venv
DATA=/media/volume/MyData
PORT=49529

fail() { echo "install-dropzone: $*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || fail "run with sudo"
[ -d "$CFG/.git" ] && [ -x "$VENV/bin/ansible-playbook" ] || fail "this does not look like a MorphoCloud instance"
mountpoint -q "$DATA" || fail "the MyData volume is not mounted"

# The passphrase is the one Guacamole uses for SFTP; root can read it.
PW="$(sed -n 's:.*<param name="sftp-password">\([^<]*\)</param>.*:\1:p' /opt/guacamole/config/user-mapping.xml 2>/dev/null | head -1 || true)"
if [ -z "$PW" ]; then
  read -r -s -p "Instance passphrase: " PW < /dev/tty
  echo
  [ -n "$PW" ] || fail "no passphrase"
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

IP="$(curl -sf --max-time 5 http://169.254.169.254/latest/meta-data/public-ipv4 || true)"
echo
echo "Done. Upload page (same passphrase as the desktop):"
if [ -n "$IP" ]; then
  echo "  https://https-${IP//./-}-$PORT.proxy-js2-iu.exosphere.app/Uploads/"
else
  echo "  https://https-<instance IP with dashes>-$PORT.proxy-js2-iu.exosphere.app/Uploads/"
fi
echo "Files you drop there land in the Uploads folder on the desktop."
