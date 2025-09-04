# SPDX-FileCopyrightText: 2013 - 2023 Jolla Ltd.
# SPDX-FileCopyrightText: 2024 - 2025 Jolla Mobile Ltd
#
# SPDX-License-Identifier: BSD-3-Clause

Name:       sailfish-weather
Summary:    Weather application
Version:    1.0.3
Release:    1
License:    BSD-3-Clause
URL:        https://github.com/sailfishos/sailfish-weather
Source0:    %{name}-%{version}.tar.bz2
Source1:    %{name}.privileges
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  pkgconfig(Qt5Gui)
BuildRequires:  pkgconfig(qdeclarative5-boostable)
BuildRequires:  pkgconfig(contentaction5)
BuildRequires:  qt5-qttools
BuildRequires:  qt5-qttools-linguist
BuildRequires:  oneshot

Requires: %{name}-all-translations

Requires: sailfishsilica-qt5 >= 0.27.0
Requires: mapplauncherd-booster-silica-qt5
Requires: sailfish-content-graphics >= 1.0.42
Requires: sailfish-content-graphics-closed
Requires: qt5-qtpositioning
Requires: nemo-qml-plugin-systemsettings >= 0.2.26
Requires: qt5-qtdeclarative-import-xmllistmodel
Requires: qt5-qtdeclarative-import-positioning
Requires: libkeepalive >= 1.7.0
Requires: nemo-qml-plugin-connectivity >= 0.1.0
Requires: jolla-settings-accounts

%{_oneshot_requires_post}

%description
Sailfish-style Weather application

%package ts-devel
Summary: Translation source for %{name}

%description ts-devel
Translation source for %{name}

%package -n sailfish-components-weather-qt5
Summary: Sailfish weather UI components

%description -n sailfish-components-weather-qt5
Sailfish weather UI components

%prep
%setup -q -n %{name}-%{version}

%build
%qmake5
%make_build

%install

%qmake5_install
chmod +x %{buildroot}/%{_oneshotdir}/*

mkdir -p %{buildroot}%{_datadir}/mapplauncherd/privileges.d
install -m 644 -p %{SOURCE1} %{buildroot}%{_datadir}/mapplauncherd/privileges.d/

%post
if [ $1 -eq 2 ]; then
    add-oneshot --all-users sailfish-weather-move-data-to-new-location || :
fi

%files
%license LICENSES/BSD-3-Clause.txt
%{_datadir}/applications/*.desktop
%{_datadir}/sailfish-weather/*
%{_bindir}/sailfish-weather
%{_datadir}/translations/weather_eng_en.qm
%{_datadir}/jolla-settings/entries/sailfish-weather.json
%{_datadir}/jolla-settings/pages/sailfish-weather
%{_datadir}/dbus-1/services/org.sailfishos.weather.service
%{_datadir}/mapplauncherd/privileges.d/*
%{_libdir}/qt5/qml/org/sailfishos/weather/settings
%{_oneshotdir}/sailfish-weather-move-data-to-new-location

%files -n sailfish-components-weather-qt5
%dir %{_libdir}/qt5/qml/Sailfish/Weather
%{_libdir}/qt5/qml/Sailfish/Weather/*
%{_datadir}/translations/sailfish_components_weather_qt5_eng_en.qm

%files ts-devel
%{_datadir}/translations/source/weather.ts
%{_datadir}/translations/source/sailfish_components_weather_qt5.ts
