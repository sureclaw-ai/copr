%global debug_package %{nil}

Name:           gogcli
Version:        0.46.0
Release:        2%{?dist}
Summary:        Google Workspace CLI for the terminal

License:        MIT
URL:            https://github.com/openclaw/gogcli
Source0:        %{name}-%{version}.tar.gz
Source1:        %{name}-%{version}-vendor.tar.gz

# The vendored go.mod ships `go 1.26.0` (many cloud.google.com/go/* deps pin it;
# `go mod tidy` in make_srpm.sh restores this even after GO_VERSION_COMPAT lowers
# the directive), so the build needs a Go toolchain >= 1.26 present in the build
# root. On openSUSE Leap 16.0 `golang` is a versioned virtual Provide (go 1.25,
# 1.26, 1.27 all provide it), so a >= 1.25 floor can resolve to Go 1.25, which is
# too old for the `go 1.26.0` directive and cannot build offline.
BuildRequires:  golang >= 1.26
ExclusiveArch:  aarch64 x86_64

%description
gogcli is a script-friendly CLI for Gmail, Calendar, Drive, Contacts, and
other Google Workspace services.

%prep
%autosetup -n %{name}-%{version} -a1

%build
export CGO_ENABLED=0
# Azure Linux ships the Microsoft build of Go, which defaults to
# GOEXPERIMENT=systemcrypto. That crypto backend requires CGO on Linux and
# breaks our CGO_ENABLED=0 build, so opt out. Harmless on upstream Go (Fedora),
# which ignores this Microsoft-specific variable.
export MS_GO_NOSYSTEMCRYPTO=1
# The vendored go.mod keeps a `toolchain go1.27.x` line (make_srpm.sh lowers only
# the `go` directive, not the toolchain). With the default GOTOOLCHAIN=auto, a
# build root whose Go is older than that toolchain tries to download the newer Go
# toolchain over the network. COPR per-chroot builds have NO network, so that
# fails. openSUSE Leap 16.0 ships Go < 1.27 while leaving GOTOOLCHAIN=auto, which
# is why only the opensuse-leap chroots broke (Fedora/RHEL/Azure/etc. either ship
# a Go that already satisfies the toolchain or pin GOTOOLCHAIN=local themselves).
# Force the installed toolchain and never attempt a download; BuildRequires
# golang >= 1.26 guarantees it satisfies the go.mod `go 1.26.0` directive.
export GOTOOLCHAIN=local
export GOFLAGS="-mod=vendor -trimpath"
VERSION="v%{version}"
COMMIT="$(tr -d '\n' < .copr-commit)"
DATE="$(tr -d '\n' < .copr-date)"
go build \
    -ldflags "\
        -X github.com/steipete/gogcli/internal/cmd.version=${VERSION} \
        -X github.com/steipete/gogcli/internal/cmd.commit=${COMMIT} \
        -X github.com/steipete/gogcli/internal/cmd.date=${DATE}" \
    -o gog \
    ./cmd/gog

%install
install -Dpm0755 gog %{buildroot}%{_bindir}/gog

%check
%{buildroot}%{_bindir}/gog version >/dev/null

%files
%license LICENSE
%doc README.md
%{_bindir}/gog

%changelog
* Thu Oct 22 2026 matt haigh <matthaigh27@gmail.com> - 0.46.0-2
- Force GOTOOLCHAIN=local so the network-less build never tries to download the
  go.mod `toolchain go1.27.x` toolchain (fixes opensuse-leap-16.0 build failure)
- Require golang >= 1.26 to match the vendored `go 1.26.0` directive

* Thu Oct 22 2026 Codex Automation <noreply@users.noreply.github.com> - 0.46.0-1
- Update to v0.46.0

* Fri Oct 16 2026 Codex Automation <noreply@users.noreply.github.com> - 0.45.0-1
- Update to v0.45.0

* Mon Oct 12 2026 Codex Automation <noreply@users.noreply.github.com> - 0.44.0-1
- Update to v0.44.0

* Thu Oct 01 2026 Codex Automation <noreply@users.noreply.github.com> - 0.43.0-1
- Update to v0.43.0

* Sat Sep 26 2026 Codex Automation <noreply@users.noreply.github.com> - 0.42.0-1
- Update to v0.42.0

* Wed Sep 23 2026 Codex Automation <noreply@users.noreply.github.com> - 0.41.0-1
- Update to v0.41.0

* Sat Sep 12 2026 Codex Automation <noreply@users.noreply.github.com> - 0.40.0-1
- Update to v0.40.0

* Sun Sep 06 2026 Codex Automation <noreply@users.noreply.github.com> - 0.39.1-1
- Update to v0.39.1

* Fri Sep 04 2026 Codex Automation <noreply@users.noreply.github.com> - 0.39.0-1
- Update to v0.39.0

* Thu Sep 03 2026 Codex Automation <noreply@users.noreply.github.com> - 0.38.3-1
- Update to v0.38.3

* Fri Aug 28 2026 Codex Automation <noreply@users.noreply.github.com> - 0.38.1-1
- Update to v0.38.1

* Wed Aug 26 2026 Codex Automation <noreply@users.noreply.github.com> - 0.38.0-1
- Update to v0.38.0

* Sat Aug 15 2026 Codex Automation <noreply@users.noreply.github.com> - 0.37.0-1
- Update to v0.37.0

* Fri Aug 14 2026 Codex Automation <noreply@users.noreply.github.com> - 0.36.0-1
- Update to v0.36.0

* Mon Aug 10 2026 Codex Automation <noreply@users.noreply.github.com> - 0.35.0-1
- Update to v0.35.0

* Mon Aug 03 2026 Codex Automation <noreply@users.noreply.github.com> - 0.34.2-1
- Update to v0.34.2

* Fri Jul 17 2026 Codex Automation <noreply@users.noreply.github.com> - 0.34.1-1
- Update to v0.34.1

* Sun Jul 12 2026 Codex Automation <noreply@users.noreply.github.com> - 0.34.0-1
- Update to v0.34.0

* Tue Jul 07 2026 Codex Automation <noreply@users.noreply.github.com> - 0.33.0-1
- Update to v0.33.0

* Sat Jul 04 2026 Codex Automation <noreply@users.noreply.github.com> - 0.32.0-1
- Update to v0.32.0

* Sat Jun 27 2026 Codex Automation <noreply@users.noreply.github.com> - 0.31.1-1
- Update to v0.31.1

* Thu Jun 25 2026 Codex Automation <noreply@users.noreply.github.com> - 0.31.0-1
- Update to v0.31.0

* Mon Jun 22 2026 Codex Automation <noreply@users.noreply.github.com> - 0.30.0-1
- Update to v0.30.0

* Sat Jun 20 2026 Codex Automation <noreply@users.noreply.github.com> - 0.29.0-1
- Update to v0.29.0

* Tue Jun 16 2026 Codex Automation <noreply@users.noreply.github.com> - 0.28.0-1
- Update to v0.28.0

* Mon Jun 15 2026 Codex Automation <noreply@users.noreply.github.com> - 0.27.0-1
- Update to v0.27.0

* Sun Jun 14 2026 Codex Automation <noreply@users.noreply.github.com> - 0.26.0-1
- Update to v0.26.0

* Fri Jun 12 2026 Codex Automation <noreply@users.noreply.github.com> - 0.25.0-1
- Update to v0.25.0

* Fri Jun 12 2026 Codex Automation <noreply@users.noreply.github.com> - 0.24.0-1
- Update to v0.24.0

* Tue Jun 09 2026 Codex Automation <noreply@users.noreply.github.com> - 0.23.0-1
- Update to v0.23.0

* Mon Jun 08 2026 Codex Automation <noreply@users.noreply.github.com> - 0.22.0-1
- Update to v0.22.0

* Tue Jun 02 2026 Codex Automation <noreply@users.noreply.github.com> - 0.21.0-1
- Update to v0.21.0

* Sun May 31 2026 Codex Automation <noreply@users.noreply.github.com> - 0.20.0-1
- Update to v0.20.0

* Fri May 29 2026 matt haigh <matthaigh27@gmail.com> - 0.19.0-2
- Opt out of Microsoft Go's systemcrypto GOEXPERIMENT (MS_GO_NOSYSTEMCRYPTO=1)
  so the CGO_ENABLED=0 build succeeds on Azure Linux

* Sat May 23 2026 Codex Automation <noreply@users.noreply.github.com> - 0.19.0-1
- Update to v0.19.0

* Fri May 22 2026 Codex Automation <noreply@users.noreply.github.com> - 0.18.0-1
- Update to v0.18.0

* Sat May 16 2026 Codex Automation <noreply@users.noreply.github.com> - 0.17.0-1
- Update to v0.17.0

* Mon May 11 2026 Codex Automation <noreply@users.noreply.github.com> - 0.16.0-1
- Update to v0.16.0

* Wed May 06 2026 Codex Automation <noreply@users.noreply.github.com> - 0.15.0-1
- Update to v0.15.0

* Tue Apr 28 2026 Codex Automation <noreply@users.noreply.github.com> - 0.14.0-1
- Update to v0.14.0

* Tue Apr 21 2026 Codex Automation <noreply@users.noreply.github.com> - 0.13.0-1
- Update to v0.13.0

* Tue Apr 07 2026 Codex Automation <noreply@users.noreply.github.com> - 0.12.0-1
- Initial COPR packaging for gogcli
