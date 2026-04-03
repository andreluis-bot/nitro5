#!/bin/bash
#
# nitro-fan-daemon.sh — Daemon de controle térmico do Nitro AN517-52.
#
# MODOS (passados como argumento $1):
#
#   silent   — power-saver + ventoinha desligada até TEMP_ON_SILENT (65°C)
#              Ideal para: uso muito leve, bateria, silêncio absoluto
#              CPU: 900 MHz (governor powersave)
#
#   balanced — balanced + ventoinha desligada até TEMP_ON_BALANCED (70°C)
#              Ideal para: trabalho típico (código, browser, N8N)
#              CPU: 800–3800 MHz conforme demanda
#              Ventoinha: só liga em carga sustentada, silenciosa no uso normal
#
# HYSTERESIS:
#   Ventoinha liga  em TEMP_ON  (evita ligar cedo demais)
#   Ventoinha desliga em TEMP_OFF (evita liga/desliga rápido)
#
# SEGURANÇA:
#   3 falhas de leitura consecutivas → entrega controle ao BIOS

EC="/home/andre/nitro-key/ec_probe"

MODE="${1:-silent}"

if [[ "$MODE" == "balanced" ]]; then
    TEMP_ON=70
    TEMP_OFF=60
    powerprofilesctl set balanced
else
    TEMP_ON=65
    TEMP_OFF=55
    powerprofilesctl set power-saver
fi

INTERVAL=3
FAIL_MAX=3

fan_off() {
    "$EC" write 0x03 0x1B
    "$EC" write 0x22 0x00
    "$EC" write 0x21 0x00
}

fan_auto() {
    "$EC" write 0x22 0x00
    "$EC" write 0x21 0x00
    "$EC" write 0x03 0x00
}

get_temp() {
    local t
    t=$(sensors 2>/dev/null | awk '/Package id 0/ {gsub(/[^0-9.]/,"",$4); print int($4); exit}')
    echo "${t:-0}"
}

cleanup() {
    fan_auto
    exit 0
}
trap cleanup SIGTERM SIGINT

fan_off
STATE="off"
FAIL_COUNT=0

while true; do
    TEMP=$(get_temp)

    if [[ "$TEMP" -eq 0 ]]; then
        (( FAIL_COUNT++ ))
        if [[ "$FAIL_COUNT" -ge "$FAIL_MAX" ]]; then
            fan_auto
            STATE="auto"
        fi
    else
        FAIL_COUNT=0
        if [[ "$STATE" == "off" && "$TEMP" -ge "$TEMP_ON" ]]; then
            fan_auto
            STATE="auto"
        elif [[ "$STATE" == "auto" && "$TEMP" -le "$TEMP_OFF" ]]; then
            fan_off
            STATE="off"
        fi
    fi

    sleep "$INTERVAL"
done
