#!/bin/bash
# Enable and fix the NE16 model in the container's GVSoC (pulp-open target).
#
# The stock fconti/hsdes-container image ships GVSoC without the NE16:
#   1. the pulp-open cluster has `has_ne16 = False`, so no NE16 is instantiated
#      and every NE16 job hangs forever;
#   2. the NE16 model needs xtensor, which is not installed;
#   3. GVSoC no longer compiles with the image's GCC (missing <cstdint>);
#   4. the NE16 model's weight unpacking relies on an xtensor broadcast that
#      newer xtensor versions don't perform, so all outputs come out wrong.
#
# Safe to run several times: it does nothing once the fixed NE16 model is built.

SDK=/app/pulp-sdk
source "$SDK/configs/pulp-open.sh"
set -euo pipefail

CLUSTER_PY="$SDK/tools/gvsoc/pulp/pulp/chips/pulp_open/cluster.py"
MATRIXVEC="$SDK/tools/gvsoc/pulp/pulp/ne16/src/ne16_matrixvec.cpp"
MARKER="$SDK/install/workstation/.ne16_fixed"

if [ -f "$MARKER" ]; then
    echo "[setup-ne16] NE16 model already enabled and fixed, nothing to do."
    exit 0
fi

echo "[setup-ne16] Enabling the NE16 in GVSoC (one-time, takes a few minutes)..."

# 1. Instantiate the NE16 in the pulp-open cluster
sed -i 's/has_ne16 = False/has_ne16 = True/' "$CLUSTER_PY"
grep -q "has_ne16 = True" "$CLUSTER_PY"

# 2. xtensor headers for the NE16 model (apt version: newer releases moved the headers)
if [ ! -f /usr/include/xtensor/xarray.hpp ]; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y libxtensor-dev
fi

# 4. Fix weight unpacking (explicit broadcast instead of view assignment)
sed -i 's|xt::view(wu, xt::all(), xt::all()) = xt::view(w, xt::all(), xt::all());|wu = xt::broadcast(w, std::vector<size_t>{(size_t)size, 2, 8});|' "$MATRIXVEC"
grep -q "xt::broadcast(w," "$MATRIXVEC"

# 3. Rebuild GVSoC, force-including <cstdint>
cd "$SDK"
cmake -S . -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DCMAKE_INSTALL_PREFIX="$PULP_SDK_HOME/install/workstation" \
      -DGVSOC_MODULES="$GVSOC_MODULES" -DGVSOC_TARGETS="$GVSOC_TARGETS" \
      -DCMAKE_CXX_FLAGS="-include cstdint"
cmake --build build -j "$(nproc)"
cmake --install build

if ! find "$SDK/install" -name "*ne16*.so" | grep -q .; then
    echo "[setup-ne16] ERROR: NE16 model was not built." >&2
    exit 1
fi

touch "$MARKER"
echo "[setup-ne16] Done: GVSoC now includes a working NE16."
