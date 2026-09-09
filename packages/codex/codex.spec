%global debug_package %{nil}

Name:           codex
Version:        0.152.0
Release:        2%{?dist}
Version:        0.152.1
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
%endif
%ifarch aarch64
tar -xzf %{SOURCE1}
%endif

%install
# The upstream codex-package archive also bundles rg, bwrap and zsh under
# codex-path/ and codex-resources/; those are provided by the ripgrep and
# bubblewrap runtime dependencies (and the system zsh) instead.
install -Dpm0755 bin/codex %{buildroot}%{_bindir}/codex
install -Dpm0755 bin/codex-code-mode-host %{buildroot}%{_bindir}/codex-code-mode-host

%check
%{buildroot}%{_bindir}/codex --version >/dev/null

%files
%license LICENSE NOTICE
%doc README.md
%{_bindir}/codex
%{_bindir}/codex-code-mode-host

%changelog
* Tue Sep 01 2026 David <david@example.com> - 0.152.0-2
- Switch to the upstream codex-package release archives and ship
  codex-code-mode-host next to codex; without it code mode fails with
  "failed to spawn code-mode host" (openai/codex#31906)
* Wed Sep 02 2026 Codex Automation <noreply@users.noreply.github.com> - 0.152.1-1
- Update to v0.152.1

* Tue Sep 01 2026 Codex Automation <noreply@users.noreply.github.com> - 0.152.0-1
- Update to v0.152.0

* Sun Aug 30 2026 Codex Automation <noreply@users.noreply.github.com> - 0.151.0-1
- Update to v0.151.0

* Fri Aug 28 2026 Codex Automation <noreply@users.noreply.github.com> - 0.150.1-1
- Update to v0.150.1

* Mon Aug 24 2026 Codex Automation <noreply@users.noreply.github.com> - 0.149.1-1
- Update to v0.149.1

* Fri Aug 21 2026 Codex Automation <noreply@users.noreply.github.com> - 0.149.0-1
- Update to v0.149.0

* Wed Aug 19 2026 Codex Automation <noreply@users.noreply.github.com> - 0.148.0-1
- Update to v0.148.0

* Fri Aug 07 2026 Codex Automation <noreply@users.noreply.github.com> - 0.147.0-1
- Update to v0.147.0

* Thu Aug 06 2026 Codex Automation <noreply@users.noreply.github.com> - 0.146.1-1
- Update to v0.146.1

* Wed Jul 29 2026 Codex Automation <noreply@users.noreply.github.com> - 0.146.0-1
- Update to v0.146.0

* Wed Jul 22 2026 Codex Automation <noreply@users.noreply.github.com> - 0.145.0-1
- Update to v0.145.0

* Sun Jul 19 2026 Codex Automation <noreply@users.noreply.github.com> - 0.144.6-1
- Update to v0.144.6

* Thu Jul 16 2026 Codex Automation <noreply@users.noreply.github.com> - 0.144.5-1
- Update to v0.144.5

* Wed Jul 15 2026 Codex Automation <noreply@users.noreply.github.com> - 0.144.4-1
- Update to v0.144.4

* Tue Jul 14 2026 Codex Automation <noreply@users.noreply.github.com> - 0.144.3-1
- Update to v0.144.3

* Fri Jul 10 2026 Codex Automation <noreply@users.noreply.github.com> - 0.144.1-1
- Update to v0.144.1

* Wed Jul 08 2026 Codex Automation <noreply@users.noreply.github.com> - 0.143.0-1
- Update to v0.143.0

* Wed Jul 01 2026 Codex Automation <noreply@users.noreply.github.com> - 0.142.5-1
- Update to v0.142.5

* Mon Jun 29 2026 Codex Automation <noreply@users.noreply.github.com> - 0.142.4-1
- Update to v0.142.4

* Sat Jun 27 2026 Codex Automation <noreply@users.noreply.github.com> - 0.142.3-1
- Update to v0.142.3

* Fri Jun 26 2026 Codex Automation <noreply@users.noreply.github.com> - 0.142.2-1
- Update to v0.142.2

* Thu Jun 25 2026 Codex Automation <noreply@users.noreply.github.com> - 0.142.1-1
- Update to v0.142.1

* Tue Jun 23 2026 Codex Automation <noreply@users.noreply.github.com> - 0.142.0-1
- Update to v0.142.0

* Thu Jun 18 2026 Codex Automation <noreply@users.noreply.github.com> - 0.141.0-1
- Update to v0.141.0

* Tue Jun 16 2026 Codex Automation <noreply@users.noreply.github.com> - 0.140.0-1
- Update to v0.140.0

* Wed Jun 10 2026 Codex Automation <noreply@users.noreply.github.com> - 0.139.0-1
- Update to v0.139.0

* Tue Jun 09 2026 Codex Automation <noreply@users.noreply.github.com> - 0.138.0-1
- Update to v0.138.0

* Thu Jun 04 2026 Codex Automation <noreply@users.noreply.github.com> - 0.137.0-1
- Update to v0.137.0

* Tue Jun 02 2026 Codex Automation <noreply@users.noreply.github.com> - 0.136.0-1
- Update to v0.136.0

* Fri May 29 2026 Codex Automation <noreply@users.noreply.github.com> - 0.135.0-1
- Update to v0.135.0

* Wed May 27 2026 Codex Automation <noreply@users.noreply.github.com> - 0.134.0-1
- Update to v0.134.0

* Fri May 22 2026 Codex Automation <noreply@users.noreply.github.com> - 0.133.0-1
- Update to v0.133.0

* Wed May 20 2026 Codex Automation <noreply@users.noreply.github.com> - 0.132.0-1
- Update to v0.132.0

* Tue May 19 2026 Codex Automation <noreply@users.noreply.github.com> - 0.131.0-1
- Update to v0.131.0

* Sat May 09 2026 Codex Automation <noreply@users.noreply.github.com> - 0.130.0-1
- Update to v0.130.0

* Fri May 08 2026 Codex Automation <noreply@users.noreply.github.com> - 0.129.0-1
- Update to v0.129.0

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
