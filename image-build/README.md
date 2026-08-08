# MorphoCloud image build

Bakes a fully-provisioned MorphoCloud instance into a Glance image, so that
booting an instance stops meaning "download 3.4 GB of Slicer and ~130 Python
wheels over a network we do not control".

Measured on the first build (2026-08-08, g3.large):

| | from scratch | from baked image |
| --- | --- | --- |
| boot -> provisioned | ~8 min (5 min playbook + 3 min pip) | **2 min 29 s** |
| ansible `changed=` | 80 | 32 |
| Slicer / extension downloads | every instance | none |

## Why the image must be `raw`

JS2's Glance is Ceph-backed — `Featured-Ubuntu24` reports
`direct_url = rbd://.../images/<id>/snap`. With `disk_format=raw`, Nova boots by
taking a copy-on-write RBD clone, so a 60 GiB image boots as fast as a 2 GiB
one and nothing is transferred to the compute node. Uploading `qcow2` instead
silently loses the clone and reintroduces a per-boot download-and-convert.

Nova snapshots inherit the base image's format and properties, so
`openstack server image create` gives you `raw` plus `hw_disk_bus`,
`hw_scsi_model`, `hw_qemu_guest_agent`, `os_require_quiesce`,
`hw_firmware_type=uefi`, `hw_machine_type=q35` and `os_desktop=true` for free.
Verify them against `Featured-Ubuntu24` before publishing; `os_desktop=true` in
particular is what makes Exosphere offer the web desktop.

## Procedure

Run everything against the **Test-Instances** allocation (`BIO240357`) until the
full image matrix exists and has been validated. Instances on JS2's
`auto_allocated_network` are not reachable from outside JS2, so all SSH goes
through a runner as a jump host.

```sh
source ~/openstack/BIO240357_IU-openrc.sh
export MC_JUMP=exouser@<runner-floating-ip>
```

1. **Launch a build instance** on the target flavor from `Featured-Ubuntu24`.
   The NVIDIA driver is already in that image (`nvidia-smi` works before any of
   our ansible runs), so GPU variants differ only in which flavor you build on.

2. **`build-instance.sh`** — reproduces the production boot path
   (`Instances/cloud-config`) on an already-running instance: creates `exouser`,
   installs the ansible toolchain, clones this repo at a pinned SHA, and runs
   `ansible/playbook.yml` with `guac_enabled=true gui_enabled=true`. Running it
   over SSH rather than via cloud-init means the build does not depend on
   winning the compute-host lottery at create time (see "Known blocker").

3. **`bake-dependencies.sh`** — installs PyTorch (cu128 by default) and
   nnInteractive into Slicer's Python, then harvests every extension's declared
   requirements and writes a pinned freeze to
   `/opt/instance-config-support/pip-freeze-after.txt`. Commit that freeze
   alongside the image so the shipped set is reproducible and diffable.

4. **`sysprep.sh`** — makes the instance safe to snapshot. **Do not skip this**;
   see "Traps" below.

5. **Snapshot.**

   ```sh
   openstack server stop  <build-instance>
   openstack server image create --name morphocloud-slicer-<ver>-<variant>-<date> <build-instance>
   ```

6. **Boot-test** the image with the production cloud-config and require
   `{"status":"complete"}` on the console plus `failed=0` in the PLAY RECAP
   before promoting it.

## Traps

Both of these were found the hard way, and both are silent.

**`vncserver@1.service` must be disabled before snapshotting.** Its unit has
`ExecStartPre='ip address show dev docker0 | grep -q 172.17.0.1'` with
`Restart=always`, `RestartSec=10`, `StartLimitBurst=5`. Left enabled in an
image it starts at boot *before* Docker (observed: unit 04:50:35, docker0
04:50:37), fails, and burns all five restarts inside the 300 s window — so when
ansible later reaches `state: started` systemd answers "Start request repeated
too quickly" and the entire playbook aborts. Deterministic, 2 boots out of 2.
On a fresh instance the unit does not exist until ansible writes it, so it
starts once, after docker0 exists. **Baking inverts the ordering.** Expect more
of this shape: an image does not just skip work, it changes timing, and latent
ordering races surface.

**The Guacamole containers must be removed before snapshotting.** They hold the
*build* instance's passphrase hash in their config and would restart with it on
every instance built from the image, before the playbook re-templates. That is
a shared-credential leak, not merely a startup nuisance. `docker rm -f` them —
the images stay cached, so nothing is re-pulled.

`sysprep.sh` also clears the exouser password, `.vnc/passwd`, SSH host keys,
`machine-id`, `authorized_keys`, and runs `cloud-init clean --logs --seed`.
That last one is load-bearing: without it the `cloud-init-per instance` guard in
the boothook stays satisfied and instance setup is skipped entirely.

## Where Slicer lives

Slicer installs to **`/opt/slicer`** (`slicer_install_dir`), owned by `exouser`.
It used to install to `/media/volume/MyData`, which is the MyData volume's mount
point — that made it invisible to a snapshot and required shuttling the whole
application onto the volume after attach.

The tree must stay user-writable: the extensions manager installs into
`<slicer_install_dir>/Slicer/slicer.org/Extensions-<rev>`, so a root-owned
`/opt/slicer` breaks the Extensions Manager. Do not relocate it under
`/home/exouser` either — that is moved onto the volume during instance setup.

User data stays on the volume: the default scene path and the Guacamole SFTP
root still point at `/media/volume/MyData`.

## Known blocker: unhealthy GPU compute hosts

On 2026-08-08, 4 of 8 `g3.large` instances came up with **no route past the
tenant router** — DNS resolved, the gateway pinged, the tenant network was
reachable, but nothing beyond it. A CPU instance on the same network, same
security group, same router and with *no* floating IP had full egress, and
attaching a fresh floating IP to a healthy GPU instance did not break it. So
this is neither our configuration nor the floating-IP pool; it is a
JS2-side per-host fault. This is reported separately.

`triage-hosts.py` gives a verdict without needing SSH. There are two distinct
failure modes and it takes both signals, because the second one is silent:

- **DEAD-EGRESS** — no `"running"` marker well past the ~30 s a healthy boot
  takes. The instance usually reports `{"status":"error"}` itself.
- **WEDGED** — the `system-load-logging` heartbeat has gone stale. That cron job
  runs every minute and needs no network, so a stopped heartbeat means userspace
  is blocked rather than waiting. Seen with a hanging CephFS `/software`
  automount, which blocks anything touching `/software` (including Lmod's
  profile scripts, so sshd accepts the connection then stalls before the
  banner). This mode reports nothing on its own — without the heartbeat check it
  is indistinguishable from "still working".

Ages are measured against the newest epoch seen across the batch rather than the
local clock; the two differ by minutes. Instances whose console has scrolled
past the boot markers get no verdict rather than a false one.

## Open points

- **User-installed extensions no longer persist across instance rebuilds.**
  They used to land on the volume; they now land on `/opt/slicer` on the root
  disk. Acceptable while this is a testbed, but it needs a proper answer before
  production — probably a separate volume-backed path for user-added
  extensions, with the baked set staying in `/opt`.
- The boot path still clones this repo and re-runs the whole playbook, so
  instances still need egress at boot. Removing that needs a build-time vs
  boot-time split (ansible tags), which is the next step after the image
  matrix.
- The image matrix is not built yet: CPU (m3/r3), vGPU (g3.medium/large), A100
  passthrough (g3.xl), L40S (g4.xl).
