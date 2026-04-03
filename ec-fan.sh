#!/bin/bash
#
# ec-fan.sh — Controla as ventoinhas do Nitro AN517-52 via Embedded Controller.
#
# REGISTROS DO EC (descobertos via dump + comparação com AN517-55):
#   0x03 — Modo: 0x00 = automático (BIOS), 0x1B = manual
#   0x21 — Velocidade ventoinha ESQUERDA: 0x00 (0) a 0x40 (64)
#   0x22 — Velocidade ventoinha DIREITA:  0x00 (0) a 0x08 (8)
#
# USO:
#   sudo ~/nitro-key/ec-fan.sh turbo    # máxima velocidade
#   sudo ~/nitro-key/ec-fan.sh mid      # metade da velocidade máxima
#   sudo ~/nitro-key/ec-fan.sh auto     # devolver controle ao BIOS
#   sudo ~/nitro-key/ec-fan.sh silent   # silenciosa até 65°C, depois auto

EC="/home/andre/nitro-key/ec_probe"

_stop_daemon() {
    systemctl stop nitro-fan-silent.service 2>/dev/null
    systemctl stop nitro-fan-silent-balanced.service 2>/dev/null
    sleep 0.3
}

case "$1" in
  turbo)
    _stop_daemon
    "$EC" write 0x03 0x1B
    "$EC" write 0x22 0x08
    "$EC" write 0x21 0x40
    ;;
  mid)
    _stop_daemon
    "$EC" write 0x03 0x1B
    "$EC" write 0x22 0x04
    "$EC" write 0x21 0x20
    ;;
  auto)
    _stop_daemon
    "$EC" write 0x22 0x00
    "$EC" write 0x21 0x00
    "$EC" write 0x03 0x00
    ;;
  silent)
    _stop_daemon
    systemctl start nitro-fan-silent.service
    ;;
  silent+)
    # Balanceado silencioso: governor balanced + ventoinha desligada até 70°C
    _stop_daemon
    systemctl start nitro-fan-silent-balanced.service
    ;;
  *)
    echo "Uso: $0 [turbo|mid|auto|silent]"
    exit 1
    ;;
esac
