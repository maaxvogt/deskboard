import Foundation
import Observation

struct WeatherSnapshot {
    var place: String
    var temperature: Double
    var todayMin: Double
    var todayMax: Double
    var weatherCode: Int

    var symbolName: String { WeatherSnapshot.symbol(for: weatherCode) }
    var conditionText: String { WeatherSnapshot.text(for: weatherCode) }

    /// WMO weather interpretation codes as used by Open-Meteo.
    static func symbol(for code: Int) -> String {
        switch code {
        case 0: return "sun.max"
        case 1, 2: return "cloud.sun"
        case 3: return "cloud"
        case 45, 48: return "cloud.fog"
        case 51...57: return "cloud.drizzle"
        case 61...67, 80...82: return "cloud.rain"
        case 71...77, 85, 86: return "cloud.snow"
        case 95...99: return "cloud.bolt.rain"
        default: return "cloud"
        }
    }

    static func text(for code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1: return "Mostly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Fog"
        case 51...57: return "Drizzle"
        case 61...67: return "Rain"
        case 71...77: return "Snow"
        case 80...82: return "Showers"
        case 85, 86: return "Snow showers"
        case 95...99: return "Thunderstorm"
        default: return "—"
        }
    }
}

/// Fetches current conditions from Open-Meteo (no API key required).
/// The place name from settings is geocoded once and cached.
@Observable
final class WeatherService {
    private(set) var snapshot: WeatherSnapshot?
    private(set) var error: String?

    private var geocoded: (place: String, lat: Double, lon: Double)?

    func refresh() async {
        if Demo.active {
            snapshot = Demo.weather
            error = nil
            return
        }
        let place = AppSettings.shared.weatherPlace.trimmingCharacters(in: .whitespaces)
        guard !place.isEmpty else {
            snapshot = nil
            error = nil
            return
        }
        do {
            let coords = try await coordinates(for: place)
            var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
            comps.queryItems = [
                .init(name: "latitude", value: String(coords.lat)),
                .init(name: "longitude", value: String(coords.lon)),
                .init(name: "current", value: "temperature_2m,weather_code"),
                .init(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
                .init(name: "forecast_days", value: "1"),
                .init(name: "timezone", value: "auto"),
            ]
            let (data, _) = try await URLSession.shared.data(from: comps.url!)
            let decoded = try JSONDecoder().decode(ForecastResponse.self, from: data)
            snapshot = WeatherSnapshot(
                place: coords.place,
                temperature: decoded.current.temperature_2m,
                todayMin: decoded.daily.temperature_2m_min.first ?? decoded.current.temperature_2m,
                todayMax: decoded.daily.temperature_2m_max.first ?? decoded.current.temperature_2m,
                weatherCode: decoded.current.weather_code
            )
            error = nil
        } catch {
            self.error = "Weather unavailable"
        }
    }

    private func coordinates(for place: String) async throws -> (place: String, lat: Double, lon: Double) {
        if let cached = geocoded, cached.place.caseInsensitiveCompare(place) == .orderedSame {
            return cached
        }
        var comps = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        comps.queryItems = [.init(name: "name", value: place), .init(name: "count", value: "1")]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let decoded = try JSONDecoder().decode(GeocodeResponse.self, from: data)
        guard let hit = decoded.results?.first else {
            throw URLError(.resourceUnavailable)
        }
        let result = (place: place, lat: hit.latitude, lon: hit.longitude)
        geocoded = result
        return result
    }

    private struct GeocodeResponse: Decodable {
        struct Hit: Decodable { let latitude: Double; let longitude: Double }
        let results: [Hit]?
    }

    private struct ForecastResponse: Decodable {
        struct Current: Decodable { let temperature_2m: Double; let weather_code: Int }
        struct Daily: Decodable { let temperature_2m_max: [Double]; let temperature_2m_min: [Double] }
        let current: Current
        let daily: Daily
    }
}
