%global debug_package %{nil}

Name:           wacli
Version:        0.24.0
Release:        2%{?dist}
Summary:        WhatsApp CLI for sync, search, and send

License:        MIT
URL:            https://github.com/openclaw/wacli
Source0:        %{name}-%{version}.tar.gz
Source1:        %{name}-%{version}-vendor.tar.gz

BuildRequires:  gcc
# The vendored go.mod ships `go 1.26.0` (deps pin it; `go mod tidy` in
# make_srpm.sh restores this even after GO_VERSION_COMPAT lowers the directive),
# so the build root needs a Go toolchain >= 1.26. On openSUSE Leap 16.0 `golang`
# is a versioned virtual Provide (go 1.25/1.26/1.27 all provide it), so a >= 1.25
# floor can resolve to Go 1.25, which is too old to build the module offline.
BuildRequires:  golang >= 1.26
ExclusiveArch:  aarch64 x86_64

%description
wacli is a command-line interface for WhatsApp built on top of the WhatsApp
Web protocol. It supports local message sync, offline search, and sending
messages from the terminal.

%prep
%autosetup -n %{name}-%{version} -a1

%build
export CGO_ENABLED=1
export CGO_CFLAGS="${CGO_CFLAGS:+${CGO_CFLAGS} }-Wno-error=missing-braces"
# The vendored go.mod keeps a `toolchain go1.27.x` line (make_srpm.sh lowers only
# the `go` directive, not the toolchain). With the default GOTOOLCHAIN=auto, a
# build root whose Go is older than that toolchain tries to download the newer Go
# toolchain over the network. COPR per-chroot builds have NO network, so that
# fails (this is what breaks openSUSE Leap 16.0, which ships Go < 1.27 and leaves
# GOTOOLCHAIN=auto). Force the installed toolchain; BuildRequires golang >= 1.26
# guarantees it satisfies the go.mod `go 1.26.0` directive.
export GOTOOLCHAIN=local
export GOFLAGS="-mod=vendor -trimpath"
export GOWORK=off
go build \
    -tags sqlite_fts5 \
    -ldflags "-X main.version=%{version}" \
    -o wacli \
    ./cmd/wacli

%install
install -Dpm0755 wacli %{buildroot}%{_bindir}/wacli

%check
%{buildroot}%{_bindir}/wacli --version >/dev/null

%files
%license LICENSE
%doc README.md
%{_bindir}/wacli

%changelog
* Thu Oct 22 2026 matt haigh <matthaigh27@gmail.com> - 0.24.0-2
- Force GOTOOLCHAIN=local so the network-less build never tries to download the
  go.mod `toolchain go1.27.x` toolchain (prevents an opensuse-leap-16.0 failure)
- Require golang >= 1.26 to match the vendored `go 1.26.0` directive

* Thu Oct 22 2026 Codex Automation <noreply@users.noreply.github.com> - 0.24.0-1
- Update to v0.24.0

* Fri Oct 16 2026 Codex Automation <noreply@users.noreply.github.com> - 0.22.0-1
- Update to v0.22.0

* Mon Oct 12 2026 Codex Automation <noreply@users.noreply.github.com> - 0.21.0-1
- Update to v0.21.0

* Thu Oct 01 2026 Codex Automation <noreply@users.noreply.github.com> - 0.20.0-1
- Update to v0.20.0

* Fri Sep 25 2026 Codex Automation <noreply@users.noreply.github.com> - 0.19.0-1
- Update to v0.19.0

* Wed Sep 23 2026 Codex Automation <noreply@users.noreply.github.com> - 0.18.3-1
- Update to v0.18.3

* Sat Sep 12 2026 Codex Automation <noreply@users.noreply.github.com> - 0.18.2-1
- Update to v0.18.2

* Tue Sep 08 2026 Codex Automation <noreply@users.noreply.github.com> - 0.18.1-1
- Update to v0.18.1

* Sun Sep 06 2026 Codex Automation <noreply@users.noreply.github.com> - 0.17.2-1
- Update to v0.17.2

* Sat Aug 15 2026 Codex Automation <noreply@users.noreply.github.com> - 0.17.1-1
- Update to v0.17.1

* Fri Aug 14 2026 Codex Automation <noreply@users.noreply.github.com> - 0.17.0-1
- Update to v0.17.0

* Thu Aug 06 2026 Codex Automation <noreply@users.noreply.github.com> - 0.16.0-1
- Update to v0.16.0

* Mon Aug 03 2026 Codex Automation <noreply@users.noreply.github.com> - 0.15.2-1
- Update to v0.15.2

* Fri Jul 24 2026 Codex Automation <noreply@users.noreply.github.com> - 0.15.0-1
- Update to v0.15.0

* Mon Jul 20 2026 Codex Automation <noreply@users.noreply.github.com> - 0.14.0-1
- Update to v0.14.0

* Sat Jul 18 2026 Codex Automation <noreply@users.noreply.github.com> - 0.13.0-1
- Update to v0.13.0

* Tue Jul 07 2026 Codex Automation <noreply@users.noreply.github.com> - 0.12.0-1
- Update to v0.12.0

* Fri Jul 03 2026 Codex Automation <noreply@users.noreply.github.com> - 0.11.2-1
- Update to v0.11.2

* Thu Jun 11 2026 Codex Automation <noreply@users.noreply.github.com> - 0.11.1-1
- Update to v0.11.1

* Sat May 23 2026 Codex Automation <noreply@users.noreply.github.com> - 0.11.0-1
- Update to v0.11.0

* Thu May 21 2026 Codex Automation <noreply@users.noreply.github.com> - 0.10.0-1
- Update to v0.10.0

* Mon May 18 2026 Codex Automation <noreply@users.noreply.github.com> - 0.9.2-1
- Update to v0.9.2

* Sat May 16 2026 Codex Automation <noreply@users.noreply.github.com> - 0.9.1-1
- Update to v0.9.1

* Fri May 08 2026 Codex Automation <noreply@users.noreply.github.com> - 0.8.1-1
- Update to v0.8.1

* Thu May 07 2026 Codex Automation <noreply@users.noreply.github.com> - 0.8.0-1
- Update to v0.8.0

* Thu Apr 16 2026 Codex Automation <noreply@users.noreply.github.com> - 0.6.0-1
- Initial COPR packaging for wacli
