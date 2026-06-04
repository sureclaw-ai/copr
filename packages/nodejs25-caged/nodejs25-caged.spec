%global debug_package %{nil}
%global nodejs_major 25
%global npm_version 11.12.1

Name:           nodejs25-caged
Version:        25.9.0
Release:        1%{?dist}
Summary:        Node.js 25 built with V8 pointer compression

License:        MIT
URL:            https://nodejs.org/
Source0:        https://nodejs.org/dist/v%{version}/node-v%{version}.tar.xz
Source1:        https://nodejs.org/dist/v%{version}/SHASUMS256.txt

BuildRequires:  clang
BuildRequires:  findutils
BuildRequires:  gcc-c++
BuildRequires:  libatomic
BuildRequires:  make
BuildRequires:  python3
BuildRequires:  tar
BuildRequires:  xz

Provides:       node = %{version}-%{release}
Provides:       nodejs = %{version}-%{release}
Provides:       nodejs%{nodejs_major} = %{version}-%{release}
Provides:       nodejs-npm = %{npm_version}
Provides:       nodejs-npx = %{npm_version}
Provides:       nodejs%{nodejs_major}-npm = %{npm_version}
Provides:       nodejs%{nodejs_major}-npx = %{npm_version}
Provides:       npm = %{npm_version}
Provides:       npx = %{npm_version}

ExclusiveArch:  aarch64 x86_64

%description
Node.js 25 built from the official source tarball with V8 pointer compression
enabled.

%prep
%setup -q -n node-v%{version}

%build
export CC=clang
export CXX=clang++
%{?set_build_flags}
./configure \
    --prefix=%{_prefix} \
    --experimental-enable-pointer-compression
%make_build

%install
%make_install PREFIX=%{_prefix}

%check
export PATH="%{buildroot}%{_bindir}:$PATH"
%{buildroot}%{_bindir}/node --version | grep -qx "v%{version}"
%{buildroot}%{_bindir}/node -p "process.config.variables.v8_enable_pointer_compression" | grep -qx "1"
%{buildroot}%{_bindir}/npm --version | grep -qx "%{npm_version}"
%{buildroot}%{_bindir}/npx --version >/dev/null

%files
%license LICENSE
%doc README.md
%{_bindir}/node
%{_bindir}/npm
%{_bindir}/npx
%{_includedir}/node
%{_prefix}/lib/node_modules/npm
%{_datadir}/doc/node
%{_mandir}/man1/node.1*

%changelog
* Thu Jun 04 2026 matt haigh <matthaigh27@gmail.com> - 25.9.0-1
- Initial COPR packaging for Node.js 25 with V8 pointer compression
