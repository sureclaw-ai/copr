%global debug_package %{nil}

Name:           claude-code
Version:        2.1.119
Release:        2%{?dist}
Summary:        Anthropic Claude Code terminal assistant

License:        LicenseRef-Anthropic-Claude-Code
URL:            https://github.com/anthropics/claude-code
Source0:        %{name}-%{version}.tgz
Source1:        %{name}-%{version}-linux-x64
Source2:        %{name}-%{version}-linux-arm64

ExclusiveArch:  aarch64 x86_64

%description
Claude Code is Anthropic's terminal-based coding assistant.

%prep
%setup -q -n package

%build
# Nothing to build; the release feed ships the native CLI binary.

%install
%ifarch x86_64
install -Dpm0755 %{SOURCE1} %{buildroot}%{_bindir}/claude
%endif
%ifarch aarch64
install -Dpm0755 %{SOURCE2} %{buildroot}%{_bindir}/claude
%endif

%check
%{buildroot}%{_bindir}/claude --version >/dev/null

%files
%license LICENSE.md
%doc README.md
%{_bindir}/claude

%changelog
* Tue Apr 28 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.119-2
- Package the native Linux binaries from Anthropic's release feed

* Fri Apr 24 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.119-1
- Update to v2.1.119

* Thu Apr 23 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.118-1
- Update to v2.1.118

* Wed Apr 22 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.117-1
- Update to v2.1.117

* Tue Apr 21 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.116-1
- Update to v2.1.116

* Sat Apr 18 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.114-1
- Update to v2.1.114

* Thu Apr 16 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.112-1
- Update to v2.1.112

* Thu Apr 16 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.110-1
- Update to v2.1.110

* Wed Apr 15 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.108-1
- Update to v2.1.108

* Tue Apr 14 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.105-1
- Update to v2.1.105

* Sun Apr 12 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.104-1
- Update to v2.1.104

* Sat Apr 11 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.101-1
- Update to v2.1.101

* Fri Apr 10 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.98-1
- Update to v2.1.98

* Thu Apr 09 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.97-1
- Update to v2.1.97

* Wed Apr 08 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.94-1
- Update to v2.1.94

* Tue Apr 07 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.92-2
- Install the upstream `claude` command name only

* Tue Apr 07 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.92-1
- Initial COPR packaging for Claude Code
