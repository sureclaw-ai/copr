%global debug_package %{nil}

Name:           codex
Version:        0.128.0
Release:        1%{?dist}
Summary:        Coding agent that runs locally in your terminal

License:        Apache-2.0
URL:            https://github.com/openai/codex
Source0:        %{name}-%{version}-x86_64.tar.gz
Source1:        %{name}-%{version}-aarch64.tar.gz
Source2:        %{name}-%{version}-docs.tar.gz

Requires:       bubblewrap
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
* Fri May 01 2026 Codex Automation <noreply@users.noreply.github.com> - 0.128.0-1
- Update to v0.128.0

* Thu Apr 30 2026 Codex Automation <noreply@users.noreply.github.com> - 0.126.0-1
- Update to v0.126.0

* Sat Apr 25 2026 Codex Automation <noreply@users.noreply.github.com> - 0.125.0-1
- Update to v0.125.0

* Fri Apr 24 2026 Codex Automation <noreply@users.noreply.github.com> - 0.124.0-1
- Update to v0.124.0

* Thu Apr 23 2026 Codex Automation <noreply@users.noreply.github.com> - 0.123.0-1
- Update to v0.123.0

* Thu Apr 16 2026 Codex Automation <noreply@users.noreply.github.com> - 0.122.0-1
- Update to v0.122.0

* Thu Apr 16 2026 Codex Automation <noreply@users.noreply.github.com> - 0.121.0-1
- Update to v0.121.0

* Sat Apr 11 2026 Codex Automation <noreply@users.noreply.github.com> - 0.120.0-1
- Update to v0.120.0

* Tue Apr 07 2026 Codex Automation <noreply@users.noreply.github.com> - 0.118.0-1
- Initial COPR packaging for Codex CLI
