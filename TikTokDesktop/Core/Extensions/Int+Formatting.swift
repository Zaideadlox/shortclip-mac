import Foundation

extension Int {
    var compactFormatted: String {
        let absValue = abs(self)
        let sign = self < 0 ? "-" : ""
        switch absValue {
        case 1_000_000_000...:
            return String(format: "%@%.1fB", sign, Double(absValue) / 1_000_000_000)
        case 1_000_000...:
            return String(format: "%@%.1fM", sign, Double(absValue) / 1_000_000)
        case 10_000...:
            return String(format: "%@%.1fK", sign, Double(absValue) / 1_000)
        case 1_000...:
            return String(format: "%@%.1fK", sign, Double(absValue) / 1_000)
        default:
            return "\(self)"
        }
    }
}

extension Double {
    var formattedDuration: String {
        guard isFinite, self >= 0 else { return "0:00" }
        let totalSeconds = Int(self.rounded(.down))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
