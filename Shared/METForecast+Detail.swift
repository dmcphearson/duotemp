import Foundation

extension METForecast {
    /// Detail-screen data: 48 hours, up to 10 days, and current conditions.
    /// Sunrise and sunset come from MET's separate Sunrise API and are added by the caller.
    func detail(snapshot: WeatherSnapshot, now: Date) -> ForecastDetail {
        let steps = properties.timeseries.sorted { $0.time < $1.time }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = snapshot.timeZone

        let hours: [ForecastDetail.Hour] = steps
            .filter { $0.time >= snapshot.current.date }
            .compactMap { step in
                guard let period = step.data.next1Hours else { return nil }
                return ForecastDetail.Hour(
                    date: step.time,
                    temperature: DualTemp(celsius: step.data.instant.details.airTemperature),
                    symbolName: METSymbol(code: period.summary.symbolCode, windSpeed: step.data.instant.details.windSpeed).symbolName,
                    precipitationMM: period.details?.precipitationAmount,
                    precipitationChance: nil,
                    cloudCover: step.data.instant.details.cloudAreaFraction.map { $0 / 100 }
                )
            }

        let today = calendar.startOfDay(for: now)
        let byDay = Dictionary(grouping: steps.filter { $0.time >= snapshot.current.date }) { calendar.startOfDay(for: $0.time) }
        let days: [ForecastDetail.Day] = byDay.keys.sorted().compactMap { day in
            guard let items = byDay[day], day == today || items.count >= 3 else { return nil }

            var temperatures = items.map(\.data.instant.details.airTemperature)
            for item in items {
                if let max = item.data.next6Hours?.details?.airTemperatureMax { temperatures.append(max) }
                if let min = item.data.next6Hours?.details?.airTemperatureMin { temperatures.append(min) }
            }
            // Hourly steps carry 1-hour rain; the long-range tail only has 6-hour totals.
            let rain = items.reduce(0.0) { total, item in
                total + (item.data.next1Hours?.details?.precipitationAmount
                    ?? item.data.next6Hours?.details?.precipitationAmount ?? 0)
            }
            // The day's icon is the forecast nearest local noon.
            let noon = day.addingTimeInterval(12 * 3600)
            let symbolStep = items
                .filter { $0.data.next6Hours != nil || $0.data.next1Hours != nil }
                .min { abs($0.time.timeIntervalSince(noon)) < abs($1.time.timeIntervalSince(noon)) }
            let code = symbolStep?.data.next6Hours?.summary.symbolCode ?? symbolStep?.data.next1Hours?.summary.symbolCode

            let isToday = day == today
            return ForecastDetail.Day(
                date: day,
                symbolName: code.map { METSymbol(code: $0, windSpeed: symbolStep?.data.instant.details.windSpeed).symbolName } ?? "cloud",
                high: isToday ? snapshot.high : DualTemp(celsius: temperatures.max() ?? 0),
                low: isToday ? snapshot.low : DualTemp(celsius: temperatures.min() ?? 0),
                precipitationMM: rain,
                precipitationChance: nil
            )
        }

        let currentStep = steps.last { $0.time <= now } ?? steps.first
        let details = currentStep?.data.instant.details
        // Trend over the next three hours of forecast, as barometers report the last three.
        let later = currentStep.flatMap { current in
            steps.first { $0.time >= current.time.addingTimeInterval(3 * 3600) }?.data.instant.details.airPressureAtSeaLevel
        }
        var trend: ForecastDetail.PressureTrend?
        if let pressure = details?.airPressureAtSeaLevel, let later {
            trend = later - pressure > 1 ? .rising : (pressure - later > 1 ? .falling : .steady)
        }
        let conditions = ForecastDetail.Conditions(
            windSpeed: details?.windSpeed,
            windDirection: details?.windFromDirection,
            humidity: details?.relativeHumidity.map { $0 / 100 },
            uvIndex: details?.ultravioletIndexClearSky.map { Int($0.rounded()) },
            pressure: details?.airPressureAtSeaLevel,
            pressureTrend: trend,
            dewPoint: details?.dewPointTemperature.map { DualTemp(celsius: $0) }
        )

        var sources: [ForecastDetail.Field: WeatherSource] = [
            .temperature: .yr, .conditions: .yr, .forecast: .yr, .rainAmount: .yr,
        ]
        if conditions.windSpeed != nil { sources[.wind] = .yr }
        if conditions.humidity != nil { sources[.humidity] = .yr }
        if conditions.uvIndex != nil { sources[.uv] = .yr }
        if conditions.pressure != nil { sources[.pressure] = .yr }

        return ForecastDetail(
            snapshot: snapshot,
            hours: Array(hours.prefix(48)),
            days: Array(days.prefix(10)),
            conditions: conditions,
            sources: sources
        )
    }
}
