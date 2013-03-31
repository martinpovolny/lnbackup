%define buildroot %{_tmppath}/%{name}-root
Summary: Filesystem library for ruby
Name: ruby-filesystem
Version: 2.4
Release: 1%{?dist}
Group: Development/Languages
License: ruby
Source: http://fake/ruby-filesystem_0.5.1.orig.tar.gz
Requires: ruby
BuildRequires: ruby
BuildRequires: ruby-devel
Provides: ruby-filesystem = %{version}
BuildRoot: %{buildroot}

%description
ruby filesystem

%prep
#%setup 
rm -rf ruby-filesystem-0.5.1
zcat $RPM_SOURCE_DIR/ruby-filesystem_0.5.1.orig.tar.gz | tar -xvf -
mv filesystem-0.5.1/ ruby-filesystem-0.5.1/

%build
cd ruby-filesystem-0.5.1
ruby extconf.rb
make

%install
cd ruby-filesystem-0.5.1
make install DESTDIR=%{buildroot}

%files
#/usr/lib/ruby/1.8/filesystem.so
/usr/lib64/ruby/site_ruby/1.8/x86_64-linux/filesystem.so

%changelog
* Mon Feb 22 2013 Martin Povolny - 0.5-1
- Initial package
