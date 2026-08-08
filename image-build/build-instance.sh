#!/bin/bash
# Reproduce the production boot path (MorphoCloud/Instances cloud-config,
# 90-exosphere-ansible-setup.sh) on an already-running instance.
#
# Run this ON the build instance, as root:
#   sudo EXOSPHERE_SHA=<sha> ./build-instance.sh
#
# Doing it over SSH rather than through cloud-init user-data is deliberate: it
# decouples the build from winning the compute-host lottery at create time. If
# an instance comes up on a host with no egress you discard it and launch
# another, instead of losing a whole provisioning run.
set +e
exec > /var/log/mc-build.log 2>&1

EXOSPHERE_REPO="${EXOSPHERE_REPO:-https://github.com/MorphoCloud/exosphere.git}"
EXOSPHERE_SHA="${EXOSPHERE_SHA:?set EXOSPHERE_SHA to the commit to build}"
SESSION_TIMEOUT_HRS="${SESSION_TIMEOUT_HRS:-24}"

echo "MC_BUILD_START $(date -u +%FT%TZ) sha=$EXOSPHERE_SHA"

# --- exouser, as the exosphere.yml cloud-config part creates it ---------------
if ! id exouser >/dev/null 2>&1; then
  groupadd -f admin
  useradd -m -s /bin/bash -G sudo,admin exouser
  echo 'exouser ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/90-exouser
  chmod 440 /etc/sudoers.d/90-exouser
  mkdir -p /home/exouser/.ssh
  cp /home/ubuntu/.ssh/authorized_keys /home/exouser/.ssh/authorized_keys
  chown -R exouser:exouser /home/exouser/.ssh
  chmod 700 /home/exouser/.ssh
  chmod 600 /home/exouser/.ssh/authorized_keys
fi
echo "MC_STEP exouser_ready"

# --- egress precondition, same check the production script makes -------------
if curl -s -o /dev/null --max-time 10 https://github.com \
   || curl -s -o /dev/null --max-time 10 https://pypi.org; then
  echo "MC_STEP egress_ok"
else
  echo "MC_FATAL no_outbound_network -- discard this instance and launch another"
  exit 1
fi

# --- ansible toolchain -------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y python3-venv git
python3 -m venv /opt/ansible-venv
. /opt/ansible-venv/bin/activate
pip install --upgrade pip
pip install ansible-core passlib lxml psutil
ansible-galaxy collection install community.general
echo "MC_STEP ansible_ready"

# --- pinned checkout ---------------------------------------------------------
rm -rf /opt/instance-config-mgt
git clone "$EXOSPHERE_REPO" /opt/instance-config-mgt
cd /opt/instance-config-mgt || exit 1
git reset --hard "$EXOSPHERE_SHA"
[ -f ansible/playbook.yml ] || { echo "MC_FATAL incomplete_checkout"; exit 1; }
echo "MC_STEP repo_ready $(git rev-parse --short HEAD)"

ansible-playbook \
  -i /opt/instance-config-mgt/ansible/hosts \
  -e "{\"guac_enabled\":true,\"gui_enabled\":true,\"session_timeout_hrs\":${SESSION_TIMEOUT_HRS},\"ansible_python_interpreter\":\"/opt/ansible-venv/bin/python\"}" \
  /opt/instance-config-mgt/ansible/playbook.yml
echo "MC_ANSIBLE_RC=$?"
echo "MC_FAILED_EXTENSIONS=$(cat /opt/instance-config-support/slicer_failed_extensions 2>/dev/null | tr '\n' ' ')"
echo "MC_BUILD_DONE $(date -u +%FT%TZ)"
