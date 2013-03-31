%define buildroot %{_tmppath}/%{name}-root
Summary: Hardlink backup system for hard drives
Name: lnbackup
Version: 2.4
Release: 1%{?dist}
Group: Development/Languages
License: ruby
URL: https://github.com/martinpovolny/lnbackup
Source: http://fake/lnbackup-2.4.tar.gz
Requires: ruby
BuildRequires: ruby
BuildArch: noarch
Provides: lnbackup = %{version}
BuildRoot: %{buildroot}

%description
Lnbackup is a hardlink backup system for hard drives.
Lnbackup operates in a way similar to the '--link-dest' switch in rsync.
It creates incremental backups using hardlinks so that each backup seems like
a full backup. Additionaly it can make (using hardlinks) bootable mirror from
the latest backup.
Obviously the target filesystem of lnbackup needs to support hardlinks.
It's run on ~200 servers for several years and it is considered stable.
Read the man page for more information.


%prep
%setup


%build


%install
mkdir -p %{buildroot}%{_bindir}/
cp bin/lnbackup-stat   %{buildroot}%{_bindir}/
cp bin/lnbackup        %{buildroot}%{_bindir}/
cp bin/lnbackup-umount %{buildroot}%{_bindir}/
cp bin/lnbackup-mount  %{buildroot}%{_bindir}/
cp bin/pc_backup       %{buildroot}%{_bindir}/
cp bin/sql_backup.sh   %{buildroot}%{_bindir}/
cp lib/lnbackup.rb %{buildroot}/usr/lib/ruby/1.8/
mkdir -p %{buildroot}/usr/lib/ruby/1.8/lnbackup/
cp lib/lnbackup/*  %{buildroot}/usr/lib/ruby/1.8/lnbackup/

find %{buildroot}%{_bindir} -type f | xargs chmod a+x


%files
%{_bindir}/lnbackup-stat
%{_bindir}/lnbackup
%{_bindir}/lnbackup-umount
%{_bindir}/lnbackup-mount
%{_bindir}/pc_backup
%{_bindir}/sql_backup.sh
/usr/lib/ruby/1.8/lnbackup.rb
%dir /usr/lib/ruby/1.8/lnbackup
/usr/lib/ruby/1.8/lnbackup/backup.rb
/usr/lib/ruby/1.8/lnbackup/freespace.rb
/usr/lib/ruby/1.8/lnbackup/util.rb
/usr/lib/ruby/1.8/lnbackup/version.rb

%changelog
* Mon Feb 11 2013 Martin Povolny - 2.4-1
- Initial package
