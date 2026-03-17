#!/bin/bash
#
# install.sh — Instala o Nitro Key do zero numa instalação limpa do Zorin OS / Ubuntu 24.04.
#
# USO:
#   git clone https://github.com/andreluis-bot/nitro5.git
#   cd nitro5
#   bash install.sh

set -e
USUARIO=$(whoami)
DESTINO="$HOME/nitro-key"

echo "======================================"
echo " Nitro Key — Instalador"
echo " Acer Nitro AN517-52 / Zorin OS"
echo "======================================"
echo ""

# 1. Dependências
echo "[1/7] Instalando dependências..."
sudo apt install -y git build-essential libcurl4-openssl-dev python3-gi gir1.2-gtk-3.0

# 2. Compilar ec_probe
echo "[2/7] Compilando ec_probe (nbfc-linux)..."
cd /tmp
rm -rf nbfc-linux
git clone https://github.com/nbfc-linux/nbfc-linux.git
cd nbfc-linux
make src/ec_probe 2>/dev/null || true

# 3. Copiar arquivos
echo "[3/7] Copiando arquivos para $DESTINO..."
mkdir -p "$DESTINO"
cp /tmp/nbfc-linux/src/ec_probe "$DESTINO/"
cp "$(dirname "$0")/nitro-listener.py" "$DESTINO/"
cp "$(dirname "$0")/nitro-menu.sh"     "$DESTINO/"
cp "$(dirname "$0")/ec-fan.sh"         "$DESTINO/"
chmod +x "$DESTINO/ec_probe" "$DESTINO/nitro-menu.sh" "$DESTINO/ec-fan.sh"

# 4. Permissão permanente no event4 (teclado AT onde o botão Nitro gera eventos)
echo "[4/7] Criando regra udev para /dev/input/event4..."
echo 'SUBSYSTEM=="input", ATTRS{phys}=="isa0060/serio0/input0", MODE="0666"' | \
    sudo tee /etc/udev/rules.d/99-nitro-keyboard.rules > /dev/null
sudo udevadm control --reload-rules
sudo udevadm trigger

# 5. Sudo sem senha para ec_probe e ec-fan.sh
echo "[5/7] Configurando sudo sem senha para ec_probe e ec-fan.sh..."
SUDOERS_LINE="$USUARIO ALL=(ALL) NOPASSWD: $DESTINO/ec_probe, $DESTINO/ec-fan.sh"
if ! sudo grep -q "nitro-key/ec_probe" /etc/sudoers 2>/dev/null; then
    echo "$SUDOERS_LINE" | sudo tee -a /etc/sudoers > /dev/null
fi

# 6. Serviço systemd do usuário
echo "[6/7] Instalando serviço systemd..."
mkdir -p "$HOME/.config/systemd/user"
cp "$(dirname "$0")/nitro-key.service" "$HOME/.config/systemd/user/"
systemctl --user daemon-reload
systemctl --user enable nitro-key.service
systemctl --user start nitro-key.service

# 7. Otimizações de kernel (swappiness, vfs_cache_pressure, dirty_ratio)
echo "[7/7] Aplicando otimizações de kernel..."
sudo tee /etc/sysctl.d/99-performance.conf > /dev/null << 'EOF'
# Reduz uso de swap com RAM abundante
vm.swappiness=10
# Kernel retém mais cache de filesystem na RAM
vm.vfs_cache_pressure=50
# Gravações em disco mais eficientes para NVMe
vm.dirty_ratio=10
vm.dirty_background_ratio=5
EOF
sudo sysctl --system > /dev/null 2>&1

echo ""
echo "======================================"
echo " Instalação concluída!"
echo "======================================"
echo ""
echo " Pressione o botão Nitro para testar."
echo ""
echo " Ciclo de perfis:"
echo "   🚀 Performance  → ventoinha turbo"
echo "   ⚖  Balanceado   → ventoinha média"
echo "   🍃 Economia     → ventoinha automática (BIOS)"
echo ""
echo " Comandos úteis:"
echo "   systemctl --user status nitro-key"
echo "   journalctl --user -u nitro-key -f"
echo "   sudo $DESTINO/ec-fan.sh [turbo|mid|auto]"
