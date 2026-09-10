%global debug_package %{nil}

# Preserve the official Node.js executable exactly as published. In particular,
# do not re-strip or otherwise rewrite the prebuilt ELF during RPM post-processing.
%global __os_install_post %{nil}

Name:           nodejs-latest
Version:        26.8.2
Release:        1%{?dist}
Summary:        Latest stable Node.js release from the official binary distribution

License:        Apache-2.0 AND Artistic-2.0 AND BSD-2-Clause AND BSD-3-Clause AND BlueOak-1.0.0 AND CC-BY-3.0 AND CC0-1.0 AND ISC AND MIT AND Unicode-3.0
URL:            https://nodejs.org/
Source0:        https://nodejs.org/dist/v%{version}/node-v%{version}-linux-x64.tar.xz
Source1:        https://nodejs.org/dist/v%{version}/node-v%{version}-linux-arm64.tar.xz
Source2:        https://nodejs.org/dist/v%{version}/SHASUMS256.txt

BuildRequires:  libatomic
Requires:       libatomic

Provides:       node = %{version}-%{release}
Provides:       nodejs = %{version}-%{release}
Provides:       nodejs-npm
Provides:       nodejs-npx
Provides:       npm
Provides:       npx

# This package deliberately owns the conventional Node.js command paths and the
# complete npm installation. It therefore cannot coexist with distro Node.js/npm
# packages or the old pointer-compressed build that owns the same files.
Conflicts:      nodejs
Conflicts:      nodejs-npm
Conflicts:      nodejs25-caged
Conflicts:      nodejs-lts

ExclusiveArch:  aarch64 x86_64

%description
The latest stable Node.js Current release, repackaged without recompilation from
the official Node.js Linux binary distribution. The package includes Node.js,
npm, npx, development headers, npm's bundled modules and documentation.

%prep
%setup -q -T -c -n %{name}-%{version}
%ifarch x86_64
tar -xJf %{SOURCE0}
mv node-v%{version}-linux-x64 node-dist
%endif
%ifarch aarch64
tar -xJf %{SOURCE1}
mv node-v%{version}-linux-arm64 node-dist
%endif

%install
install -d %{buildroot}%{_prefix}
cp -a node-dist/bin node-dist/include node-dist/lib node-dist/share \
    %{buildroot}%{_prefix}/

# An archive extracted directly under /usr makes npm derive /usr as its global
# prefix. Add npm's distribution-level config hook and send administrator-managed
# global installs to /usr/local.
cat > %{buildroot}%{_prefix}/lib/node_modules/npm/npmrc <<'EOF'
globalconfig=/etc/npmrc
EOF
install -d %{buildroot}%{_sysconfdir}
cat > %{buildroot}%{_sysconfdir}/npmrc <<'EOF'
prefix=/usr/local
update-notifier=false
EOF

%check
node_bin="%{buildroot}%{_bindir}/node"
test "$("$node_bin" --version)" = "v%{version}"
PATH="%{buildroot}%{_bindir}:$PATH" \
    "%{buildroot}%{_bindir}/npm" --version >/dev/null
PATH="%{buildroot}%{_bindir}:$PATH" \
    "%{buildroot}%{_bindir}/npx" --version >/dev/null

%files
%license node-dist/LICENSE
%doc node-dist/README.md node-dist/CHANGELOG.md
%config(noreplace) %{_sysconfdir}/npmrc
%{_bindir}/*
%{_includedir}/node/
%{_prefix}/lib/node_modules/
%{_datadir}/doc/node/
%{_mandir}/man1/node.1*

%changelog
* Thu Sep 10 2026 Codex Automation <noreply@users.noreply.github.com> - 26.8.2-1
- Update to v26.8.2

* Fri Aug 28 2026 Codex Automation <noreply@users.noreply.github.com> - 26.8.1-1
- Update to v26.8.1

* Thu Aug 06 2026 Codex Automation <noreply@users.noreply.github.com> - 26.7.0-1
- Update to v26.7.0

* Tue Aug 04 2026 Codex Automation <noreply@users.noreply.github.com> - 26.6.0-1
- Update to v26.6.0

* Thu Jul 30 2026 Codex Automation <noreply@users.noreply.github.com> - 26.5.1-1
- Update to v26.5.1

* Wed Jul 15 2026 matt haigh <matthaigh27@gmail.com> - 26.5.0-1
- Initial package using official Node.js x64 and arm64 binaries
- Track the newest stable Current release across Node.js major versions
