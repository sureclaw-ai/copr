%global debug_package %{nil}

Name:           ollama
Version:        0.20.6
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
* Mon Apr 13 2026 Codex Automation <noreply@users.noreply.github.com> - 0.20.6-1
- Update to v0.20.6

* Sun Apr 12 2026 Codex Automation <noreply@users.noreply.github.com> - 0.20.5-1
- Initial COPR packaging for Ollama
