%global debug_package %{nil}

Name:           opencode
Version:        1.14.28
Release:        1%{?dist}
Summary:        Open source AI coding agent for the terminal

License:        MIT
URL:            https://github.com/anomalyco/opencode
Source0:        %{name}-%{version}-x86_64.tar.gz
Source1:        %{name}-%{version}-aarch64.tar.gz
Source2:        %{name}-%{version}-docs.tar.gz

ExclusiveArch:  aarch64 x86_64

%description
OpenCode is an open source AI coding agent for the terminal.

%prep
%setup -q -T -c -n %{name}-%{version}
tar -xzf %{SOURCE2}
%ifarch x86_64
tar -xzf %{SOURCE0}
%endif
%ifarch aarch64
tar -xzf %{SOURCE1}
%endif

%install
install -Dpm0755 opencode %{buildroot}%{_bindir}/opencode

%check
%{buildroot}%{_bindir}/opencode --version >/dev/null

%files
%license LICENSE
%doc README.md
%{_bindir}/opencode

%changelog
* Tue Apr 28 2026 Codex Automation <noreply@users.noreply.github.com> - 1.14.28-1
- Update to v1.14.28

* Mon Apr 27 2026 Codex Automation <noreply@users.noreply.github.com> - 1.14.27-1
- Update to v1.14.27

* Sun Apr 26 2026 Codex Automation <noreply@users.noreply.github.com> - 1.14.25-1
- Update to v1.14.25

* Sat Apr 25 2026 Codex Automation <noreply@users.noreply.github.com> - 1.14.24-1
- Update to v1.14.24

* Fri Apr 24 2026 Codex Automation <noreply@users.noreply.github.com> - 1.14.22-1
- Update to v1.14.22

* Wed Apr 22 2026 Codex Automation <noreply@users.noreply.github.com> - 1.14.20-1
- Update to v1.14.20

* Tue Apr 21 2026 Codex Automation <noreply@users.noreply.github.com> - 1.14.19-1
- Update to v1.14.19

* Mon Apr 20 2026 Codex Automation <noreply@users.noreply.github.com> - 1.14.18-1
- Update to v1.14.18

* Sun Apr 19 2026 Codex Automation <noreply@users.noreply.github.com> - 1.14.17-1
- Update to v1.14.17

* Sat Apr 18 2026 Codex Automation <noreply@users.noreply.github.com> - 1.4.11-1
- Update to v1.4.11

* Thu Apr 16 2026 Codex Automation <noreply@users.noreply.github.com> - 1.4.7-1
- Update to v1.4.7

* Thu Apr 16 2026 Codex Automation <noreply@users.noreply.github.com> - 1.4.6-1
- Update to v1.4.6

* Wed Apr 15 2026 Codex Automation <noreply@users.noreply.github.com> - 1.4.4-1
- Update to v1.4.4

* Fri Apr 10 2026 Codex Automation <noreply@users.noreply.github.com> - 1.4.3-1
- Update to v1.4.3

* Wed Apr 08 2026 Codex Automation <noreply@users.noreply.github.com> - 1.4.0-1
- Update to v1.4.0

* Tue Apr 07 2026 Codex Automation <noreply@users.noreply.github.com> - 1.3.17-1
- Initial COPR packaging for OpenCode
