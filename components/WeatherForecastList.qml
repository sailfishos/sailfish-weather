// SPDX-FileCopyrightText: 2020 - 2023 Jolla Ltd.
// SPDX-FileCopyrightText: 2024 - 2025 Jolla Mobile Ltd
//
// SPDX-License-Identifier: BSD-3-Clause

import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Weather 1.0

SilicaListView {
    property bool active: true
    property int columnCount: 6
    property int itemWidth: width / columnCount
    property int itemHeight

    opacity: active ? 1.0 : 0.0
    Behavior on opacity { FadeAnimator {}}
    width: parent ? parent.width : 0
    implicitHeight: 2 * (Screen.sizeCategory >= Screen.Large ? Theme.itemSizeExtraLarge : Theme.itemSizeLarge)
    height: Math.max(itemHeight, implicitHeight)

    clip: true // limit to 6 forecasts
    currentIndex: -1
    interactive: false
    orientation: ListView.Horizontal
}
