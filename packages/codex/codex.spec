Name:           codex
Version:        0.118.0
Release:        1%{?dist}
Summary:        Coding agent that runs locally in your terminal

License:        Apache-2.0
URL:            https://github.com/openai/codex
Source0:        %{name}-%{version}-x86_64.tar.gz
Source1:        %{name}-%{version}-aarch64.tar.gz
Source2:        %{name}-%{version}-docs.tar.gz

Requires:       ripgrep
ExclusiveArch:  aarch64 x86_64

%description
Codex CLI is a coding agent from OpenAI that runs locally in your terminal.

%prep
%setup -q -T -c -n %{name}-%{version}
tar -xzf %{SOURCE2}
%ifarch x86_64
tar -xzf %{SOURCE0}
mv codex-x86_64-unknown-linux-musl codex
%endif
%ifarch aarch64
tar -xzf %{SOURCE1}
mv codex-aarch64-unknown-linux-musl codex
%endif

%install
install -Dpm0755 codex %{buildroot}%{_bindir}/codex

%check
%{buildroot}%{_bindir}/codex --version >/dev/null

%files
%license LICENSE NOTICE
%doc README.md
%{_bindir}/codex

%changelog
* Tue Apr 07 2026 Codex Automation <noreply@users.noreply.github.com> - 0.118.0-1
- Initial COPR packaging for Codex CLI

