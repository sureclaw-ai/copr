%global debug_package %{nil}

Name:           wacli
Version:        0.13.0
Release:        2%{?dist}
Summary:        WhatsApp CLI for sync, search, and send

License:        MIT
URL:            https://github.com/openclaw/wacli
Source0:        %{name}-%{version}.tar.gz
Source1:        %{name}-%{version}-vendor.tar.gz

BuildRequires:  gcc
BuildRequires:  golang >= 1.25
ExclusiveArch:  aarch64 x86_64

%description
wacli is a command-line interface for WhatsApp built on top of the WhatsApp
Web protocol. It supports local message sync, offline search, and sending
messages from the terminal.

%prep
%autosetup -n %{name}-%{version} -a1
# Some targets (openSUSE Leap 15.6, Amazon Linux 2023) ship a Go patch release
# older than the one upstream pins in the go.mod "go" directive, so the build
# fails with "go.mod requires go >= X (running go Y; GOTOOLCHAIN=local)". Go
# patch releases add no language features, so relax the directive to its minor
# version (and drop any toolchain pin) to let the distro's local Go build
# without a GOTOOLCHAIN download. All vendored dependencies require <= go 1.24.
sed -i -E 's/^go ([0-9]+\.[0-9]+)\.[0-9]+$/go \1/' go.mod
sed -i -E '/^toolchain /d' go.mod

%build
export CGO_ENABLED=1
export CGO_CFLAGS="${CGO_CFLAGS:+${CGO_CFLAGS} }-Wno-error=missing-braces"
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
* Sun Jul 19 2026 matt haigh <matthaigh27@gmail.com> - 0.13.0-2
- Relax the go.mod Go patch pin at build time so targets shipping an older Go
  (openSUSE Leap 15.6, Amazon Linux 2023) build without a toolchain download

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
