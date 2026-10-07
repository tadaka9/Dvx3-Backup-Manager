Name:           dvx3
Version:        %{dvx3_version}
Release:        1%{?dist}
Summary:        Local encrypted backup manager
License:        MIT
URL:            https://github.com/tadaka9/Dvx3-Backup-Manager
Source0:        dvx3-root.tar.gz
Requires:       glib2, json-glib, libsodium, qt6-qtbase, tar
%description
DVX3 creates authenticated, compressed backup archives.
%prep
%setup -q -c -T
tar -xzf %{SOURCE0}
%install
mkdir -p %{buildroot}
cp -a . %{buildroot}/
%files
/usr/bin/dvx3
/usr/bin/backup-manager
/usr/bin/dvx3-backup-manager
/usr/lib/libdvx3.so
/usr/share/applications/io.github.tadaka9.dvx3.desktop
/usr/share/icons/hicolor/512x512/apps/io.github.tadaka9.dvx3.png
/usr/share/metainfo/io.github.tadaka9.dvx3.metainfo.xml
/usr/share/doc/dvx3
%changelog
* Wed Oct 07 2026 DVX3 Project <dvx3@dvx3.local> - 1.0.0-1
- Native package
