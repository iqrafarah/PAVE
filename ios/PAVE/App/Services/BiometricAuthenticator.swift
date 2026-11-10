import LocalAuthentication

enum BiometricKind {
    case faceID
    case touchID

    var name: String {
        switch self {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        }
    }

    var symbolName: String {
        switch self {
        case .faceID: "faceid"
        case .touchID: "touchid"
        }
    }
}

protocol BiometricAuthenticating {
    var kind: BiometricKind? { get }
    func authenticate(reason: String) async -> Bool
}

struct LocalBiometricAuthenticator: BiometricAuthenticating {
    var kind: BiometricKind? {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else { return nil }
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        default: return nil
        }
    }

    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = ""
        return (try? await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)) ?? false
    }
}
