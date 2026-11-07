#!/bin/bash
set -e

ETHERCAT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY_DIR="$HOME/cl"

echo "========== IgH EtherCAT Build =========="

cd "$ETHERCAT_DIR"

echo "[1/9] Configurando..."
./configure --enable-generic

echo "[2/9] Compilando..."
make -j"$(nproc)"

echo "[3/9] Compilando módulos..."
make modules

echo "[4/9] Instalando..."
sudo make install
sudo make modules_install

echo "[5/9] Localizando módulos..."
MASTER=$(modinfo -n ec_master)
GENERIC=$(modinfo -n ec_generic)

echo "ec_master : $MASTER"
echo "ec_generic: $GENERIC"

echo "[6/9] Firmando módulos..."
sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 "$KEY_DIR/MOK.key" "$KEY_DIR/MOK.der" "$MASTER"
sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 "$KEY_DIR/MOK.key" "$KEY_DIR/MOK.der" "$GENERIC"

echo "[7/9] Verificando firma..."
modinfo "$MASTER" | egrep 'signer|sig_key|sig_hash' || true
modinfo "$GENERIC" | egrep 'signer|sig_key|sig_hash' || true

echo "[8/9] Actualizando módulos..."
sudo depmod -a

echo "[9/9] Cargando módulos..."
sudo modprobe ec_master
sudo modprobe ec_generic

echo "Reiniciando servicio EtherCAT..."
sudo systemctl restart ethercat || true

echo
echo "===== Estado del maestro ====="
ethercat master || true

echo
echo "===== Esclavos ====="
ethercat slaves || true

echo
echo "===== PDOs ====="
ethercat pdos || true

echo
echo "Proceso finalizado."
echo "Si el servicio falla, revisa /usr/local/etc/ethercat.conf y MASTER0_DEVICE."
