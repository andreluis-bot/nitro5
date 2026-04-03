#!/bin/bash
#
# nitro-menu.sh — Executado pelo nitro-listener.py ao pressionar o botão Nitro.
#
# COMPORTAMENTO:
#   Cicla entre 3 perfis a cada pressionamento:
#     Economia → Performance → Balanceado → Economia → ...
#
#   Cada perfil combina:
#     - powerprofilesctl: controla o governor do CPU (intel_pstate)
#     - ec-fan.sh: escreve diretamente no Embedded Controller (EC) do laptop
#
# CONTROLE DE VENTOINHA (EC):
#   Registros do EC do AN517-52 (descobertos via ec_probe dump):
#     0x03 = modo: 0x00 = automático (BIOS controla), 0x1B = manual
#     0x21 = velocidade ventoinha esquerda: 0x00-0x40 (0=mín, 64=máx)
#     0x22 = velocidade ventoinha direita:  0x00-0x08 (0=mín,  8=máx)
#
# NOTIFICAÇÃO OSD:
#   Janela GTK sem decoração, fundo escuro semitransparente.
#   Aparece no centro-topo da tela por cima de qualquer janela.
#   Some automaticamente em 1.2 segundos.
#   Usa set_type_hint(SPLASHSCREEN) para garantir que fique acima no GNOME/Wayland.

EC_FAN="$HOME/nitro-key/ec-fan.sh"

# Captura DBUS da sessão gráfica (necessário quando chamado via systemd)
USER_PID=$(pgrep -u $USER gnome-session 2>/dev/null | head -1)
USER_PID=${USER_PID:-$(pgrep -u $USER gnome-shell 2>/dev/null | head -1)}
export DISPLAY=:0
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS=$(cat /proc/$USER_PID/environ 2>/dev/null \
    | tr '\0' '\n' | grep DBUS_SESSION_BUS_ADDRESS | cut -d= -f2-)
export DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-"unix:path=/run/user/$(id -u)/bus"}

# Mata OSD anterior para não acumular janelas
pkill -f "python3 -c.*Nitro OSD" 2>/dev/null
sleep 0.05

show_osd() {
    # Janela GTK tipo SPLASHSCREEN — fica acima de tudo no GNOME incluindo janelas maximizadas.
    # set_type_hint(SPLASHSCREEN) é o único hint que o GNOME respeita para sobreposição.
    python3 -c "
# Nitro OSD
import gi, sys
gi.require_version('Gtk', '3.0')
gi.require_version('Gdk', '3.0')
from gi.repository import Gtk, Gdk, GLib, Pango

title   = '$1'
subtitle= '$2'

win = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
win.set_decorated(False)
win.set_keep_above(True)
win.set_skip_taskbar_hint(True)
win.set_skip_pager_hint(True)
# SPLASHSCREEN faz o GNOME respeitar o keep_above mesmo com janelas maximizadas
win.set_type_hint(Gdk.WindowTypeHint.SPLASHSCREEN)
win.set_app_paintable(True)

screen = win.get_screen()
visual = screen.get_rgba_visual()
if visual:
    win.set_visual(visual)

def draw(w, cr):
    cr.set_source_rgba(0.08, 0.08, 0.08, 0.88)
    cr.set_operator(1)
    alloc = w.get_allocation()
    # Cantos arredondados
    r = 12
    x, y, w2, h = 0, 0, alloc.width, alloc.height
    cr.arc(x+r, y+r, r, 3.14159, 3*3.14159/2)
    cr.arc(x+w2-r, y+r, r, 3*3.14159/2, 0)
    cr.arc(x+w2-r, y+h-r, r, 0, 3.14159/2)
    cr.arc(x+r, y+h-r, r, 3.14159/2, 3.14159)
    cr.close_path()
    cr.fill()
win.connect('draw', draw)

box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
box.set_margin_top(16); box.set_margin_bottom(16)
box.set_margin_start(32); box.set_margin_end(32)

l1 = Gtk.Label(label=title)
l1.override_color(Gtk.StateFlags.NORMAL, Gdk.RGBA(1, 1, 1, 1))
a1 = Pango.AttrList()
a1.insert(Pango.attr_weight_new(Pango.Weight.BOLD))
a1.insert(Pango.attr_size_new(17 * Pango.SCALE))
l1.set_attributes(a1)

l2 = Gtk.Label(label=subtitle)
l2.override_color(Gtk.StateFlags.NORMAL, Gdk.RGBA(0.72, 0.72, 0.72, 1))
a2 = Pango.AttrList()
a2.insert(Pango.attr_size_new(13 * Pango.SCALE))
l2.set_attributes(a2)

box.add(l1); box.add(l2)
win.add(box)
win.show_all()

# Centraliza no topo do monitor principal
mon  = screen.get_monitor_geometry(0)
win.realize()
w2, h2 = win.get_size()
win.move(mon.x + (mon.width - w2) // 2, mon.y + 52)
win.present_with_time(Gdk.CURRENT_TIME)

GLib.timeout_add(1200, Gtk.main_quit)
Gtk.main()
" &
}

CURRENT=$(powerprofilesctl get 2>/dev/null || echo "balanced")
SILENT_ACTIVE=$(systemctl is-active nitro-fan-silent.service 2>/dev/null)
SILENT_PLUS_ACTIVE=$(systemctl is-active nitro-fan-silent-balanced.service 2>/dev/null)

# Ciclo de 5 modos (botão Nitro):
#   🔇 Silencioso → 🔇+ Silencioso+ → 🚀 Performance → ⚖ Balanceado → 🍃 Economia → 🔇 Silencioso

if [[ "$SILENT_ACTIVE" == "active" ]]; then
    # Silencioso → Silencioso+ (balanced, ventoinha desliga até 70°C)
    show_osd "🔇  Silencioso+" "Balanced, fan off até 70°C"
    sudo "$EC_FAN" silent+

elif [[ "$SILENT_PLUS_ACTIVE" == "active" ]]; then
    # Silencioso+ → Performance
    powerprofilesctl set performance
    show_osd "🚀  Performance" "Ventoinha: turbo!"
    sudo "$EC_FAN" turbo

elif [[ "$CURRENT" == "performance" ]]; then
    # Performance → Balanceado
    powerprofilesctl set balanced
    show_osd "⚖  Balanceado" "Ventoinha: média"
    sudo "$EC_FAN" mid

elif [[ "$CURRENT" == "balanced" && "$SILENT_PLUS_ACTIVE" != "active" ]]; then
    # Balanceado → Economia
    powerprofilesctl set power-saver
    show_osd "🍃  Economia" "Ventoinha: automática"
    sudo "$EC_FAN" auto

else
    # Economia → Silencioso
    show_osd "🔇  Silencioso" "Ventoinha off até 65°C"
    sudo "$EC_FAN" silent
fi
