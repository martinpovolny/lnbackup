# Generated from lnbackup-2.3.gem by gem2rpm -*- rpm-spec -*-
%global gem_name lnbackup
%global rubyabi 1.9.1

Summary: Hardlink backup system for hard drives
Name: rubygem-%{gem_name}
Version: 2.3
Release: 1%{?dist}
Group: Development/Languages
License: 
URL: https://github.com/martinpovolny/lnbackup
Source0: %{gem_name}-%{version}.gem
Requires: ruby(abi) = %{rubyabi}
Requires: ruby(rubygems) 
Requires: rubygem(sys-filesystem) 
Requires: rubygem(acl) 
BuildRequires: ruby(abi) = %{rubyabi}
BuildRequires: rubygems-devel 
BuildRequires: ruby 
BuildArch: noarch
Provides: rubygem(%{gem_name}) = %{version}

%description
Lnbackup is a hardlink backup system for hard drives.
Lnbackup operates in a way similar to the '--link-dest' switch in rsync.
It creates incremental backups using hardlinks so that each backup seems like
a
full backup. Additionaly it can make (using hardlinks) bootable mirror from
the
latest backup.
Obviously the target filesystem of lnbackup needs to support hardlinks.
It's run on ~200 servers for several years and it is considered stable.
Read the man page for more information.


%package doc
Summary: Documentation for %{name}
Group: Documentation
Requires: %{name} = %{version}-%{release}
BuildArch: noarch

%description doc
Documentation for %{name}

%prep
%setup -q -c -T
mkdir -p .%{gem_dir}
gem install --local --install-dir .%{gem_dir} \
            --bindir .%{_bindir} \
            --force %{SOURCE0}

%build

%install
mkdir -p %{buildroot}%{gem_dir}
cp -pa .%{gem_dir}/* \
        %{buildroot}%{gem_dir}/


mkdir -p %{buildroot}%{_bindir}
cp -pa .%{_bindir}/* \
        %{buildroot}%{_bindir}/

find %{buildroot}%{gem_instdir}/bin -type f | xargs chmod a+x

%files
%dir %{gem_instdir}
%{_bindir}/lnbackup-stat
%{_bindir}/lnbackup
%{_bindir}/lnbackup-umount
%{_bindir}/lnbackup-mount
%{_bindir}/pc_backup
%{_bindir}/sql_backup.sh
%{gem_instdir}/bin
%{gem_libdir}
%exclude %{gem_cache}
%{gem_spec}

%files doc
%doc %{gem_docdir}

%changelog
* Mon Feb 11 2013 Martin Povolny - 2.3-1
- Initial package
