%global debug_package %{nil}

Name:           wacli
Version:        0.6.0
Release:        1%{?dist}
Summary:        WhatsApp CLI for sync, search, and send

License:        MIT
URL:            https://github.com/steipete/wacli
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
* Thu Apr 16 2026 Codex Automation <noreply@users.noreply.github.com> - 0.6.0-1
- Initial COPR packaging for wacli
