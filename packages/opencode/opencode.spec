Name:           opencode
Version:        1.3.17
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
* Tue Apr 07 2026 Codex Automation <noreply@users.noreply.github.com> - 1.3.17-1
- Initial COPR packaging for OpenCode
