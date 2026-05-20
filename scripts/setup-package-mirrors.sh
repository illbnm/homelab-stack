#!/usr/bin/env bash
set -euo pipefail

MODE=${1:---help}
APT_MIRROR=${APT_MIRROR:-https://mirrors.tuna.tsinghua.edu.cn/ubuntu/}
PIP_MIRROR=${PIP_MIRROR:-https://pypi.tuna.tsinghua.edu.cn/simple}
APK_MIRROR=${APK_MIRROR:-https://mirrors.ustc.edu.cn/alpine}

usage() {
  cat <<'USAGE'
Usage: scripts/setup-package-mirrors.sh --host|--print-entrypoint|--help

  --host             Configure host apt/pip/apk mirrors when those package
                     managers exist. Uses sudo if needed.
  --print-entrypoint Print a shell snippet that service entrypoints can source
                     before apt/pip/apk installs.
USAGE
}

write_file() {
  local path=$1 content=$2
  if [[ "$(id -u)" -eq 0 || -w "$(dirname "$path")" ]]; then
    printf '%s\n' "$content" > "$path"
  else
    printf '%s\n' "$content" | sudo tee "$path" >/dev/null
  fi
}

configure_apt() {
  command -v apt-get >/dev/null 2>&1 || return 0
  local codename
  codename=$( . /etc/os-release && printf '%s' "${VERSION_CODENAME:-jammy}" )
  write_file /etc/apt/sources.list "deb $APT_MIRROR $codename main restricted universe multiverse
deb $APT_MIRROR $codename-updates main restricted universe multiverse
deb $APT_MIRROR $codename-backports main restricted universe multiverse
deb $APT_MIRROR $codename-security main restricted universe multiverse"
}

configure_pip() {
  local pip_conf=/etc/pip.conf
  write_file "$pip_conf" "[global]
index-url = $PIP_MIRROR
trusted-host = pypi.tuna.tsinghua.edu.cn"
}

configure_apk() {
  [[ -d /etc/apk ]] || return 0
  local branch=v3.20
  [[ -f /etc/alpine-release ]] && branch="v$(cut -d. -f1,2 /etc/alpine-release)"
  write_file /etc/apk/repositories "$APK_MIRROR/$branch/main
$APK_MIRROR/$branch/community"
}

print_entrypoint() {
  cat <<SNIPPET
# HomeLab CN package mirror snippet
export PIP_INDEX_URL="${PIP_MIRROR}"
export PIP_TRUSTED_HOST="pypi.tuna.tsinghua.edu.cn"
if command -v sed >/dev/null 2>&1 && [ -f /etc/apt/sources.list ]; then
  sed -i 's#http://archive.ubuntu.com/ubuntu/#${APT_MIRROR}#g; s#http://security.ubuntu.com/ubuntu/#${APT_MIRROR}#g' /etc/apt/sources.list || true
fi
if [ -d /etc/apk ]; then
  alpine_branch="v\$(cut -d. -f1,2 /etc/alpine-release 2>/dev/null || printf '3.20')"
  printf '%s/%s/main\n%s/%s/community\n' '${APK_MIRROR}' "\$alpine_branch" '${APK_MIRROR}' "\$alpine_branch" > /etc/apk/repositories || true
fi
SNIPPET
}

case "$MODE" in
  --host)
    configure_apt
    configure_pip
    configure_apk
    ;;
  --print-entrypoint)
    print_entrypoint
    ;;
  --help|-h)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
