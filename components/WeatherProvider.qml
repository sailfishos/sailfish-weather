// SPDX-FileCopyrightText: 2025 Jolla Mobile Ltd
//
// SPDX-License-Identifier: BSD-3-Clause
//
// @author Anton Turko <turok@duck.com>

pragma Singleton
import QtQuick 2.6
import Nemo.Configuration 1.0

QtObject {
    id: root

    readonly property var backends: loadBackends()
    readonly property var providers: providerMetadata(backends)
    readonly property string defaultProviderId: "met_norway"
    readonly property var name: providerNameMap(providers)
    readonly property var backend: backendForId(effectiveProviderId(weatherProvider.value))

    readonly property ConfigurationValue weatherProvider: ConfigurationValue {
        key: "/sailfish/weather/data_provider"
        defaultValue: root.defaultProviderId
    }

    readonly property ConfigurationValue providerAppKey: ConfigurationValue {
        key: root.apiKeyConfigurationKey(root.currentProvider())
        defaultValue: ""
    }
    readonly property bool isApiKeyProvided: {
        var providerId = currentProvider()
        return providerId.length > 0
                && (!requiresApiKey(providerId) || providerAppKey.value.length > 0)
    }

    function loadBackends() {
        var loadedBackends = []
        var backendFiles = BackendRegistry.backendFiles

        for (var i = 0; i < backendFiles.length; i++) {
            var backend = createBackend(backendFiles[i])
            if (!backend || backend.providerId().length === 0) {
                continue
            }

            loadedBackends[loadedBackends.length] = backend
        }

        // TODO: Use locale-aware sorting if provider titles become translated
        // differently enough that simple string ordering becomes problematic.
        loadedBackends.sort(function(a, b) {
            var aTitle = a.providerTitle()
            var bTitle = b.providerTitle()
            if (aTitle < bTitle) {
                return -1
            }
            if (aTitle > bTitle) {
                return 1
            }
            return 0
        })

        return loadedBackends
    }

    function createBackend(backendFile) {
        var component = Qt.createComponent(backendFile)
        if (component.status !== Component.Ready) {
            console.warn("Failed to load weather backend", backendFile, component.errorString())
            return null
        }

        var backend = component.createObject(root)
        if (!backend) {
            console.warn("Failed to instantiate weather backend", backendFile, component.errorString())
            return null
        }

        return backend
    }

    function providerMetadata(backends) {
        var metadata = []
        for (var i = 0; i < backends.length; i++) {
            metadata[metadata.length] = {
                "id": backends[i].providerId(),
                "title": backends[i].providerTitle(),
                "requiresApiKey": backends[i].requiresApiKey(),
                "apiKeyInstructions": backends[i].apiKeyInstructions(),
                "attributionText": callBackend(backends[i], "attributionText", ""),
                "locationSearchAttributionText": callBackend(backends[i], "locationSearchAttributionText", "")
            }
        }

        return metadata
    }

    function callBackend(backendObject, methodName, defaultValue) {
        if (!backendObject || typeof backendObject[methodName] !== "function") {
            return defaultValue
        }

        return backendObject[methodName]()
    }

    function providerNameMap(providers) {
        var result = {}

        for (var i = 0; i < providers.length; i++) {
            result[providers[i].id.toUpperCase().replace(/[^A-Z0-9]+/g, "_")] = providers[i].id
        }

        return result
    }

    function effectiveProviderId(providerId) {
        if (backendForId(providerId)) {
            return providerId
        }

        if (backendForId(defaultProviderId)) {
            return defaultProviderId
        }

        return ""
    }

    function backendForId(providerId) {
        if (backends.length === 0 || typeof providerId !== "string" || providerId.length === 0) {
            return null
        }
        for (var i = 0; i < backends.length; i++) {
            if (backends[i].providerId() === providerId) {
                return backends[i]
            }
        }

        return null
    }

    function providerInfo(providerId) {
        providerId = effectiveProviderId(providerId)
        if (typeof providerId !== "string" || providerId.length === 0) {
            return null
        }

        for (var i = 0; i < providers.length; i++) {
            if (providers[i].id === providerId) {
                return providers[i]
            }
        }

        return null
    }

    function indexOfProvider(providerId) {
        providerId = effectiveProviderId(providerId)
        if (typeof providerId !== "string" || providerId.length === 0) {
            return -1
        }
        for (var i = 0; i < providers.length; i++) {
            if (providers[i].id === providerId) {
                return i
            }
        }

        return -1
    }

    function apiKeyConfigurationKey(providerId) {
        var backend = backendForId(effectiveProviderId(providerId))
        if (!backend) {
            return "/sailfish/weather/app_id"
        }

        return "/sailfish/weather/" + backend.providerId() + "_app_id"
    }

    function currentProvider() {
        return effectiveProviderId(weatherProvider.value)
    }

    function requiresApiKey(providerId) {
        var selectedBackend = backendForId(providerId)
        return selectedBackend ? selectedBackend.requiresApiKey() : false
    }

    function fetchToken(weatherRequest) {
        if (!backend) {
            console.log("Selected weather provider backend is not supported.")
            return false
        }

        return backend.fetchToken(weatherRequest, providerAppKey.value)
    }

    function locationProvider(weather) {
        if (weather === undefined || weather === null) {
            return backendForId(defaultProviderId) ? defaultProviderId : ""
        }

        if (typeof weather.provider === "string" && weather.provider.length > 0) {
            return weather.provider
        }

        var providerId = backendForId(defaultProviderId) ? defaultProviderId : ""
        weather["provider"] = providerId
        return providerId
    }

    function locationMap(weather) {
        if (!weather) {
            return {}
        }

        return {
            "locationId": weather.locationId,
            "provider": weather.provider,
            "latitude": weather.latitude,
            "longitude": weather.longitude,
            "city": weather.city,
            "state": weather.state,
            "adminArea": weather.adminArea,
            "adminArea2": weather.adminArea2,
            "station": weather.station,
            "country": weather.country,
            "temperature": weather.temperature,
            "feelsLikeTemperature": weather.feelsLikeTemperature,
            "weatherType": weather.weatherType,
            "description": weather.description,
            "timestamp": weather.timestamp,
            "populated": weather.populated
        }
    }

    function isLocationCompatible(weather) {
        return locationProvider(weather) === currentProvider()
    }

    function requestHeaders() {
        return callBackend(backend, "requestHeaders", {})
    }

    function providerImage() {
        return callBackend(backend, "providerImage", "")
    }

    function smallProviderImage() {
        return callBackend(backend, "smallProviderImage", "")
    }

    function attributionText() {
        return callBackend(backend, "attributionText", "")
    }

    function shortAttributionText() {
        return callBackend(backend, "shortAttributionText", "")
    }

    function locationSearchAttributionText() {
        return callBackend(backend, "locationSearchAttributionText", "")
    }

    function forecastUrl(weather, hourly) {
        return backend ? backend.forecastUrl(withPrecision(weather), hourly) : ""
    }

    function latestObservationUrl(weatherJson) {
        return backend ? backend.latestObservationUrl(withPrecision(weatherJson)) : ""
    }

    function searchLocationUrl(filter, language) {
        return backend ? backend.searchLocationUrl(filter, language) : ""
    }

    function currentWeatherUrl(weather) {
        return backend ? backend.currentWeatherUrl(withPrecision(weather)) : ""
    }

    function handleSearchLocationResult(result) {
        return backend ? backend.handleSearchLocationResult(result) : undefined
    }

    function externalUrl(weather) {
        return backend ? backend.externalUrl(weather) : ""
    }

    function handleCurrentWeatherResult(result) {
        return backend ? backend.handleCurrentWeatherResult(result) : undefined
    }

    function handleObservationResult(result) {
        return backend ? backend.handleObservationResult(result) : ""
    }

    function handleForecastResult(result, hourly, visibleCount, minimumHourlyRange) {
        if (!backend) {
            return undefined
        }

        var res = backend.handleForecastResult(result, hourly, visibleCount, minimumHourlyRange)
        if (res === undefined || res === null) {
            return undefined
        }

        for (var index in res) {
            var weather = res[index]
            var precipitationRateCode = weather.weatherType.charAt(2)
            var precipitationRate = ""

            switch (precipitationRateCode) {
            case '0':
                //% "No precipitation"
                precipitationRate = qsTrId("weather-la-precipitation_none")
                break
            case '1':
                //% "Slight precipitation"
                precipitationRate = qsTrId("weather-la-precipitation_slight")
                break
            case '2':
                //% "Showers"
                precipitationRate = qsTrId("weather-la-precipitation_showers")
                break
            case '3':
                //% "Precipitation"
                precipitationRate = qsTrId("weather-la-precipitation_normal")
                break
            case '4':
                //% "Thunder"
                precipitationRate = qsTrId("weather-la-precipitation_thunder")
                break
            default:
                console.log("WeatherModel warning: invalid precipitation rate code", precipitationRateCode)
                break
            }

            var precipitationType = ""
            if (precipitationRateCode === '0') {
                //% "None"
                precipitationType = qsTrId("weather-la-precipitationtype_none")
            } else {
                var precipitationTypeCode = weather.weatherType.charAt(3)
                switch (precipitationTypeCode) {
                case '0':
                    //% "Rain"
                    precipitationType = qsTrId("weather-la-precipitationtype_rain")
                    break
                case '1':
                    //% "Sleet"
                    precipitationType = qsTrId("weather-la-precipitationtype_sleet")
                    break
                case '2':
                    //% "Snow"
                    precipitationType = qsTrId("weather-la-precipitationtype_snow")
                    break
                default:
                    console.log("WeatherModel warning: invalid precipitation type code", precipitationTypeCode)
                    break
                }
            }
            // Backend descriptions can retain detail lost in the shared icon codes.
            weather['precipitationType'] = weather.precipitationType || precipitationType
            weather['precipitationRate'] = weather.precipitationRate || precipitationRate
        }

        return res
    }

    function withPrecision(weather) {
        if (!backend || !weather) {
            return weather
        }

        if (typeof backend.maxPrecision !== "function") {
            return weather
        }

        var precision = backend.maxPrecision()
        if (precision === undefined || precision < 0
                || weather.latitude === undefined || weather.longitude === undefined) {
            return weather
        }

        // Only copy the location-identifying fields needed by backend URL
        // builders. If source depends on dynamic weather data like temperature
        // or description, updating the current weather can re-trigger the same
        // request binding path.
        var adjustedWeather = {
            "locationId": weather.locationId,
            "provider": weather.provider,
            "latitude": weather.latitude,
            "longitude": weather.longitude
        }
        adjustedWeather.latitude = truncateToPrecision(weather.latitude, precision)
        adjustedWeather.longitude = truncateToPrecision(weather.longitude, precision)
        return adjustedWeather
    }

    function truncateToPrecision(value, precision) {
        var factor = Math.pow(10, precision)
        var scaled = value * factor
        var truncated = scaled < 0 ? Math.ceil(scaled) : Math.floor(scaled)
        return truncated / factor
    }
}
