# Nitro Key — Controle do botão Nitro no Linux

Controle total do botão físico **"N" (Nitro)** do **Acer Nitro AN517-52** no Linux.  
Funciona no Zorin OS 18 / Ubuntu 24.04 com kernel 6.x.

Permite ciclar entre perfis de performance e controlar as ventoinhas diretamente,  
**replicando o comportamento do NitroSense do Windows** — sem ele instalado.

---

## Instalação rápida

```bash
git clone https://github.com/andreluis-bot/nitro5.git
cd nitro5
bash install.sh
```

O script faz tudo automaticamente:
- Compila o `ec_probe` (ferramenta para acessar o EC do hardware)
- Copia os arquivos para `~/nitro-key/`
- Cria regra udev permanente para o botão
- Configura sudo sem senha para os scripts de ventoinha
- Instala e ativa o serviço systemd
- Aplica otimizações de kernel

---

## O que faz

Cada pressionamento do botão Nitro cicla entre 3 perfis:

| Toque | Perfil CPU | Ventoinha |
|---|---|---|
| 1º | 🚀 **Performance** | Turbo — velocidade máxima |
| 2º | ⚖ **Balanceado** | Média — metade da velocidade máxima |
| 3º | 🍃 **Economia** | Automático — BIOS controla pela temperatura |

Um OSD aparece no centro-topo da tela por **1.2 segundos** ao trocar de modo,  
sobreposto a qualquer janela inclusive em tela cheia.

---

## Arquivos

| Arquivo | Função |
|---|---|
| `install.sh` | Instalador automático |
| `nitro-listener.py` | Monitora `/dev/input/event4`, detecta keycode 425, chama o menu |
| `nitro-menu.sh` | Cicla entre perfis, exibe OSD GTK, controla ventoinha |
| `ec-fan.sh` | Escreve nos registros do EC para controlar velocidade das ventoinhas |
| `nitro-key.service` | Serviço systemd — inicia o listener automaticamente no login |

O binário `ec_probe` é compilado durante a instalação a partir do  
[nbfc-linux](https://github.com/nbfc-linux/nbfc-linux) e salvo em `~/nitro-key/ec_probe`.

---

## Descobertas técnicas

### O botão Nitro não está onde todos dizem

Guias online indicam que o botão Nitro usa `/dev/input/event18` (Acer WMI hotkeys).  
**No AN517-52 isso está errado.** O botão está em:

- **Device:** `/dev/input/event4` (teclado AT principal, `AT Translated Set 2 keyboard`)
- **Keycode:** `425`

Descoberto monitorando todos os `/dev/input/event*` ao vivo com Python enquanto  
o botão era pressionado — não existe documentação pública sobre isso para este modelo.

### Registros do EC (Embedded Controller)

O EC do AN517-52 foi mapeado via `ec_probe dump` e comparação com registros  
documentados do AN517-55. Confirmados testando escrita ao vivo:

| Registro | Valor | Descrição |
|---|---|---|
| `0x03` | `0x00` | Modo automático — BIOS controla a curva de temperatura |
| `0x03` | `0x1B` | Modo manual — script assume o controle |
| `0x21` | `0x00`–`0x40` | Velocidade ventoinha **esquerda** (0=min, 64=max) |
| `0x22` | `0x00`–`0x08` | Velocidade ventoinha **direita** (0=min, 8=max) |

**Valores usados:**

| Modo | 0x03 | 0x21 | 0x22 |
|---|---|---|---|
| Turbo | `0x1B` | `0x40` (64) | `0x08` (8) |
| Médio | `0x1B` | `0x20` (32) | `0x04` (4) |
| Auto | `0x00` | `0x00` | `0x00` |

---

## Otimizações de kernel aplicadas

O `install.sh` também aplica tuning de kernel em `/etc/sysctl.d/99-performance.conf`:

| Parâmetro | Valor | Motivo |
|---|---|---|
| `vm.swappiness` | `10` | Evita swap desnecessário com RAM abundante |
| `vm.vfs_cache_pressure` | `50` | Retém mais cache de filesystem na RAM |
| `vm.dirty_ratio` | `10` | Gravações mais eficientes para NVMe |
| `vm.dirty_background_ratio` | `5` | Idem |

---

## Comandos úteis

```bash
# Status do serviço
systemctl --user status nitro-key

# Reiniciar após mudanças nos scripts
systemctl --user restart nitro-key

# Ver log ao vivo
journalctl --user -u nitro-key -f

# Controle manual da ventoinha
sudo ~/nitro-key/ec-fan.sh turbo   # máximo
sudo ~/nitro-key/ec-fan.sh mid     # metade
sudo ~/nitro-key/ec-fan.sh auto    # automático (BIOS)

# Ler registros do EC
sudo ~/nitro-key/ec_probe read 0x03   # modo (0x00=auto, 0x1B=manual)
sudo ~/nitro-key/ec_probe read 0x21   # ventoinha esquerda
sudo ~/nitro-key/ec_probe read 0x22   # ventoinha direita

# Dump completo do EC
sudo ~/nitro-key/ec_probe dump
```

---

## Ambiente testado

- **Hardware:** Acer Nitro AN517-52, board Karoq_CMS, BIOS V2.06
- **CPU:** Intel Core i5-10300H
- **GPU:** NVIDIA GTX 1650 Mobile + Intel UHD (híbrido)
- **OS:** Zorin OS 18 (base Ubuntu 24.04)
- **Kernel:** 6.17.0-19-generic
- **Driver NVIDIA:** 590.48.01

---

## Dependências

- `python3` + `python3-gi` + `gir1.2-gtk-3.0` — listener e OSD
- `powerprofilesctl` — controle de perfil CPU (incluso no Zorin OS)
- `git`, `build-essential`, `libcurl4-openssl-dev` — para compilar o `ec_probe`
- `ec_probe` — compilado de [nbfc-linux](https://github.com/nbfc-linux/nbfc-linux)
