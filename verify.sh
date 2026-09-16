#!/usr/bin/env bash
#
# verify.sh - Cross-platform prerequisite verification script
# Verifies:
#   - agents-cli v1.4.1+
#   - python     v3.11+ (checks python3, then python)
#   - gcloud     v580+  (Google Cloud SDK)
#   - uv         v0.11.0+
#   - npx        v11+
#   - git        v2+
#
set -u

# Color configuration (respects terminal, NO_COLOR, and TERM=dumb)
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]] && [[ "${TERM:-}" != "dumb" ]]; then
    C_RED='\033[0;31m'
    C_GREEN='\033[0;32m'
    C_YELLOW='\033[0;33m'
    C_BLUE='\033[0;34m'
    C_BOLD='\033[1m'
    C_RESET='\033[0m'
else
    C_RED=''
    C_GREEN=''
    C_YELLOW=''
    C_BLUE=''
    C_BOLD=''
    C_RESET=''
fi

# Detect operating system
detect_os() {
    local uname_out
    uname_out="$(uname -s 2>/dev/null || echo "Unknown")"
    case "${uname_out}" in
        Darwin*)              echo "macos" ;;
        Linux*)               echo "linux" ;;
        CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
        *)                    echo "unknown" ;;
    esac
}

OS="$(detect_os)"

# Compare semver versions: returns 0 if $1 >= $2, 1 otherwise
version_ge() {
    local v1="${1#v}"
    local v2="${2#v}"

    local IFS=.
    local i ver1=($v1) ver2=($v2)
    local len=${#ver1[@]}
    if (( ${#ver2[@]} > len )); then
        len=${#ver2[@]}
    fi

    for ((i=0; i<len; i++)); do
        local num1="${ver1[i]:-0}"
        local num2="${ver2[i]:-0}"
        # Strip any non-numeric suffix
        num1="${num1%%[^0-9]*}"
        num2="${num2%%[^0-9]*}"
        num1="${num1:-0}"
        num2="${num2:-0}"

        if (( 10#$num1 > 10#$num2 )); then
            return 0
        fi
        if (( 10#$num1 < 10#$num2 )); then
            return 1
        fi
    done
    return 0
}

# Extract semver string from raw command output
extract_version() {
    local raw="$1"
    local parsed
    parsed="$(echo "$raw" | grep -oE '[0-9]+(\.[0-9]+)+' | head -n 1)"
    if [[ -z "$parsed" ]]; then
        parsed="$(echo "$raw" | grep -oE '[0-9]+' | head -n 1)"
    fi
    echo "$parsed"
}

# Track results
TOTAL_CHECKS=0
FAILED_CHECKS=0
REMEDIATIONS=()

record_remediation() {
    local tool="$1"
    local reason="$2"
    local remedy="$3"
    REMEDIATIONS+=("${tool}|${reason}|${remedy}")
}

print_header() {
    echo ""
    echo -e "${C_BOLD}Checking environment prerequisites (OS: ${OS})...${C_RESET}"
    echo ""
    printf "%-8s %-12s %-10s %-14s %-20s\n" "STATUS" "PACKAGE" "REQUIRED" "DETECTED" "DETAILS"
    printf "%-8s %-12s %-10s %-14s %-20s\n" "------" "-------" "--------" "--------" "-------"
}

# 1. agents-cli (v1.4.1+)
check_agents_cli() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    local req="1.4.1"
    if ! command -v agents-cli >/dev/null 2>&1; then
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        printf "${C_RED}%-8s${C_RESET} %-12s %-10s %-14s %-20s\n" "[FAIL]" "agents-cli" "${req}+" "not found" "-"
        record_remediation "agents-cli" "missing" "Install agents-cli via uv or pip:\n    uv tool install agents-cli\n    # or: pip install agents-cli"
        return
    fi

    local raw_ver ver
    raw_ver="$(agents-cli --version 2>&1 || true)"
    ver="$(extract_version "$raw_ver")"

    if [[ -z "$ver" ]]; then
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        printf "${C_RED}%-8s${C_RESET} %-12s %-10s %-14s %-20s\n" "[FAIL]" "agents-cli" "${req}+" "unknown" "could not parse version"
        record_remediation "agents-cli" "unrecognized version" "Reinstall or upgrade agents-cli:\n    uv tool install --upgrade agents-cli\n    # or: pip install --upgrade agents-cli"
    elif version_ge "$ver" "$req"; then
        printf "${C_GREEN}%-8s${C_RESET} %-12s %-10s %-14s %-20s\n" "[PASS]" "agents-cli" "${req}+" "$ver" "agents-cli"
    else
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        printf "${C_RED}%-8s${C_RESET} %-12s %-10s %-14s %-20s\n" "[FAIL]" "agents-cli" "${req}+" "$ver" "outdated"
        record_remediation "agents-cli" "outdated (${ver} < ${req})" "Upgrade agents-cli:\n    uv tool upgrade agents-cli\n    # or: pip install --upgrade agents-cli"
    fi
}

# 2. python (v3.11+, checks python3 then python)
check_python() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    local req="3.11"
    local py_bin=""
    local py_ver=""

    for candidate in python3 python; do
        if command -v "$candidate" >/dev/null 2>&1; then
            local raw_ver ver
            raw_ver="$("$candidate" --version 2>&1 || true)"
            ver="$(extract_version "$raw_ver")"
            if [[ -n "$ver" ]] && version_ge "$ver" "$req"; then
                py_bin="$candidate"
                py_ver="$ver"
                break
            elif [[ -n "$ver" ]] && [[ -z "$py_ver" ]]; then
                # Keep track of candidate even if outdated
                py_bin="$candidate"
                py_ver="$ver"
            fi
        fi
    done

    if [[ -z "$py_bin" ]]; then
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        printf "${C_RED}%-8s${C_RESET} %-12s %-10s %-14s %-20s\n" "[FAIL]" "python" "${req}+" "not found" "-"
        case "$OS" in
            macos)
                record_remediation "python" "missing" "Install Python 3.11+ via Homebrew or uv:\n    brew install python@3.11\n    # or: uv python install 3.11"
                ;;
            linux)
                record_remediation "python" "missing" "Install Python 3.11+ via apt or uv:\n    sudo apt update && sudo apt install -y python3\n    # or: uv python install 3.11"
                ;;
            windows)
                record_remediation "python" "missing" "Install Python 3.11+ via winget or official installer:\n    winget install Python.Python.3.11\n    https://www.python.org/downloads/"
                ;;
            *)
                record_remediation "python" "missing" "Install Python 3.11+ from https://www.python.org/downloads/ or via uv (uv python install 3.11)"
                ;;
        esac
        return
    fi

    if version_ge "$py_ver" "$req"; then
        printf "${C_GREEN}%-8s${C_RESET} %-12s %-10s %-14s %-20s\n" "[PASS]" "python" "${req}+" "$py_ver" "$py_bin"
    else
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        printf "${C_RED}%-8s${C_RESET} %-12s %-10s %-14s %-20s\n" "[FAIL]" "python" "${req}+" "$py_ver" "outdated ($py_bin)"
        case "$OS" in
            macos)
                record_remediation "python" "outdated (${py_ver} < ${req})" "Upgrade to Python 3.11+ via Homebrew or uv:\n    brew install python@3.11\n    # or: uv python install 3.11"
                ;;
            linux)
                record_remediation "python" "outdated (${py_ver} < ${req})" "Upgrade to Python 3.11+:\n    sudo apt update && sudo apt install -y python3\n    # or: uv python install 3.11"
                ;;
            windows)
                record_remediation "python" "outdated (${py_ver} < ${req})" "Install Python 3.11+:\n    winget install Python.Python.3.11"
                ;;
            *)
                record_remediation "python" "outdated (${py_ver} < ${req})" "Install Python 3.11+ from https://www.python.org/downloads/ or via uv (uv python install 3.11)"
                ;;
        esac
    fi
}

# 3. gcloud (v580+)
check_gcloud() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    local req="580"
    if ! command -v gcloud >/dev/null 2>&1; then
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        printf "${C_RED}%-8s${C_RESET} %-12s %-10s %-14s %-20s\n" "[FAIL]" "gcloud" "${req}+" "not found" "-"
        case "$OS" in
            macos)
                record_remediation "gcloud" "missing" "Install Google Cloud SDK:\n    brew install --cask google-cloud-sdk\n    # or: https://cloud.google.com/sdk/docs/install"
                ;;
            linux)
                record_remediation "gcloud" "missing" "Install Google Cloud SDK:\n    curl https://sdk.cloud.google.com | bash\n    # or see: https://cloud.google.com/sdk/docs/install"
                ;;
            windows)
                record_remediation "gcloud" "missing" "Install Google Cloud SDK:\n    winget install Google.CloudSDK\n    # or see: https://cloud.google.com/sdk/docs/install"
                ;;
            *)
                record_remediation "gcloud" "missing" "Install Google Cloud SDK from https://cloud.google.com/sdk/docs/install"
                ;;
        esac
        return
    fi

    local raw_ver ver
    # First line usually contains "Google Cloud SDK 581.0.0"
    raw_ver="$(gcloud --version 2>&1 | head -n 1 || true)"
    ver="$(extract_version "$raw_ver")"

    if [[ -z "$ver" ]]; then
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        printf "${C_RED}%-8s${C_RESET} %-12s %-10s %-14s %-20s\n" "[FAIL]" "gcloud" "${req}+" "unknown" "could not parse version"
        record_remediation "gcloud" "unrecognized version" "Update gcloud components:\n    gcloud components update"
    elif version_ge "$ver" "$req"; then
        printf "${C_GREEN}%-8s${C_RESET} %-12s %-10s %-14s %-20s\n" "[PASS]" "gcloud" "${req}+" "$ver" "Google Cloud SDK"
    else
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        printf "${C_RED}%-8s${C_RESET} %-12s %-10s %-14s %-20s\n" "[FAIL]" "gcloud" "${req}+" "$ver" "outdated"
        record_remediation "gcloud" "outdated (${ver} < ${req})" "Update Google Cloud CLI:\n    gcloud components update"
    fi
}

# 4. uv (v0.11.0+)
check_uv() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    local req="0.11.0"
    if ! command -v uv >/dev/null 2>&1; then
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        printf "${C_RED}%-8s${C_RESET} %-12s %-10s %-14s %-20s\n" "[FAIL]" "uv" "${req}+" "not found" "-"
        case "$OS" in
            macos)
                record_remediation "uv" "missing" "Install uv via standalone installer or brew:\n    curl -LsSf https://astral.sh/uv/install.sh | sh\n    # or: brew install uv"
                ;;
            linux)
                record_remediation "uv" "missing" "Install uv via standalone installer:\n    curl -LsSf https://astral.sh/uv/install.sh | sh"
                ;;
            windows)
                record_remediation "uv" "missing" "Install uv via PowerShell or winget:\n    powershell -ExecutionPolicy ByPass -c \"irm https://astral.sh/uv/install.ps1 | iex\"\n    # or: winget install astral-sh.uv"
                ;;
            *)
                record_remediation "uv" "missing" "Install uv via: curl -LsSf https://astral.sh/uv/install.sh | sh"
                ;;
        esac
        return
    fi

    local raw_ver ver
    raw_ver="$(uv --version 2>&1 || true)"
    ver="$(extract_version "$raw_ver")"

    if [[ -z "$ver" ]]; then
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        printf "${C_RED}%-8s${C_RESET} %-12s %-10s %-14s %-20s\n" "[FAIL]" "uv" "${req}+" "unknown" "could not parse version"
        record_remediation "uv" "unrecognized version" "Update uv:\n    uv self update"
    elif version_ge "$ver" "$req"; then
        printf "${C_GREEN}%-8s${C_RESET} %-12s %-10s %-14s %-20s\n" "[PASS]" "uv" "${req}+" "$ver" "uv"
    else
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        printf "${C_RED}%-8s${C_RESET} %-12s %-10s %-14s %-20s\n" "[FAIL]" "uv" "${req}+" "$ver" "outdated"
        record_remediation "uv" "outdated (${ver} < ${req})" "Update uv:\n    uv self update\n    # or: brew upgrade uv"
    fi
}

# 5. npx (v11+)
check_npx() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    local req="11"
    if ! command -v npx >/dev/null 2>&1; then
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        printf "${C_RED}%-8s${C_RESET} %-12s %-10s %-14s %-20s\n" "[FAIL]" "npx" "${req}+" "not found" "-"
        case "$OS" in
            macos)
                record_remediation "npx" "missing" "Install Node.js (which includes npx):\n    brew install node"
                ;;
            linux)
                record_remediation "npx" "missing" "Install Node.js (which includes npx):\n    sudo apt update && sudo apt install -y nodejs npm\n    # or use nvm: https://github.com/nvm-sh/nvm"
                ;;
            windows)
                record_remediation "npx" "missing" "Install Node.js (which includes npx):\n    winget install OpenJS.NodeJS.LTS\n    # or: https://nodejs.org/"
                ;;
            *)
                record_remediation "npx" "missing" "Install Node.js (includes npx) from https://nodejs.org/"
                ;;
        esac
        return
    fi

    local raw_ver ver
    raw_ver="$(npx --version 2>&1 || true)"
    ver="$(extract_version "$raw_ver")"

    if [[ -z "$ver" ]]; then
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        printf "${C_RED}%-8s${C_RESET} %-12s %-10s %-14s %-20s\n" "[FAIL]" "npx" "${req}+" "unknown" "could not parse version"
        record_remediation "npx" "unrecognized version" "Update npm/npx:\n    npm install -g npm@latest"
    elif version_ge "$ver" "$req"; then
        printf "${C_GREEN}%-8s${C_RESET} %-12s %-10s %-14s %-20s\n" "[PASS]" "npx" "${req}+" "$ver" "npx"
    else
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        printf "${C_RED}%-8s${C_RESET} %-12s %-10s %-14s %-20s\n" "[FAIL]" "npx" "${req}+" "$ver" "outdated"
        record_remediation "npx" "outdated (${ver} < ${req})" "Update npm/npx or Node.js:\n    npm install -g npm@latest\n    # or upgrade Node.js (e.g. brew upgrade node / nvm install 22)"
    fi
}

# 6. git (v2+)
check_git() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    local req="2"
    if ! command -v git >/dev/null 2>&1; then
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        printf "${C_RED}%-8s${C_RESET} %-12s %-10s %-14s %-20s\n" "[FAIL]" "git" "${req}+" "not found" "-"
        case "$OS" in
            macos)
                record_remediation "git" "missing" "Install Git:\n    xcode-select --install\n    # or: brew install git"
                ;;
            linux)
                record_remediation "git" "missing" "Install Git:\n    sudo apt update && sudo apt install -y git"
                ;;
            windows)
                record_remediation "git" "missing" "Install Git for Windows:\n    winget install Git.Git\n    https://git-scm.com/download/win"
                ;;
            *)
                record_remediation "git" "missing" "Install Git from https://git-scm.com/"
                ;;
        esac
        return
    fi

    local raw_ver ver
    raw_ver="$(git --version 2>&1 || true)"
    ver="$(extract_version "$raw_ver")"

    if [[ -z "$ver" ]]; then
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        printf "${C_RED}%-8s${C_RESET} %-12s %-10s %-14s %-20s\n" "[FAIL]" "git" "${req}+" "unknown" "could not parse version"
        record_remediation "git" "unrecognized version" "Update Git:\n    brew upgrade git # or package manager"
    elif version_ge "$ver" "$req"; then
        printf "${C_GREEN}%-8s${C_RESET} %-12s %-10s %-14s %-20s\n" "[PASS]" "git" "${req}+" "$ver" "git"
    else
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        printf "${C_RED}%-8s${C_RESET} %-12s %-10s %-14s %-20s\n" "[FAIL]" "git" "${req}+" "$ver" "outdated"
        case "$OS" in
            macos)
                record_remediation "git" "outdated (${ver} < ${req})" "Upgrade Git:\n    brew upgrade git"
                ;;
            linux)
                record_remediation "git" "outdated (${ver} < ${req})" "Upgrade Git:\n    sudo apt update && sudo apt install --only-upgrade git"
                ;;
            windows)
                record_remediation "git" "outdated (${ver} < ${req})" "Upgrade Git for Windows:\n    winget upgrade Git.Git"
                ;;
            *)
                record_remediation "git" "outdated (${ver} < ${req})" "Upgrade Git from https://git-scm.com/"
                ;;
        esac
    fi
}

main() {
    print_header

    check_agents_cli
    check_python
    check_gcloud
    check_uv
    check_npx
    check_git

    echo "-------------------------------------------------------------"

    if [[ "$FAILED_CHECKS" -eq 0 ]]; then
        echo -e "${C_GREEN}${C_BOLD}✓ All ${TOTAL_CHECKS} prerequisites satisfied!${C_RESET}"
        echo ""
        exit 0
    else
        local passed_checks=$((TOTAL_CHECKS - FAILED_CHECKS))
        echo -e "${C_RED}${C_BOLD}✗ ${FAILED_CHECKS} of ${TOTAL_CHECKS} checks failed (${passed_checks} passed).${C_RESET}"
        echo ""
        echo -e "${C_BOLD}${C_YELLOW}Recommended Remediation:${C_RESET}"
        echo "-------------------------------------------------------------"
        for entry in "${REMEDIATIONS[@]}"; do
            IFS='|' read -r tool reason remedy <<< "$entry"
            echo -e "${C_BOLD}• ${tool}${C_RESET} (${reason}):"
            echo -e "$remedy"
            echo ""
        done
        echo "Please install or upgrade the required tools and re-run ./verify.sh"
        echo ""
        exit 1
    fi
}

main "$@"
