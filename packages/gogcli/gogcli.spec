%global debug_package %{nil}

Name:           gogcli
Version:        0.14.0
Release:        1%{?dist}
Summary:        Google Workspace CLI for the terminal

License:        MIT
URL:            https://github.com/steipete/gogcli
Source0:        %{name}-%{version}.tar.gz
Source1:        %{name}-%{version}-vendor.tar.gz

BuildRequires:  golang >= 1.25
ExclusiveArch:  aarch64 x86_64

%description
gogcli is a script-friendly CLI for Gmail, Calendar, Drive, Contacts, and
other Google Workspace services.

%prep
%autosetup -n %{name}-%{version} -a1

%build
export CGO_ENABLED=0
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
* Tue Apr 28 2026 Codex Automation <noreply@users.noreply.github.com> - 0.14.0-1
- Update to v0.14.0

* Tue Apr 21 2026 Codex Automation <noreply@users.noreply.github.com> - 0.13.0-1
- Update to v0.13.0

* Tue Apr 07 2026 Codex Automation <noreply@users.noreply.github.com> - 0.12.0-1
- Initial COPR packaging for gogcli
