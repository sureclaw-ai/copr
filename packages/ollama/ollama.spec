%global debug_package %{nil}
%global __provides_exclude_from ^%{_prefix}/lib/ollama/.*$
%global __requires_exclude_from ^%{_prefix}/lib/ollama/.*$

Name:           ollama
Version:        0.22.1
Release:        1%{?dist}
Summary:        Local LLM runner and API server

License:        MIT
URL:            https://github.com/ollama/ollama
Source0:        %{name}-%{version}-x86_64.tar.zst
Source1:        %{name}-%{version}-aarch64.tar.zst
Source2:        %{name}-%{version}-docs.tar.gz

BuildRequires:  zstd
ExclusiveArch:  aarch64 x86_64

%description
Ollama runs large language models locally and exposes a command-line interface
and local API server.

%prep
%setup -q -T -c -n %{name}-%{version}
tar -xzf %{SOURCE2}
%ifarch x86_64
tar --zstd -xf %{SOURCE0}
%endif
%ifarch aarch64
tar --zstd -xf %{SOURCE1}
%endif

%install
install -Dpm0755 bin/ollama %{buildroot}%{_bindir}/ollama
install -d %{buildroot}%{_prefix}/lib
cp -a lib/ollama %{buildroot}%{_prefix}/lib/

%check
%{buildroot}%{_bindir}/ollama --version >/dev/null

%files
%license LICENSE
%doc README.md
%{_bindir}/ollama
%{_prefix}/lib/ollama/

%changelog
* Thu Apr 30 2026 Codex Automation <noreply@users.noreply.github.com> - 0.22.1-1
- Update to v0.22.1

* Wed Apr 29 2026 Codex Automation <noreply@users.noreply.github.com> - 0.22.0-1
- Update to v0.22.0

* Fri Apr 24 2026 Codex Automation <noreply@users.noreply.github.com> - 0.21.2-1
- Update to v0.21.2

* Wed Apr 22 2026 Codex Automation <noreply@users.noreply.github.com> - 0.21.1-1
- Update to v0.21.1

* Fri Apr 17 2026 Codex Automation <noreply@users.noreply.github.com> - 0.21.0-1
- Update to v0.21.0

* Tue Apr 14 2026 Codex Automation <noreply@users.noreply.github.com> - 0.20.7-1
- Update to v0.20.7

* Mon Apr 13 2026 Codex Automation <noreply@users.noreply.github.com> - 0.20.6-1
- Update to v0.20.6

* Sun Apr 12 2026 Codex Automation <noreply@users.noreply.github.com> - 0.20.5-1
- Initial COPR packaging for Ollama
