#
# spec file for package emacs-modusregel
#
# Copyright (c) 2026 SUSE LLC and contributors
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#

Name:           emacs-modusregel
Version:        0.9.3
Release:        0
Summary:        Mode line customizations for Emacs
License:        MIT
URL:            https://github.com/jjba23/modusregel
Source0:        modusregel-%{version}.tar.gz
BuildRequires:  emacs
Requires:       emacs

%description
Modusregel draws the Emacs mode line out of variables the package defines,
so each element can be changed, reordered or left out.

%prep
%autosetup -n modusregel-%{version}

%build
emacs -Q --batch -f batch-byte-compile modusregel.el

%install
install -d %{buildroot}%{_datadir}/emacs/site-lisp
install -m 0644 modusregel.el modusregel.elc %{buildroot}%{_datadir}/emacs/site-lisp/

# The terminal render test needs a TTY and times out in a build chroot, so the ERT suite is not run.
# %check omitted.

%files
%license LICENSE
%doc README.org NEWS.org
%{_datadir}/emacs/site-lisp/modusregel.el
%{_datadir}/emacs/site-lisp/modusregel.elc

%changelog
