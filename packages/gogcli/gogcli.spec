%global debug_package %{nil}

Name:           gogcli
Version:        0.23.0
Release:        1%{?dist}
Summary:        Google Workspace CLI for the terminal

License:        MIT
URL:            https://github.com/openclaw/gogcli
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
# Azure Linux ships the Microsoft build of Go, which defaults to
# GOEXPERIMENT=systemcrypto. That crypto backend requires CGO on Linux and
# breaks our CGO_ENABLED=0 build, so opt out. Harmless on upstream Go (Fedora),
# which ignores this Microsoft-specific variable.
export MS_GO_NOSYSTEMCRYPTO=1
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
