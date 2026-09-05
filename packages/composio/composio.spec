%global debug_package %{nil}

# The `composio` launcher is a Bun single-file executable: its application
# payload is appended after the ELF image. RPM's default post-install
# processing would strip that trailer and break the binary, so disable all
# automatic post-processing and ship the release tree byte-for-byte.
%global __os_install_post %{nil}

# The release tree bundles helper scripts and cross-platform helper binaries
# (ACP adapters, subagent services). Do not let RPM derive provides/requires
# from them.
%global __provides_exclude_from ^%{_prefix}/lib/composio/.*$
%global __requires_exclude_from ^%{_prefix}/lib/composio/.*$

Name:           composio
Version:        0.4.1
Release:        1%{?dist}
Summary:        Composio CLI for connecting AI agents to external tools

License:        MIT
URL:            https://github.com/ComposioHQ/composio
Source0:        %{name}-%{version}-x86_64.zip
Source1:        %{name}-%{version}-aarch64.zip
Source2:        %{name}-%{version}-docs.tar.gz

BuildRequires:  unzip
ExclusiveArch:  aarch64 x86_64

%description
Composio is a command-line tool for connecting AI agents and LLMs to external
applications and tools.

%prep
%setup -q -T -c -n %{name}-%{version}
tar -xzf %{SOURCE2}
%ifarch x86_64
unzip -q %{SOURCE0}
%endif
%ifarch aarch64
unzip -q %{SOURCE1}
%endif

%install
install -d %{buildroot}%{_prefix}/lib
%ifarch x86_64
cp -a composio-linux-x64 %{buildroot}%{_prefix}/lib/composio
%endif
%ifarch aarch64
cp -a composio-linux-aarch64 %{buildroot}%{_prefix}/lib/composio
%endif
chmod 0755 %{buildroot}%{_prefix}/lib/composio/composio
# The bundled codex ACP helper ships a `codex-acp` binary for every platform,
# but at runtime the CLI selects only the one matching the host:
#   ACP_BINARY_TARGETS.find(c => c.platform === process.platform
#                                && c.arch === process.arch)
# Drop the binaries that can never execute on this build's target arch; this
# roughly halves the installed size.
%ifarch x86_64
rm -rf %{buildroot}%{_prefix}/lib/composio/acp-adapters/codex/darwin-x64 \
       %{buildroot}%{_prefix}/lib/composio/acp-adapters/codex/darwin-arm64 \
       %{buildroot}%{_prefix}/lib/composio/acp-adapters/codex/linux-arm64
%endif
%ifarch aarch64
rm -rf %{buildroot}%{_prefix}/lib/composio/acp-adapters/codex/darwin-x64 \
       %{buildroot}%{_prefix}/lib/composio/acp-adapters/codex/darwin-arm64 \
       %{buildroot}%{_prefix}/lib/composio/acp-adapters/codex/linux-x64
%endif
install -d %{buildroot}%{_bindir}
ln -s %{_prefix}/lib/composio/composio %{buildroot}%{_bindir}/composio

%check
# Run the real launcher directly: the %{_bindir} symlink points at the final
# install path, which does not exist inside the build root yet.
%{buildroot}%{_prefix}/lib/composio/composio --version >/dev/null

%files
%license LICENSE
%doc README.md
%{_bindir}/composio
%{_prefix}/lib/composio/

%changelog
* Sat Sep 05 2026 Codex Automation <noreply@users.noreply.github.com> - 0.4.1-1
- Update to v0.4.1

* Mon Aug 24 2026 Codex Automation <noreply@users.noreply.github.com> - 0.4.0-1
- Update to v0.4.0

* Wed Aug 12 2026 Codex Automation <noreply@users.noreply.github.com> - 0.3.3-1
- Update to v0.3.3

* Thu Aug 06 2026 Codex Automation <noreply@users.noreply.github.com> - 0.3.2-1
- Update to v0.3.2

* Fri Jul 31 2026 Codex Automation <noreply@users.noreply.github.com> - 0.3.1-1
- Update to v0.3.1

* Thu Jul 16 2026 Codex Automation <noreply@users.noreply.github.com> - 0.2.32-1
- Update to v0.2.32

* Mon Jun 29 2026 Codex Automation <noreply@users.noreply.github.com> - 0.2.31-1
- Initial COPR packaging for Composio CLI
