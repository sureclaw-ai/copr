%global debug_package %{nil}

Name:           wacli
Version:        0.15.0
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
* Fri Jul 31 2026 Copr Maintenance <noreply@users.noreply.github.com> - 0.15.0-2
- Rebuild to recover the opensuse-leap-16.0 chroots; the 0.15.0-1 build failed
  only there because the buildroot's openSUSE package-signing key had expired
  (a transient distribution-gpg-keys issue on the Copr builders, since fixed).
  No source or packaging change; golang >= 1.25 resolves on Leap 16.0 via go1.25.

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
