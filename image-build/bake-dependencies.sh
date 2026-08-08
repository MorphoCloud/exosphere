#!/bin/bash
# Install Slicer's Python dependencies at BUILD time so instances never do it.
#
# Run ON the build instance, as root, after build-instance.sh:
#   sudo TORCH_INDEX=https://download.pytorch.org/whl/cu128 ./bake-dependencies.sh
#
# Emits a pinned freeze to $OUT/pip-freeze-after.txt. Commit that next to the
# image: it makes the shipped dependency set reproducible, and diffing it
# between builds shows exactly which extension pulled what.
set +e
exec > /var/log/mc-deps.log 2>&1
echo "MC_DEPS_START $(date -u +%FT%TZ)"

SLICER_DIR="${SLICER_DIR:-/opt/slicer/Slicer}"
TORCH_INDEX="${TORCH_INDEX:-https://download.pytorch.org/whl/cu128}"
PY="$SLICER_DIR/bin/PythonSlicer"
OUT=/opt/instance-config-support
mkdir -p "$OUT"

if [ ! -x "$PY" ]; then
  echo "MC_FATAL PythonSlicer not found at $PY"
  exit 1
fi
echo "MC_STEP pythonslicer=$PY"

"$PY" -m pip freeze > "$OUT/pip-freeze-before.txt" 2>/dev/null

# --- PyTorch -----------------------------------------------------------------
"$PY" -m pip install --no-cache-dir torch torchvision --index-url "$TORCH_INDEX"
echo "MC_TORCH_RC=$?"

# light-the-torch is what the SlicerPyTorch extension's UI uses to report the
# driver version (PyTorchUtilsLogic.nvidiaDriverVersionInformation imports
# light_the_torch._cb and swallows any exception, rendering an empty result as
# "NVIDIA driver: not found"). Installing torch straight from the CUDA index
# skips it, so without this the panel misreports a perfectly working GPU --
# and that panel is exactly where a user checks.
"$PY" -m pip install --no-cache-dir light-the-torch
echo "MC_LTT_RC=$?"

"$PY" -c "import torch;print('MC_TORCH_VERSION='+torch.__version__);print('MC_TORCH_CUDA_AVAILABLE='+str(torch.cuda.is_available()));print('MC_TORCH_DEVICE='+(torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'none'))"

# --- nnInteractive -----------------------------------------------------------
# Versions track SlicerNNInteractive's own floor/ceiling constants; scikit-image
# is imported directly by the plugin's lasso and is NOT declared by the backend
# from 2.5 onward.
"$PY" -m pip install --no-cache-dir "nnInteractive>=2.5.1,<3.0.0" scikit-image
echo "MC_NNINT_RC=$?"
"$PY" -c "import importlib.util as u;print('MC_NNINT_IMPORTABLE='+str(u.find_spec('nnInteractive') is not None))"

# --- extension requirements, discovered by glob ------------------------------
# Deliberately a glob, not a hardcoded module list: the shipped
# slicer-install-extension-dependencies.py enumerates four SlicerMorph modules
# by name and carries a "keep this list in sync" comment, and on Slicer 5.12.3
# it misses three files that actually ship. Match both conventions:
# requirements.txt (slicer.packaging, 5.12+) and requirements_<Module>.txt.
EXT_ROOTS=$(find "$(dirname "$SLICER_DIR")" -maxdepth 4 -type d -name "Extensions-*" 2>/dev/null)
echo "MC_EXT_ROOTS=$(echo "$EXT_ROOTS" | tr '\n' ',')"
for root in $EXT_ROOTS; do
  while IFS= read -r req; do
    [ -z "$req" ] && continue
    echo "MC_REQ=$req"
    "$PY" -m pip install --no-cache-dir -r "$req"
  done < <(find "$root" -maxdepth 6 \( -name 'requirements.txt' -o -name 'requirements_*.txt' \) 2>/dev/null)
done

# --- extensions that predate the requirements convention ---------------------
# Not every extension ships a requirements file. Photogrammetry's ClusterPhotos
# module, for example, does the older lazy dance:
#
#     try:    import transformers
#     except: slicer.util.pip_install("transformers>4.29.2")
#
# so nothing declares those deps anywhere on disk and the glob above cannot see
# them. Scan for literal pip_install arguments and install those too. Skip
# anything with a shell/format character in it -- those are computed at runtime
# (e.g. f-strings building a version range) and are not installable as written.
SCAN="$OUT/pip-scan-literals.txt"
: > "$SCAN"
for root in $EXT_ROOTS; do
  grep -rhoE "pip_install\(\s*[\"'][^\"']+[\"']" "$root" --include='*.py' 2>/dev/null \
    | sed -E "s/.*[\"']([^\"']+)[\"']/\1/" >> "$SCAN"
done
sort -u -o "$SCAN" "$SCAN"
echo "MC_SCAN_CANDIDATES=$(wc -l < "$SCAN")"
while IFS= read -r pkg; do
  [ -z "$pkg" ] && continue
  case "$pkg" in *" -"*|*"--"*|*"{"*|*"$"*) echo "MC_SCAN_SKIP=$pkg"; continue ;; esac
  echo "MC_SCAN_INSTALL=$pkg"
  "$PY" -m pip install --no-cache-dir "$pkg"
done < "$SCAN"

# --- pinned output -----------------------------------------------------------
"$PY" -m pip freeze > "$OUT/pip-freeze-after.txt" 2>/dev/null
diff <(cut -d= -f1 "$OUT/pip-freeze-before.txt" | sort -u) \
     <(cut -d= -f1 "$OUT/pip-freeze-after.txt" | sort -u) \
     | grep '^>' | sed 's/^> //' > "$OUT/pip-added.txt"
echo "MC_PACKAGES_ADDED=$(wc -l < "$OUT/pip-added.txt")"
chown -R exouser:exouser "$OUT" 2>/dev/null
echo "MC_DEPS_DONE $(date -u +%FT%TZ)"
