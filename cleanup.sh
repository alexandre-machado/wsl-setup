#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

DRY_RUN=false

usage() {
    echo "Uso: $0 [--dry-run | -n]"
    echo ""
    echo "  --dry-run, -n   Mostra o que seria removido sem executar nada"
    echo "  --help, -h      Mostra esta mensagem"
    exit 0
}

for arg in "$@"; do
    case "$arg" in
        --dry-run|-n) DRY_RUN=true ;;
        --help|-h)    usage ;;
        *)            echo "Opção desconhecida: $arg"; usage ;;
    esac
done

header() { echo -e "\n${BOLD}${YELLOW}=== $1 ===${NC}\n"; }
info()   { echo -e "${BOLD}$1${NC}"; }
ok()     { echo -e "${GREEN}$1${NC}"; }
skip()   { echo -e "${YELLOW}  [dry-run] $1${NC}"; }

# ---------------------------------------------------------------------------
# 1. Snapshot ANTES
# ---------------------------------------------------------------------------
header "Coletando uso de disco ANTES da limpeza"

before_total=$(df --output=used / | tail -1)
declare -A before

# ---------------------------------------------------------------------------
# Descoberta dinâmica de alvos
# ---------------------------------------------------------------------------
MIN_CACHE_BYTES=$((50 * 1048576))  # 50 MB — ignora caches pequenos

# Padrões conhecidos de servidores/IDEs e caches no $HOME
known_home_targets=(
    .npm
    .yarn
    .vscode-server
    .antigravity-server
    .gradle/caches
)

# Alvos do sistema (requerem sudo)
system_targets=(
    /var/cache/apt
    /var/log/journal
)

targets=()

# 1) Auto-descobrir diretórios em ~/.cache com >= MIN_CACHE_BYTES
if [[ -d "$HOME/.cache" ]]; then
    echo -ne "  Escaneando ~/.cache...\r"
    while IFS=$'\t' read -r size dir; do
        if (( size >= MIN_CACHE_BYTES )); then
            targets+=("$dir")
        fi
    done < <(du -sb "$HOME/.cache"/*/ 2>/dev/null || true)
    echo -ne "\033[2K"
fi

# 2) Adicionar padrões conhecidos do $HOME (se existirem e não estiverem duplicados)
for name in "${known_home_targets[@]}"; do
    dir="$HOME/$name"
    if [[ -d "$dir" ]]; then
        # evita duplicata se já foi encontrado via ~/.cache scan
        local_dup=false
        for t in "${targets[@]}"; do
            [[ "$t" == "$dir" ]] && local_dup=true && break
        done
        $local_dup || targets+=("$dir")
    fi
done

# 3) Alvos do sistema
for dir in "${system_targets[@]}"; do
    [[ -d "$dir" ]] && targets+=("$dir")
done

if (( ${#targets[@]} == 0 )); then
    echo "Nenhum diretório relevante encontrado para limpeza."
    exit 0
fi

dir_size() {
    local size
    size=$(du -sb "$1" 2>/dev/null | cut -f1) || true
    echo "${size:-0}"
}

human_size() {
    local bytes=$1
    if (( bytes >= 1073741824 )); then
        printf "%.1fG" "$(echo "scale=1; $bytes/1073741824" | bc)"
    elif (( bytes >= 1048576 )); then
        printf "%.1fM" "$(echo "scale=1; $bytes/1048576" | bc)"
    elif (( bytes >= 1024 )); then
        printf "%.1fK" "$(echo "scale=1; $bytes/1024" | bc)"
    else
        printf "%dB" "$bytes"
    fi
}

for dir in "${targets[@]}"; do
    short="${dir/#$HOME/~}"
    if [[ -d "$dir" ]]; then
        echo -ne "  Calculando ${short}...\r"
        before[$dir]=$(dir_size "$dir")
    else
        before[$dir]=0
    fi
done
echo -ne "\033[2K"

if $DRY_RUN; then
    before_home=0
else
    echo -ne "  Calculando \$HOME (pode demorar)...\r"
    before_home=$(dir_size "$HOME")
    echo -ne "\033[2K"
fi

echo "Uso do disco (/)  : $(df -h --output=used / | tail -1 | xargs)"
if ! $DRY_RUN; then
    echo "Uso do \$HOME      : $(human_size "$before_home")"
fi
echo ""

printf "%-40s %10s\n" "Diretório" "Tamanho"
printf "%-40s %10s\n" "----------------------------------------" "----------"
for dir in "${targets[@]}"; do
    short="${dir/#$HOME/~}"
    printf "%-40s %10s\n" "$short" "$(human_size "${before[$dir]}")"
done

# ---------------------------------------------------------------------------
# 2. Limpeza
# ---------------------------------------------------------------------------
if $DRY_RUN; then
    header "Simulação de limpeza (dry-run)"
else
    header "Executando limpeza"
fi

clean_dir() {
    local dir="$1"
    local label="${dir/#$HOME/~}"
    if [[ -d "$dir" ]]; then
        if $DRY_RUN; then
            local size=${before[$dir]:-0}
            skip "$label seria removido ($(human_size "$size"))"
        else
            rm -rf "$dir"
            ok "  [x] $label removido"
        fi
    fi
}

# Diretórios descobertos dinamicamente
for dir in "${targets[@]}"; do
    # Pula alvos do sistema (tratados separadamente abaixo)
    [[ "$dir" == /var/* ]] && continue
    clean_dir "$dir"
done

# Comandos nativos de limpeza de ferramentas
run_tool_clean() {
    local tool="$1" cmd="$2"
    if command -v "$tool" &>/dev/null; then
        if $DRY_RUN; then
            skip "$cmd"
        else
            eval "$cmd" &>/dev/null 2>&1 && ok "  [x] $cmd"
        fi
    fi
}

run_tool_clean yarn "yarn cache clean"
run_tool_clean npm  "npm cache clean --force"
run_tool_clean uv   "uv cache clean"
run_tool_clean brew "brew cleanup --prune=all"

# APT
if $DRY_RUN; then
    skip "apt clean"
else
    sudo apt clean -y &>/dev/null && ok "  [x] apt clean"
fi

# Journal logs
if $DRY_RUN; then
    skip "journalctl vacuum (3 dias)"
else
    sudo journalctl --vacuum-time=3d &>/dev/null 2>&1 && ok "  [x] journalctl vacuum (3 dias)"
fi

if $DRY_RUN; then
    # ---------------------------------------------------------------------------
    # 3. Resumo dry-run
    # ---------------------------------------------------------------------------
    header "Resumo (dry-run — nenhuma alteração foi feita)"

    total_potential=0
    for dir in "${targets[@]}"; do
        total_potential=$((total_potential + ${before[$dir]}))
    done

    printf "${BOLD}%-40s %10s${NC}\n" "Diretório" "Tamanho"
    printf "%-40s %10s\n" "----------------------------------------" "----------"
    for dir in "${targets[@]}"; do
        short="${dir/#$HOME/~}"
        b=${before[$dir]}
        if (( b > 0 )); then
            printf "%-40s ${GREEN}%10s${NC}\n" "$short" "$(human_size "$b")"
        else
            printf "%-40s %10s\n" "$short" "-"
        fi
    done

    echo ""
    echo -e "${BOLD}Espaço potencial a liberar:${NC} ${GREEN}~$(human_size "$total_potential")${NC}"
    echo -e "${BOLD}Espaço livre atual:${NC} $(df -h --output=avail / | tail -1 | xargs)"
    echo ""
    echo -e "${YELLOW}Execute sem --dry-run para efetuar a limpeza.${NC}"
else
    # ---------------------------------------------------------------------------
    # 3. Snapshot DEPOIS
    # ---------------------------------------------------------------------------
    header "Coletando uso de disco DEPOIS da limpeza"

    after_total=$(df --output=used / | tail -1)
    declare -A after

    for dir in "${targets[@]}"; do
        short="${dir/#$HOME/~}"
        if [[ -d "$dir" ]]; then
            echo -ne "  Calculando ${short}...\r"
            after[$dir]=$(dir_size "$dir")
        else
            after[$dir]=0
        fi
    done
    echo -ne "\033[2K"

    echo -ne "  Calculando \$HOME...\r"
    after_home=$(dir_size "$HOME")
    echo -ne "\033[2K"

    echo "Uso do disco (/)  : $(df -h --output=used / | tail -1 | xargs)"
    echo "Uso do \$HOME      : $(human_size "$after_home")"

    # ---------------------------------------------------------------------------
    # 4. Relatório comparativo
    # ---------------------------------------------------------------------------
    header "Relatório de limpeza"

    printf "${BOLD}%-40s %10s %10s %10s${NC}\n" "Diretório" "Antes" "Depois" "Liberado"
    printf "%-40s %10s %10s %10s\n" "----------------------------------------" "----------" "----------" "----------"

    total_freed=0
    for dir in "${targets[@]}"; do
        short="${dir/#$HOME/~}"
        b=${before[$dir]}
        a=${after[$dir]}
        freed=$((b - a))
        total_freed=$((total_freed + freed))
        if (( freed > 0 )); then
            printf "%-40s %10s %10s ${GREEN}%10s${NC}\n" \
                "$short" "$(human_size "$b")" "$(human_size "$a")" "-$(human_size "$freed")"
        else
            printf "%-40s %10s %10s %10s\n" \
                "$short" "$(human_size "$b")" "$(human_size "$a")" "-"
        fi
    done

    echo ""
    printf "%-40s %10s %10s ${GREEN}%10s${NC}\n" \
        "\$HOME total" "$(human_size "$before_home")" "$(human_size "$after_home")" "-$(human_size $((before_home - after_home)))"

    disk_freed=$(( (before_total - after_total) * 1024 ))
    printf "%-40s %10s\n" "" ""
    echo -e "${BOLD}Espaço total liberado no disco:${NC} ${GREEN}-$(human_size "$disk_freed")${NC}"
    echo -e "${BOLD}Espaço livre atual:${NC} $(df -h --output=avail / | tail -1 | xargs)"
fi
