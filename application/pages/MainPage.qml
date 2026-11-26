// SPDX-FileCopyrightText: 2013 - 2023 Jolla Ltd.
// SPDX-FileCopyrightText: 2024 - 2025 Jolla Mobile Ltd
//
// SPDX-License-Identifier: BSD-3-Clause

import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Weather 1.0
import Nemo.DBus 2.0

Page {
    readonly property bool noProviderSelected: WeatherProvider.currentProvider().length === 0
    readonly property bool hasCurrentWeather: !!savedWeathersModel.currentWeather
    readonly property bool loadingCurrentWeather: hasCurrentWeather && !currentWeatherAvailable
    readonly property bool emptyState: !hasCurrentWeather && savedWeathersModel.count === 0

    SilicaListView {
        id: weatherListView

        PullDownMenu {
            visible: (!savedWeathersModel.currentWeather
                      || savedWeathersModel.currentWeather.status !== Weather.Unauthorized)
                     && WeatherProvider.isApiKeyProvided
            MenuItem {
                //% "New location"
                text: qsTrId("weather-me-new_location")
                onClicked: pageStack.animatorPush(Qt.resolvedUrl("LocationSearchPage.qml"))
            }
            MenuItem {
                //% "Update"
                text: qsTrId("weather-me-update")
                onClicked: reloadTimer.restart()
                enabled: savedWeathersModel.currentWeather || savedWeathersModel.count > 0
                Timer {
                    id: reloadTimer

                    interval: 500
                    onTriggered: weatherApplication.reloadAll()
                }
            }
        }
        anchors.fill: parent
        header: Column {
            width: parent.width
            spacing: Theme.paddingLarge

            WeatherHeader {
                opacity: currentWeatherAvailable ? 1.0 : 0.0
                weather: savedWeathersModel.currentWeather
                onClicked: {
                    pageStack.animatorPush("WeatherPage.qml", {
                        "weather": weather,
                        "weatherModel": currentWeatherModel,
                        "savedWeathersModel": savedWeathersModel,
                        "current": true
                    })
                }
            }

            Label {
                visible: !placeholder.enabled
                         && currentWeatherAvailable
                         && currentWeatherModel.status === Weather.Unauthorized
                         && WeatherProvider.isApiKeyProvided
                x: Theme.horizontalPageMargin
                width: parent.width - 2*x
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                font {
                    pixelSize: Theme.fontSizeLarge
                    family: Theme.fontFamilyHeading
                }

                color: palette.highlightColor
                opacity: Theme.opacityHigh

                //% "Invalid authentication credentials"
                text: qsTrId("weather-la-unauthorized")
            }

            Label {
                visible: !placeholder.enabled
                         && !noProviderSelected
                         && currentWeatherAvailable
                         && !WeatherProvider.isApiKeyProvided
                x: Theme.horizontalPageMargin
                width: parent.width - 2*x
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                font {
                    pixelSize: Theme.fontSizeLarge
                    family: Theme.fontFamilyHeading
                }

                color: palette.highlightColor
                opacity: Theme.opacityHigh

                //% "Api key is not provided. Please provide API key in the Weather app settings"
                text: qsTrId("weather-la-api_key_not_provided_instruction")
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge
            }
        }
        PlaceholderItem {
            id: placeholder

            flickable: weatherListView
            parent: weatherListView.contentItem
            y: weatherListView.originY
               + (currentWeatherAvailable ? Math.round(parent.height / 12) + weatherListView.headerItem.height
                                          : Math.round(Screen.height / 4))
            enabled: loadingCurrentWeather
                     || emptyState
                     || (currentWeatherAvailable && savedWeathersModel.count === 0 && counter.active)
            error: savedWeathersModel.currentWeather && savedWeathersModel.currentWeather.status === Weather.Error
            unauthorized: savedWeathersModel.currentWeather && savedWeathersModel.currentWeather.status === Weather.Unauthorized
            empty: emptyState
            text: {
                if (error) {
                    //% "Loading failed"
                    return qsTrId("weather-la-loading_failed")
                }
                if (unauthorized) {
                    //% "Invalid authentication credentials"
                    return qsTrId("weather-la-unauthorized")
                }

                if (empty) {
                    if (noProviderSelected) {
                        //% "No weather provider selected. Open Settings to choose one."
                        return qsTrId("weather-la-no_weather_provider_selected")
                    }

                    if (currentWeatherAvailable) {
                        if (counter.active) {
                            return SoftKeys.active
                                    ? //: Access via softkey
                                      //% "Press options to add another weather location"
                                      qsTrId("weather-la-options_to_add_another_location")
                                    : //% "Pull down to add another weather location"
                                      qsTrId("weather-la-pull_down_to_add_another_location")
                        }

                        return ""
                    }

                    return SoftKeys.active
                            ? //: Access via softkey
                              //% "Press options to select your location"
                              qsTrId("weather-la-options_to_select_your_location")
                            : //% "Pull down to select your location"
                              qsTrId("weather-la-pull_down_to_select_your_location")
                }

                //% "Loading"
                return qsTrId("weather-la-loading")
            }
            onReload: {
                if (savedWeathersModel.currentWeather) {
                    weatherApplication.reload(savedWeathersModel.currentWeather.locationId)
                }
            }

            // Only show pull down to add another location hint twice on app startup
            FirstTimeUseCounter {
                id: counter

                limit: 2
                key: "/sailfish/weather/pull_down_to_add_another_location_hint_count"
                property bool showLocationHint: active && currentWeatherAvailable
                onShowLocationHintChanged: if (showLocationHint) counter.increase()
            }
        }
        model: savedWeathersModel
        delegate: ListItem {
            id: savedWeatherItem

            readonly property bool compatible: WeatherProvider.isLocationCompatible(model)
            visible: WeatherProvider.isApiKeyProvided && compatible

            function remove() {
                savedWeathersModel.remove(locationId, model.provider)
            }
            ListView.onAdd: AddAnimation { target: savedWeatherItem }
            ListView.onRemove: animateRemoval()
            menu: contextMenuComponent
            contentHeight: visible ? Math.max(Theme.itemSizeMedium, labelColumn.implicitHeight + 2 * Theme.paddingMedium) : 0
            onClicked: {
                pageStack.animatorPush("WeatherPage.qml", {
                    "weather": savedWeathersModel.get(model.locationId, model.provider),
                    "weatherModel": weatherModels[weatherApplication.weatherModelKey(model.provider, model.locationId)],
                    "savedWeathersModel": savedWeathersModel
                })
            }

            Image {
                id: icon

                x: Theme.horizontalPageMargin
                anchors.verticalCenter: labelColumn.verticalCenter
                visible: model.status !== Weather.Loading
                width: Theme.iconSizeMedium
                height: Theme.iconSizeMedium
                source: !!model.weatherType
                        && model.weatherType.length > 0 ? "image://theme/icon-m-weather-" + model.weatherType
                                                          + (highlighted ? "?" + Theme.highlightColor : "")
                                                        : ""
            }
            BusyIndicator {
                running: model.status === Weather.Loading
                anchors.centerIn: icon
            }
            Column {
                id: labelColumn

                y: Theme.paddingMedium
                height: cityLabel.height + descriptionLabel.lineHeight
                anchors {
                    left: icon.right
                    right: temperatureLabel.left
                    leftMargin: Theme.paddingMedium
                    rightMargin: Theme.paddingSmall
                }
                Label {
                    id: cityLabel

                    width: parent.width
                    color: highlighted ? Theme.highlightColor : Theme.primaryColor
                    text: model.city + ", " + model.country + (model.adminArea ? (", " + model.adminArea) : "")
                    truncationMode: TruncationMode.Fade
                }
                Label {
                    id: descriptionLabel

                    property real lineHeight: height / lineCount

                    width: parent.width
                    color: highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                    text: !model.populated && model.status === Weather.Error
                          ? //% "Loading current conditions failed"
                            qsTrId("weather-la-loading_current_conditions_failed")
                          : model.description
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    wrapMode: Text.Wrap
                }
            }
            Label {
                id: temperatureLabel

                text: TemperatureConverter.format(model.temperature)
                color: highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                font.pixelSize: Theme.fontSizeHuge
                anchors {
                    verticalCenter: labelColumn.verticalCenter
                    right: parent.right
                    rightMargin: Theme.horizontalPageMargin
                }
                width: visible ? implicitWidth : 0
                visible: model.populated
            }
            Component {
                id: contextMenuComponent

                ContextMenu {
                    property bool moveItemsWhenClosed
                    property bool setCurrentWhenClosed
                    property bool menuOpen: height > 0

                    onMenuOpenChanged: {
                        if (!menuOpen) {
                            if (moveItemsWhenClosed) {
                                savedWeathersModel.moveToTop(model.index)
                                moveItemsWhenClosed = false
                            }
                            if (setCurrentWhenClosed) {
                                var current = savedWeathersModel.currentWeather
                                if (!current || current.locationId !== model.locationId) {
                                    savedWeathersModel.setCurrentWeather(WeatherProvider.locationMap(model))

                                }
                                setCurrentWhenClosed = false
                            }
                        }
                    }

                    MenuItem {
                        //% "Remove"
                        text: qsTrId("weather-me-remove")
                        onClicked: remove()
                    }
                    MenuItem {
                        //% "Set as current"
                        text: qsTrId("weather-me-set_as_current")
                        visible: model.populated
                        onClicked: setCurrentWhenClosed = true
                    }
                    MenuItem {
                        //% "Move to top"
                        text: qsTrId("weather-me-move_to_top")
                        visible: model.index !== 0
                        onClicked: moveItemsWhenClosed = true
                    }
                }
            }
        }
        footer: Item {
            width: parent.width
            height: provider.height
        }

        ProviderDisclaimer {
            id: provider

            y: weatherListView.originY - weatherListView.contentY - height
               + Math.max(Screen.height, weatherListView.contentHeight)
            weather: savedWeathersModel.currentWeather
        }
        VerticalScrollDecorator {}
    }

    DBusAdaptor {
        service: "org.sailfishos.weather"
        path: "/org/sailfishos/weather"
        iface: "org.sailfishos.weather"
        xml: "  <interface name=\"org.sailfishos.weather\">\n" +
             "    <method name=\"newLocation\"/>\n" +
             "  </interface>\n"

        signal newLocation

        onNewLocation: {
            var alreadyOpen = pageStack.currentPage && pageStack.currentPage.objectName === "LocationSearchPage"
            if (!alreadyOpen)
                pageStack.push(Qt.resolvedUrl("LocationSearchPage.qml"), undefined, PageStackAction.Immediate)
            weatherApplication.activate()
        }

        function activateWindow(arg) {
            weatherApplication.activate()
        }
    }
}
