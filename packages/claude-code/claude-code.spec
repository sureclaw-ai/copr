%global debug_package %{nil}

Name:           claude-code
Version:        2.1.117
Release:        1%{?dist}
Summary:        Anthropic Claude Code terminal assistant

License:        LicenseRef-Anthropic-Claude-Code
URL:            https://github.com/anthropics/claude-code
Source0:        %{name}-%{version}.tgz

BuildRequires:  nodejs >= 18
Requires:       nodejs >= 18
ExclusiveArch:  aarch64 x86_64

%description
Claude Code is Anthropic's terminal-based coding assistant.

%prep
%setup -q -n package

%build
# Nothing to build; the npm tarball ships the CLI entrypoint plus native vendor assets.

%install
install -d %{buildroot}%{_libexecdir}/%{name}
install -pm0644 cli.js %{buildroot}%{_libexecdir}/%{name}/cli.js
install -pm0644 sdk-tools.d.ts %{buildroot}%{_libexecdir}/%{name}/sdk-tools.d.ts

install -d %{buildroot}%{_libexecdir}/%{name}/vendor/ripgrep
install -d %{buildroot}%{_libexecdir}/%{name}/vendor/audio-capture
install -d %{buildroot}%{_libexecdir}/%{name}/vendor/seccomp
install -pm0644 vendor/ripgrep/COPYING %{buildroot}%{_libexecdir}/%{name}/vendor/ripgrep/COPYING

%ifarch x86_64
cp -a vendor/ripgrep/x64-linux %{buildroot}%{_libexecdir}/%{name}/vendor/ripgrep/
cp -a vendor/audio-capture/x64-linux %{buildroot}%{_libexecdir}/%{name}/vendor/audio-capture/
cp -a vendor/seccomp/x64 %{buildroot}%{_libexecdir}/%{name}/vendor/seccomp/
%endif
%ifarch aarch64
cp -a vendor/ripgrep/arm64-linux %{buildroot}%{_libexecdir}/%{name}/vendor/ripgrep/
cp -a vendor/audio-capture/arm64-linux %{buildroot}%{_libexecdir}/%{name}/vendor/audio-capture/
cp -a vendor/seccomp/arm64 %{buildroot}%{_libexecdir}/%{name}/vendor/seccomp/
%endif

install -d %{buildroot}%{_bindir}
cat > %{buildroot}%{_bindir}/claude <<'EOF'
#!/bin/sh
exec /usr/bin/node /usr/libexec/claude-code/cli.js "$@"
EOF
chmod 0755 %{buildroot}%{_bindir}/claude

%check
node ./cli.js --version >/dev/null

%files
%license LICENSE.md vendor/ripgrep/COPYING
%doc README.md
%{_bindir}/claude
%{_libexecdir}/%{name}/

%changelog
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
