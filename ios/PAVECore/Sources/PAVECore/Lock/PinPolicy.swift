public enum PinPolicy {
    public static let length = 6

    public static func isValidFormat(_ pin: String) -> Bool {
        pin.count == length && pin.allSatisfy { $0.isASCII && $0.isNumber }
    }

    public static func isAcceptable(_ pin: String) -> Bool {
        guard isValidFormat(pin) else { return false }
        let digits = pin.compactMap(\.wholeNumberValue)
        let steps = zip(digits, digits.dropFirst()).map { $1 - $0 }
        let isRepeated = Set(digits).count == 1
        let isSequence = Set(steps).count == 1 && abs(steps[0]) == 1
        return !isRepeated && !isSequence
    }
}
