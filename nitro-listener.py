#!/usr/bin/env python3
"""
nitro-listener.py — Detecta o botão Nitro físico e dispara o menu.

COMO FUNCIONA:
  O botão "N" do Nitro 5 (AN517-52) não usa o device padrão do acer_wmi (event18),
  mas sim o teclado AT principal (event4), com keycode 425.
  Isso foi descoberto monitorando /dev/input ao vivo — não existe documentação sobre isso.

  Este script fica rodando em background como serviço systemd (nitro-key.service),
  lê os eventos raw do kernel via /dev/input/event4, e ao detectar o keycode 425
  com value=1 (key press), executa o nitro-menu.sh.

  Debounce de 1 segundo evita disparos duplos acidentais.

SERVIÇO:
  ~/.config/systemd/user/nitro-key.service
  Inicia automaticamente no login do usuário.
  Comandos úteis:
    systemctl --user status nitro-key    # ver status
    systemctl --user restart nitro-key   # reiniciar após mudanças
    journalctl --user -u nitro-key -f    # ver log ao vivo

PERMISSÃO:
  O event4 precisa de permissão de leitura. Regra permanente em:
  /etc/udev/rules.d/99-nitro-keyboard.rules
"""

import struct, select, subprocess, os, time

EVENT_FORMAT = "llHHi"
EVENT_SIZE = struct.calcsize(EVENT_FORMAT)
DEVICE = "/dev/input/event4"   # Teclado AT — é aqui que o botão Nitro aparece (não no event18!)
NITRO_KEYCODE = 425            # Keycode descoberto ao vivo com monitoramento de /dev/input
MENU = os.path.expanduser("~/nitro-key/nitro-menu.sh")
last_trigger = 0

def get_dbus():
    """Busca o endereço D-Bus da sessão gráfica ativa do usuário.
    Necessário para que o OSD GTK funcione quando chamado fora da sessão
    gráfica (ex: via systemd)."""
    try:
        for pid in os.popen("pgrep -u $USER gnome-session gnome-shell 2>/dev/null").read().split():
            pid = pid.strip()
            if not pid:
                continue
            with open(f"/proc/{pid}/environ", "rb") as f:
                for var in f.read().split(b"\x00"):
                    if var.startswith(b"DBUS_SESSION_BUS_ADDRESS="):
                        return var.split(b"=", 1)[1].decode()
    except:
        pass
    return f"unix:path=/run/user/{os.getuid()}/bus"

print(f"Nitro listener ativo — keycode={NITRO_KEYCODE} device={DEVICE}", flush=True)

with open(DEVICE, "rb") as f:
    while True:
        r, _, _ = select.select([f], [], [], 1)
        if not r:
            continue
        data = f.read(EVENT_SIZE)
        if len(data) != EVENT_SIZE:
            continue
        _, _, ev_type, ev_code, ev_value = struct.unpack(EVENT_FORMAT, data)

        # Filtra estritamente: EV_KEY(1) + código 425 + press(1)
        # Ignora: EV_MSC(4), EV_SYN(0), KEY_REPEAT(2), KEY_RELEASE(0)
        if ev_type != 1 or ev_code != NITRO_KEYCODE or ev_value != 1:
            continue

        # Debounce: ignora pressionamentos dentro de 1 segundo
        now = time.time()
        if now - last_trigger < 1.0:
            continue

        last_trigger = now
        print("Botão Nitro!", flush=True)

        # Popen (não-bloqueante) para não atrasar a detecção do próximo evento
        subprocess.Popen(["bash", MENU], env={
            "DISPLAY": ":0",
            "DBUS_SESSION_BUS_ADDRESS": get_dbus(),
            "HOME": os.path.expanduser("~"),
            "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "XDG_RUNTIME_DIR": f"/run/user/{os.getuid()}",
        })
