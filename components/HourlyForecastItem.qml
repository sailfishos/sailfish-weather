// SPDX-FileCopyrightText: 2020 - 2023 Jolla Ltd.
// SPDX-FileCopyrightText: 2024 - 2025 Jolla Mobile Ltd
//
// SPDX-License-Identifier: BSD-3-Clause

import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Weather 1.0

Column {
    property bool highlighted
    property int hourMode: DateTime.TwentyFourHours

    width: parent.width

    Item {
        property int padding: Theme.paddingSmall

        width: temperatureLabel.width
        height: temperatureGraph.height + temperatureLabel.height + padding
        anchors.horizontalCenter: parent.horizontalCenter

        Label {
            id: temperatureLabel

            text: TemperatureConverter.format(model.temperature)
            y: (1 - model.relativeTemperature) * temperatureGraph.height - parent.padding
        }
    }

    Image {
        property string prefix: "image://theme/icon-" + (Screen.sizeCategory >= Screen.Large ? "l" : "m")

        anchors.horizontalCenter: parent.horizontalCenter
        source: model.weatherType.length > 0 ? prefix + "-weather-" + model.weatherType
                                               + (highlighted ? "?" + Theme.highlightColor : "")
                                             : ""
    }

    Row {
        id: timeRow

        anchors.horizontalCenter: parent.horizontalCenter
        Label {
            id: timeLabel

            text: {
                if (hourMode === DateTime.TwentyFourHours) {
                    return Format.formatDate(model.timestamp, Format.TimeValueTwentyFourHours)
                } else {
                    var hours = model.timestamp.getHours()
                    if (hours === 0) {
                        hours = 12
                    } else if (hours > 12) {
                        hours -= 12
                    }

                    //% "h"
                    //: Pattern for 12h time, should be either "h" or "hh", latter with optional 0 at the start (like "03")
                    var result = qsTrId("weather-la-12h_time_pattern_without_ap")
                    var zero = 0

                    if (result.indexOf("hh") !== -1) {
                        var hourString = ""

                        if (hours < 10) {
                            hourString = zero.toLocaleString()
                        }
                        hourString += hours.toLocaleString()

                        result = result.replace("hh", hourString)
                    } else {
                        result = result.replace("h", hours.toLocaleString())
                    }

                    return result
                }
            }
            font.pixelSize: hourMode === DateTime.TwentyFourHours ? Theme.fontSizeSmall : Theme.fontSizeMedium
        }
        Label {
            visible: hourMode === DateTime.TwelveHours
            text: model.timestamp.getHours() < 12
                  ? //: Short postfix shown behind hours in twelve hour mode, e.g. time is 8am
                    //: Align with jolla-clock-la-am
                    //% "AM"
                    qsTrId("weather-la-hourmode_am")
                  : //: Short postfix shown behind hours in twelve hour mode, e.g. 3pm time
                    //: Align with jolla-clock-la-pm
                    //% "PM"
                    qsTrId("weather-clock-la-hourmode_pm")
            color: highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
            font.pixelSize: Theme.fontSizeTiny
            anchors.baseline: timeLabel.baseline
        }
    }
}
