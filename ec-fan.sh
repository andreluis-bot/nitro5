#!/bin/bash
#
# ec-fan.sh — Controla as ventoinhas do Nitro AN517-52 via Embedded Controller.
#
# CONTEXTO:
#   No Windows, o NitroSense usa uma API proprietária da Acer para controlar
#   as ventoinhas diretamente. No Linux, o driver acer_wmi não implementa isso
#   para o AN517-52, então as ventoinhas ficam sob controle exclusivo do BIOS.
#
#   Este script usa o ec_probe (compilado do nbfc-linux) para escrever diretamente
#   nos registros do EC, replicando o que o NitroSense faz no Windows.
#
# REGISTROS DO EC (descobertos via dump + comparação com AN517-55):
#   0x03 — Modo de controle:
#           0x00 = automático (BIOS controla a curva de temperatura)
#           0x1B = manual (este script assume o controle)
#   0x21 — Velocidade ventoinha ESQUERDA: 0x00 (0) a 0x40 (64)
#   0x22 — Velocidade ventoinha DIREITA:  0x00 (0) a 0x08 (8)
#
# FERRAMENTA:
#   ~/nitro-key/ec_probe — compilado de https://github.com/nbfc-linux/nbfc-linux
#   Requer root (acessa registros do hardware diretamente)
#
# SUDO SEM SENHA (configurar em /etc/sudoers):
#   SEU_USUARIO ALL=(ALL) NOPASSWD: /home/SEU_USUARIO/nitro-key/ec-fan.sh
#   SEU_USUARIO ALL=(ALL) NOPASSWD: /home/SEU_USUARIO/nitro-key/ec_probe
#
# USO:
#   sudo ~/nitro-key/ec-fan.sh turbo   # máxima velocidade
#   sudo ~/nitro-key/ec-fan.sh mid     # metade da velocidade máxima
#   sudo ~/nitro-key/ec-fan.sh auto    # devolver controle ao BIOS

EC="/home/$USER/nitro-key/ec_probe"

case "$1" in
  turbo)
    # Modo manual, velocidade máxima (equivale ao "Turbo" do NitroSense)
    "$EC" write 0x03 0x1B
    "$EC" write 0x22 0x08
    "$EC" write 0x21 0x40
    ;;
  mid)
    # Modo manual, metade da velocidade
    "$EC" write 0x03 0x1B
    "$EC" write 0x22 0x04
    "$EC" write 0x21 0x20
    ;;
  auto)
    # Zera velocidades e devolve controle ao BIOS
    "$EC" write 0x22 0x00
    "$EC" write 0x21 0x00
    "$EC" write 0x03 0x00
    ;;
  *)
    echo "Uso: $0 [turbo|mid|auto]"
    exit 1
    ;;
esac
