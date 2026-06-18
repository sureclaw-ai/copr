%global debug_package %{nil}

Name:           opencode
Version:        1.17.8
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
* Thu Jun 18 2026 Codex Automation <noreply@users.noreply.github.com> - 1.17.8-1
- Update to v1.17.8

* Mon Jun 15 2026 Codex Automation <noreply@users.noreply.github.com> - 1.17.7-1
- Update to v1.17.7

* Sun Jun 14 2026 Codex Automation <noreply@users.noreply.github.com> - 1.17.6-1
- Update to v1.17.6

* Fri Jun 12 2026 Codex Automation <noreply@users.noreply.github.com> - 1.17.4-1
- Update to v1.17.4

* Thu Jun 11 2026 Codex Automation <noreply@users.noreply.github.com> - 1.17.3-1
- Update to v1.17.3

* Wed Jun 10 2026 Codex Automation <noreply@users.noreply.github.com> - 1.17.1-1
- Update to v1.17.1

* Wed Jun 10 2026 Codex Automation <noreply@users.noreply.github.com> - 1.17.0-1
- Update to v1.17.0

* Sat Jun 06 2026 Codex Automation <noreply@users.noreply.github.com> - 1.16.2-1
- Update to v1.16.2

* Fri Jun 05 2026 Codex Automation <noreply@users.noreply.github.com> - 1.16.0-1
- Update to v1.16.0

* Sun May 31 2026 Codex Automation <noreply@users.noreply.github.com> - 1.15.13-1
- Update to v1.15.13

* Fri May 29 2026 Codex Automation <noreply@users.noreply.github.com> - 1.15.12-1
- Update to v1.15.12

* Wed May 27 2026 Codex Automation <noreply@users.noreply.github.com> - 1.15.11-1
- Update to v1.15.11

* Sat May 23 2026 Codex Automation <noreply@users.noreply.github.com> - 1.15.10-1
- Update to v1.15.10

* Fri May 22 2026 Codex Automation <noreply@users.noreply.github.com> - 1.15.7-1
- Update to v1.15.7

* Thu May 21 2026 Codex Automation <noreply@users.noreply.github.com> - 1.15.6-1
- Update to v1.15.6

* Tue May 19 2026 Codex Automation <noreply@users.noreply.github.com> - 1.15.5-1
- Update to v1.15.5

* Mon May 18 2026 Codex Automation <noreply@users.noreply.github.com> - 1.15.4-1
- Update to v1.15.4

* Sun May 17 2026 Codex Automation <noreply@users.noreply.github.com> - 1.15.3-1
- Update to v1.15.3

* Fri May 15 2026 Codex Automation <noreply@users.noreply.github.com> - 1.15.0-1
- Update to v1.15.0

* Thu May 14 2026 Codex Automation <noreply@users.noreply.github.com> - 1.14.50-1
- Update to v1.14.50

* Mon May 11 2026 Codex Automation <noreply@users.noreply.github.com> - 1.14.48-1
- Update to v1.14.48

* Sun May 10 2026 Codex Automation <noreply@users.noreply.github.com> - 1.14.46-1
- Update to v1.14.46

* Fri May 08 2026 Codex Automation <noreply@users.noreply.github.com> - 1.14.41-1
- Update to v1.14.41

* Thu May 07 2026 Codex Automation <noreply@users.noreply.github.com> - 1.14.40-1
- Update to v1.14.40

* Wed May 06 2026 Codex Automation <noreply@users.noreply.github.com> - 1.14.39-1
- Update to v1.14.39

* Tue May 05 2026 Codex Automation <noreply@users.noreply.github.com> - 1.14.35-1
- Update to v1.14.35

* Sun May 03 2026 Codex Automation <noreply@users.noreply.github.com> - 1.14.33-1
- Update to v1.14.33

* Sat May 02 2026 Codex Automation <noreply@users.noreply.github.com> - 1.14.31-1
- Update to v1.14.31

* Thu Apr 30 2026 Codex Automation <noreply@users.noreply.github.com> - 1.14.30-1
- Update to v1.14.30

* Wed Apr 29 2026 Codex Automation <noreply@users.noreply.github.com> - 1.14.29-1
- Update to v1.14.29

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
