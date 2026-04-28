%global debug_package %{nil}

Name:           hermes-agent
Version:        0.11.0
Release:        1%{?dist}
Summary:        Self-improving AI agent by Nous Research

License:        MIT
URL:            https://github.com/NousResearch/hermes-agent
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch
BuildRequires:  python3
BuildRequires:  python3-build
BuildRequires:  python3-pip
BuildRequires:  python3-setuptools
BuildRequires:  python3-wheel

Requires:       git
Requires:       python3
Requires:       python3-pip
Requires:       ripgrep

%description
Hermes Agent is an open source AI agent with a terminal interface, persistent
memory, skills, tool use, scheduled automations, and messaging gateway support.

This package installs the tagged upstream wheel, optional skills, and a launcher.
On first run, the launcher creates a per-user virtual environment and installs
the packaged wheel into it with pip.

%prep
%autosetup -n %{name}-%{version}

%build
python3 -m build --wheel --no-isolation

%install
install -d %{buildroot}%{_datadir}/%{name}
install -m 0644 dist/*.whl %{buildroot}%{_datadir}/%{name}/
cp -a optional-skills %{buildroot}%{_datadir}/%{name}/

install -d %{buildroot}%{_bindir}
cat > %{buildroot}%{_bindir}/hermes <<'EOF'
#!/usr/bin/env sh
set -eu

version="%{version}"
payload_dir="%{_datadir}/%{name}"
wheel="${payload_dir}/hermes_agent-${version}-py3-none-any.whl"
data_root="${XDG_DATA_HOME:-$HOME/.local/share}/hermes-agent"
extras="${HERMES_AGENT_EXTRAS:-}"
extras_key="$(printf '%s' "$extras" | LC_ALL=C tr -c 'A-Za-z0-9_.-' '_')"
install_dir="${data_root}/${version}${extras_key:+-${extras_key}}"
venv="${install_dir}/venv"
marker="${install_dir}/.installed"
cmd="$(basename "$0")"

if [ ! -f "$wheel" ]; then
  echo "Packaged Hermes Agent wheel not found: $wheel" >&2
  exit 1
fi

if [ ! -x "${venv}/bin/${cmd}" ] || [ ! -f "${marker}" ] || [ "$(cat "$marker" 2>/dev/null || true)" != "$version" ]; then
  rm -rf "$venv"
  mkdir -p "$install_dir"
  python3 -m venv "$venv"
  "${venv}/bin/python" -m pip install --upgrade pip setuptools wheel
  if [ -n "$extras" ]; then
    "${venv}/bin/python" -m pip install "${wheel}[${extras}]"
  else
    "${venv}/bin/python" -m pip install "$wheel"
  fi
  printf '%s\n' "$version" > "$marker"
fi

exec "${venv}/bin/${cmd}" "$@"
EOF
chmod 0755 %{buildroot}%{_bindir}/hermes
ln -s hermes %{buildroot}%{_bindir}/hermes-agent
ln -s hermes %{buildroot}%{_bindir}/hermes-acp

%check
test -f %{buildroot}%{_datadir}/%{name}/hermes_agent-%{version}-py3-none-any.whl
test -d %{buildroot}%{_datadir}/%{name}/optional-skills

%files
%license LICENSE
%doc README.md
%{_bindir}/hermes
%{_bindir}/hermes-agent
%{_bindir}/hermes-acp
%{_datadir}/%{name}

%changelog
* Tue Apr 28 2026 Codex Automation <noreply@users.noreply.github.com> - 0.11.0-1
- Initial COPR packaging for Hermes Agent
