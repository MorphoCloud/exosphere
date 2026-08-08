#!/bin/bash
# Make a provisioned instance safe to snapshot and reuse.
#
# Run ON the build instance, as root, immediately before `openstack server stop`:
#   sudo ./sysprep.sh
#
# After this runs you can no longer SSH in (authorized_keys is cleared), so do
# all verification first.
set +e
exec > /var/log/mc-sysprep.log 2>&1
echo "MC_SYSPREP_START $(date -u +%FT%TZ)"

# --- services that must not auto-start ahead of the playbook -----------------
# vncserver@1.service has ExecStartPre='ip address show dev docker0 | grep -q
# 172.17.0.1' with Restart=always / RestartSec=10 / StartLimitBurst=5. Left
# ENABLED in an image it starts at boot BEFORE Docker (observed: unit 04:50:35,
# docker0 04:50:37), fails, and burns all five restarts inside the 300s window.
# When ansible later reaches `state: started`, systemd answers "Start request
# repeated too quickly" and the whole playbook aborts. Deterministic, 2/2.
# On a fresh instance the unit does not exist until ansible writes it, so it
# starts once, after docker0 -- the race is unique to image-booted instances.
systemctl disable vncserver@1.service 2>/dev/null
systemctl stop vncserver@1.service 2>/dev/null
rm -f /home/exouser/.vnc/*.log /home/exouser/.vnc/*.pid

# Guacamole containers carry the BUILD instance's passphrase hash in their
# config and would restart with it on every instance built from this image,
# before the playbook re-templates. Removing the containers leaves the images
# cached, so nothing is re-pulled.
docker ps -aq --filter 'name=guac' 2>/dev/null | xargs -r docker rm -f 2>/dev/null
echo "MC_STEP services_disabled"

# --- per-instance secrets ----------------------------------------------------
# The passphrase role generates a per-instance secret, POSTs it to the metadata
# service and sets it for exouser; vnc-server and guacamole derive theirs from
# it. Snapshotting without clearing these ships one image on which every
# instance shares a desktop login and a VNC password.
passwd -d exouser
passwd -l exouser
rm -f /home/exouser/.vnc/passwd /home/exouser/.vnc/passwd.bak
rm -f /opt/instance-config-support/passphrase
find /opt /etc/guacamole /home/exouser -maxdepth 4 \
     \( -name 'user-mapping.xml' -o -name 'guacamole.properties' -o -name '*.passphrase' \) \
     -delete 2>/dev/null
echo "MC_STEP secrets_cleared"

# --- identity ----------------------------------------------------------------
rm -f /etc/ssh/ssh_host_*
truncate -s0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id
rm -f /home/exouser/.ssh/authorized_keys /home/ubuntu/.ssh/authorized_keys
echo "MC_STEP identity_cleared"

# --- cloud-init: make the next boot a first boot -----------------------------
# Load-bearing: without this the `cloud-init-per instance` guard in the
# boothook stays satisfied and instance setup is skipped entirely.
cloud-init clean --logs --seed
rm -rf /var/lib/cloud/instances/* /var/lib/cloud/instance
echo "MC_STEP cloudinit_cleaned"

# --- build residue -----------------------------------------------------------
rm -f /opt/instance-config-support/session_timeout_hrs
rm -f /opt/instance-config-support/slicer_failed_extensions
rm -rf /opt/instance-config-mgt          # re-cloned at boot
rm -f /home/exouser/.bash_history /home/ubuntu/.bash_history /root/.bash_history
apt-get clean
rm -rf /var/lib/apt/lists/*
journalctl --rotate 2>/dev/null
journalctl --vacuum-time=1s 2>/dev/null
echo "MC_SYSPREP_DONE $(date -u +%FT%TZ)"   # logged before /var/log is truncated
find /var/log -type f -exec truncate -s0 {} \; 2>/dev/null
fstrim -av 2>/dev/null
sync
