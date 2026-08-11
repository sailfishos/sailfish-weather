// SPDX-FileCopyrightText: 2014 - 2023 Jolla Ltd.
// SPDX-FileCopyrightText: 2024 - 2025 Jolla Mobile Ltd
//
// SPDX-License-Identifier: BSD-3-Clause

import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Weather 1.0

Item {
    WeatherCoverItem {
        x: Theme.paddingLarge
        width: parent.width - 2*x
        topPadding: Theme.paddingLarge
        text: {
            if (!weather) {
                return ""
            }

            return (weather.status === Weather.Error || weather.status === Weather.Unauthorized)
                    ? weather.city
                    : TemperatureConverter.format(weather.temperature) + " " + weather.city
        }
        description: {
            if (!weather) {
                return ""
            }

            if (weather.status === Weather.Error) {
                //% "Loading failed"
                return qsTrId("weather-la-loading_failed")
            } else if (weather.status === Weather.Unauthorized) {
                //% "Invalid authentication credentials"
                return qsTrId("weather-la-unauthorized")
            }

            return weather.description
        }
    }
    WeatherImage {
        id: weatherImage

        height: width
        width: parent.width - Theme.paddingLarge
        sourceSize.width: width
        sourceSize.height: width
        weatherType: weather ? weather.weatherType : ""
        anchors {
            centerIn: parent
            verticalCenterOffset: Theme.paddingSmall
        }
    }
}
