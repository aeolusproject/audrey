%define app_root /usr/local/sbin

Name:		aeolus-audrey-startup
Version:	@VERSION@
Release:	3%{?dist}%{?extra_release}
Summary:	The Aeolus Audrey Startup Script
BuildArch:  noarch

Group:		Applications/System
License:	GPLv2+ and MIT and BSD
URL:		http://aeolusproject.org
Source0:	aeolus-audrey-startup-%{version}.tgz
BuildRoot:	%(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

Requires:       python >= 2.
Requires:       python-dmidecode


%description
The Aeolus Audrey Startup script runs on instances in a cloud at system boot and
contacts an Aeolus Config Server to retrieve post-boot configuration data.


%prep
%setup -q


%install
rm -rf $RPM_BUILD_ROOT
%{__mkdir} -p %{buildroot}%{app_root}

# copy over the startup script
%{__cp} -R audrey_startup.py %{buildroot}%{app_root}

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(744,root,root,-)
%{app_root}/audrey_startup.py

%changelog
* Tue May 03 2011 Greg Blomquist <gblomqui@redhat.com> 0.0.1-3
- Changed to noarch
* Thu Apr 28 2011 Greg Blomquist <gblomqui@redhat.com> 0.0.1-2
- Initial spec
