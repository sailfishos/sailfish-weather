// SPDX-FileCopyrightText: 2026 Jolla Mobile Ltd
//
// SPDX-License-Identifier: BSD-3-Clause

import QtQuick 2.6
import "BackendUtils.js" as BackendUtils
import "GeoNames.js" as GeoNames
import "WeatherTypeDescriptions.js" as WeatherTypeDescriptions

QtObject {
    readonly property string metForecastApi: "https://api.met.no/weatherapi/locationforecast/2.0/complete"

    function providerId() {
        return "met_norway"
    }

    function providerTitle() {
        //% "MET Norway"
        return qsTrId("weather_settings-me-met-norway")
    }

    function requiresApiKey() {
        return false
    }

    function apiKeyInstructions() {
        return ""
    }

    function attributionText() {
        //: Content between %1 and %2 is a link to the MET Norway / Yr web site.
        //: Content between %3 and %4 is a link to the CC BY 4.0 license page.
        //% "Weather data from %1MET Norway / Yr%2, licensed under %3CC BY 4.0%4. "
        //% "Forecast data is formatted for presentation in Sailfish Weather."
        return qsTrId("weather_settings-met-norway-attribution")
                .arg("<a href='https://www.yr.no/'>")
                .arg("</a>")
                .arg("<a href='https://creativecommons.org/licenses/by/4.0/'>")
                .arg("</a>")
    }

    function shortAttributionText() {
        //% "Weather data from MET Norway / Yr"
        return qsTrId("weather-la-met-norway-attribution-short")
    }

    function locationSearchAttributionText() {
        //: Content between %1 and %2 is a link to the GeoNames web site.
        //% "Location search by %1GeoNames%2."
        return qsTrId("weather-la-geonames-attribution")
                .arg("<a href='https://www.geonames.org/'>")
                .arg("</a>")
    }

    function maxPrecision() {
        return 4
    }

    function fetchToken(weatherRequest, apiKey) {
        weatherRequest.token = ""
        return true
    }

    function requestHeaders() {
        return {
            "User-Agent": "Sailfish Weather/1.0 (+https://github.com/sailfishos/sailfish-weather)",
            "Accept": "application/json"
        }
    }

    function currentWeatherUrl(weather) {
        return metForecastApi + "?lat=" + weather.latitude + "&lon=" + weather.longitude
    }

    function latestObservationUrl(weather) {
        return currentWeatherUrl(weather)
    }

    function forecastUrl(weather, isHourly) {
        return currentWeatherUrl(weather)
    }

    function searchLocationUrl(filter, language) {
        return GeoNames.searchLocationUrl(filter, language)
    }

    function reverseLocationResponseType() {
        return "json"
    }

    function reverseLocationUrl(latitude, longitude, language) {
        return GeoNames.reverseLocationUrl(latitude, longitude, language)
    }

    function handleCurrentWeatherResult(result) {
        var forecast = forecastTimeseries(result)
        if (forecast.length === 0) {
            return undefined
        }

        var entry = forecast[0]
        var details = entry.data.instant ? entry.data.instant.details : undefined
        if (details === undefined || details.air_temperature === undefined) {
            return undefined
        }

        var weather = getWeatherData(entry)
        weather.timestamp = new Date(entry.time)
        weather.temperature = details.air_temperature
        weather.feelsLikeTemperature = details.air_temperature
        return weather
    }

    function handleForecastResult(result, hourly, visibleCount, minimumHourlyRange) {
        var forecast = forecastTimeseries(result)
        if (forecast.length === 0) {
            return undefined
        }

        var weatherData = []
        if (hourly) {
            for (var i = 0; i < forecast.length && weatherData.length < visibleCount + 1; i++) {
                var entry = forecast[i]
                var details = entry.data.instant ? entry.data.instant.details : undefined
                if (details === undefined || details.air_temperature === undefined) {
                    continue
                }

                var weather = getWeatherData(entry)
                weather.timestamp = new Date(entry.time)
                weather.temperature = details.air_temperature
                weatherData[weatherData.length] = weather
            }

            return BackendUtils.normalizeHourlyTemperatures(
                        weatherData, visibleCount, minimumHourlyRange, true)
        }

        var groupedByDay = forecast.reduce(function(container, entry) {
            var entryDetails = entry.data.instant ? entry.data.instant.details : undefined
            if (entryDetails === undefined || entryDetails.air_temperature === undefined) {
                return container
            }

            // Convert UTC to date in local time zone
            var dayKey = Qt.formatDate(new Date(entry.time), Qt.ISODate)
            if (!container[dayKey]) {
                container[dayKey] = []
            }
            container[dayKey].push(entry)
            return container
        }, {})

        var days = Object.keys(groupedByDay).sort()
        for (var dayIndex = 0; dayIndex < days.length; dayIndex++) {
            var groupedDay = days[dayIndex]
            var entries = groupedByDay[groupedDay]
            var representative = entries[0]
            var representativeDiff = Math.abs(hourOfDay(representative.time) - 12)
            var representativeDetails = representative.data.instant.details
            var minimumDailyTemperature = representativeDetails.air_temperature
            var maximumDailyTemperature = representativeDetails.air_temperature
            var accumulatedPrecipitation = 0
            var maximumWindSpeed = representativeDetails.wind_speed || 0

            for (var entryIndex = 0; entryIndex < entries.length; entryIndex++) {
                var point = entries[entryIndex]
                var pointDetails = point.data.instant.details
                var pointTemperature = pointDetails.air_temperature

                minimumDailyTemperature = Math.min(minimumDailyTemperature, pointTemperature)
                maximumDailyTemperature = Math.max(maximumDailyTemperature, pointTemperature)
                maximumWindSpeed = Math.max(maximumWindSpeed, pointDetails.wind_speed || 0)
                accumulatedPrecipitation += precipitationAmount(point.data)

                var diff = Math.abs(hourOfDay(point.time) - 12)
                if (diff < representativeDiff) {
                    representative = point
                    representativeDiff = diff
                }
            }

            var dailyWeather = getWeatherData(representative)
            var selectedDetails = representative.data.instant.details
            dailyWeather.timestamp = new Date(representative.time)
            dailyWeather.accumulatedPrecipitation = accumulatedPrecipitation
            dailyWeather.maximumWindSpeed = Math.round(maximumWindSpeed)
            dailyWeather.windDirection = selectedDetails.wind_from_direction
            dailyWeather.high = Math.floor(maximumDailyTemperature)
            dailyWeather.low = Math.round(minimumDailyTemperature)
            weatherData[weatherData.length] = dailyWeather
        }

        return weatherData
    }

    function handleSearchLocationResult(result) {
        return GeoNames.handleSearchLocationResult(result)
    }

    function handleReverseLocationResult(result, latitude, longitude) {
        return GeoNames.handleReverseLocationResult(result, latitude, longitude)
    }

    function handleObservationResult(result) {
        return ""
    }

    function externalUrl(weather) {
        return "https://www.yr.no/en"
    }

    function providerImage() {
        return "image://theme/met-norway?"
    }

    function smallProviderImage() {
        return "image://theme/met-norway-small?"
    }

    function forecastTimeseries(result) {
        if (result === undefined || result.properties === undefined || result.properties.timeseries === undefined) {
            return []
        }

        return result.properties.timeseries
    }

    function precipitationAmount(data) {
        if (data.next_1_hours && data.next_1_hours.details && data.next_1_hours.details.precipitation_amount !== undefined) {
            return data.next_1_hours.details.precipitation_amount
        }
        if (data.next_6_hours && data.next_6_hours.details && data.next_6_hours.details.precipitation_amount !== undefined) {
            return data.next_6_hours.details.precipitation_amount
        }
        if (data.next_12_hours && data.next_12_hours.details && data.next_12_hours.details.precipitation_amount !== undefined) {
            return data.next_12_hours.details.precipitation_amount
        }

        return 0
    }

    function summarySymbolCode(data) {
        if (data.next_1_hours && data.next_1_hours.summary && data.next_1_hours.summary.symbol_code) {
            return data.next_1_hours.summary.symbol_code
        }
        if (data.next_6_hours && data.next_6_hours.summary && data.next_6_hours.summary.symbol_code) {
            return data.next_6_hours.summary.symbol_code
        }
        if (data.next_12_hours && data.next_12_hours.summary && data.next_12_hours.summary.symbol_code) {
            return data.next_12_hours.summary.symbol_code
        }

        return "cloudy"
    }

    function baseSymbolCode(symbolCode) {
        return symbolCode.replace("_day", "").replace("_night", "").replace("_polartwilight", "")
    }

    function weatherTypeFromMetSymbol(symbolCode) {
        var base = baseSymbolCode(symbolCode)
        var thunder = base.indexOf("thunder") >= 0
        var showers = base.indexOf("showers") >= 0

        if (thunder) {
            if (showers || base.indexOf("heavy") >= 0) {
                return "440"
            } else if (base.indexOf("rain") >= 0 || base.indexOf("sleet") >= 0 || base.indexOf("snow") >= 0) {
                return "340"
            }
            return "240"
        }

        if (base === "fog") {
            return "600"
        }
        if (base === "clearsky") {
            return "000"
        }
        if (base === "fair") {
            return "100"
        }
        if (base === "partlycloudy") {
            return "200"
        }
        if (base === "cloudy") {
            return "300"
        }
        if (base.indexOf("snowshowers") >= 0) {
            if (base.indexOf("light") >= 0) return "222"
            if (base.indexOf("heavy") >= 0) return "422"
            return "322"
        }
        if (base.indexOf("sleetshowers") >= 0) {
            if (base.indexOf("light") >= 0) return "221"
            if (base.indexOf("heavy") >= 0) return "421"
            return "321"
        }
        if (base.indexOf("rainshowers") >= 0) {
            if (base.indexOf("light") >= 0) return "220"
            if (base.indexOf("heavy") >= 0) return "420"
            return "320"
        }
        if (base.indexOf("snow") >= 0) {
            if (base.indexOf("light") >= 0) return "212"
            if (base.indexOf("heavy") >= 0) return "432"
            return "312"
        }
        if (base.indexOf("sleet") >= 0) {
            if (base.indexOf("light") >= 0) return "211"
            if (base.indexOf("heavy") >= 0) return "431"
            return "311"
        }
        if (base.indexOf("rain") >= 0 || base.indexOf("drizzle") >= 0) {
            if (base.indexOf("light") >= 0) return "210"
            if (base.indexOf("heavy") >= 0) return "430"
            return "310"
        }

        return "300"
    }

    function humanizeMetSymbol(symbolCode) {
        var remaining = symbolCode || ""
        var tokens = [
            ["partlycloudy", "partly cloudy"],
            ["showersandthunder", "showers and thunder"],
            ["andthunder", "and thunder"],
            ["clearsky", "clear sky"],
            ["rainshowers", "rain showers"],
            ["sleetshowers", "sleet showers"],
            ["snowshowers", "snow showers"],
            ["heavyrain", "heavy rain"],
            ["heavysleet", "heavy sleet"],
            ["heavysnow", "heavy snow"],
            ["lightrain", "light rain"],
            ["lightsleet", "light sleet"],
            ["lightsnow", "light snow"],
            ["drizzle", "drizzle"],
            ["cloudy", "cloudy"],
            ["fair", "fair"],
            ["fog", "fog"],
            ["rain", "rain"],
            ["sleet", "sleet"],
            ["snow", "snow"],
            ["light", "light"],
            ["heavy", "heavy"],
            ["showers", "showers"],
            ["thunder", "thunder"]
        ]
        var words = []

        while (remaining.length > 0) {
            var matched = false
            for (var i = 0; i < tokens.length; ++i) {
                var token = tokens[i]
                if (remaining.indexOf(token[0]) === 0) {
                    words.push(token[1])
                    remaining = remaining.slice(token[0].length)
                    matched = true
                    break
                }
            }

            if (!matched) {
                words.push(remaining.replace(/_/g, " "))
                break
            }
        }

        var text = words.join(" ").replace(/\s+/g, " ").trim()
        if (text.length === 0) {
            return ""
        }

        return text.charAt(0).toUpperCase() + text.slice(1)
    }

    function getWeatherData(entry) {
        var symbolCode = summarySymbolCode(entry.data)
        var timeSymbol = symbolCode.indexOf("_night") >= 0 ? "n" : "d"
        var weatherSymbol = timeSymbol + weatherTypeFromMetSymbol(symbolCode)
        var details = entry.data.instant && entry.data.instant.details ? entry.data.instant.details : {}
        var description = WeatherTypeDescriptions.description(weatherSymbol)

        return {
            "description": description.length > 0 ? description : humanizeMetSymbol(baseSymbolCode(symbolCode)),
            "weatherType": weatherType(weatherSymbol),
            "cloudiness": details.cloud_area_fraction !== undefined ? details.cloud_area_fraction : 0
        }
    }

    function weatherType(code) {
        if (code.length === 4) {
            return code
        } else {
            console.warn("Invalid weather code")
            return ""
        }
    }

    function displayName(name) {
        if (name === undefined || name === null || name.length === 0) {
            return ""
        }

        var commaIndex = name.indexOf(",")
        if (commaIndex < 0) {
            return name
        }

        return name.substring(0, commaIndex)
    }

    function hourOfDay(timestamp) {
        // Return the hour in local time zone
        var d = new Date(timestamp)
        return d.getHours()
    }
}
