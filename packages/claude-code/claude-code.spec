%global debug_package %{nil}

# The native `claude` binary is a Bun single-file executable: its application
# payload is appended after the ELF image. RPM's default post-install
# processing strips the ELF, which drops that trailer and degrades the binary
# into the bare Bun runtime (so `claude` just launches Bun). Disable all
# automatic binary post-processing to ship the upstream artifact byte-for-byte.
%global __os_install_post %{nil}

Name:           claude-code
Version:        2.1.161
Release:        1%{?dist}
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
* Wed Jun 03 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.161-1
- Update to v2.1.161

* Tue Jun 02 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.160-1
- Update to v2.1.160

* Mon Jun 01 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.159-1
- Update to v2.1.159

* Sat May 30 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.158-1
- Update to v2.1.158

* Fri May 29 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.156-1
- Update to v2.1.156

* Thu May 28 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.153-1
- Update to v2.1.153

* Wed May 27 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.152-1
- Update to v2.1.152

* Sat May 23 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.150-1
- Update to v2.1.150

* Fri May 22 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.148-1
- Update to v2.1.148

* Thu May 21 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.146-1
- Update to v2.1.146

* Wed May 20 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.145-1
- Update to v2.1.145

* Tue May 19 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.144-1
- Update to v2.1.144

* Sat May 16 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.143-1
- Update to v2.1.143

* Fri May 15 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.142-1
- Update to v2.1.142

* Thu May 14 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.141-1
- Update to v2.1.141

* Wed May 13 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.140-1
- Update to v2.1.140

* Tue May 12 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.139-1
- Update to v2.1.139

* Sun May 10 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.138-1
- Update to v2.1.138

* Sat May 09 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.137-1
- Update to v2.1.137

* Fri May 08 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.133-1
- Update to v2.1.133

* Thu May 07 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.132-1
- Update to v2.1.132

* Wed May 06 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.129-1
- Update to v2.1.129

* Tue May 05 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.128-1
- Update to v2.1.128

* Fri May 01 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.126-1
- Update to v2.1.126

* Wed Apr 29 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.123-1
- Update to v2.1.123

* Tue Apr 28 2026 Codex Automation <noreply@users.noreply.github.com> - 2.1.121-1
- Update to v2.1.121

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
