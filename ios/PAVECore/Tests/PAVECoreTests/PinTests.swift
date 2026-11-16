import Testing
@testable import PAVECore

struct PinPolicyTests {
    @Test(arguments: ["482916", "135790", "908172", "112233", "557799"])
    func acceptsHardToGuessPins(pin: String) {
        #expect(PinPolicy.isAcceptable(pin))
    }

    @Test(arguments: ["000000", "111111", "123456", "654321", "012345", "12345", "1234567", "12a456", "１２３４５６"])
    func rejectsWeakOrMalformedPins(pin: String) {
        #expect(!PinPolicy.isAcceptable(pin))
    }
}

struct PinVaultTests {
    private let vault = PinVault(storage: InMemoryPinStorage())

    @Test func startsWithoutPin() {
        #expect(!vault.hasPin)
        #expect(!vault.isBiometricsEnabled)
        #expect(vault.check("482916") == .lockedOut)
    }

    @Test func acceptsCorrectPinAndRemembersBiometricsChoice() throws {
        try vault.setPin("482916", biometricsEnabled: true)
        #expect(vault.hasPin)
        #expect(vault.isBiometricsEnabled)
        #expect(vault.check("482916") == .correct)
    }

    @Test func rejectsWeakPinWhenSaving() {
        #expect(throws: PinVaultError.unacceptablePin) {
            try vault.setPin("123456", biometricsEnabled: false)
        }
        #expect(!vault.hasPin)
    }

    @Test func countsDownWrongAttemptsThenLocksOut() throws {
        try vault.setPin("482916", biometricsEnabled: false)
        #expect(vault.check("000001") == .incorrect(attemptsRemaining: 4))
        #expect(vault.check("000001") == .incorrect(attemptsRemaining: 3))
        #expect(vault.check("000001") == .incorrect(attemptsRemaining: 2))
        #expect(vault.check("000001") == .incorrect(attemptsRemaining: 1))
        #expect(vault.check("000001") == .lockedOut)
        #expect(!vault.hasPin)
        #expect(vault.check("482916") == .lockedOut)
    }

    @Test func correctPinResetsAttempts() throws {
        try vault.setPin("482916", biometricsEnabled: false)
        _ = vault.check("000001")
        _ = vault.check("000001")
        #expect(vault.check("482916") == .correct)
        #expect(vault.check("000001") == .incorrect(attemptsRemaining: 4))
    }

    @Test func attemptsSurviveANewVaultOnTheSameStorage() throws {
        let storage = InMemoryPinStorage()
        try PinVault(storage: storage).setPin("482916", biometricsEnabled: false)
        _ = PinVault(storage: storage).check("000001")
        #expect(PinVault(storage: storage).check("000001") == .incorrect(attemptsRemaining: 3))
    }

    @Test func settingNewPinReplacesTheOldOne() throws {
        try vault.setPin("482916", biometricsEnabled: false)
        try vault.setPin("908172", biometricsEnabled: false)
        #expect(vault.check("482916") == .incorrect(attemptsRemaining: 4))
        #expect(vault.check("908172") == .correct)
    }

    @Test func remembersWhichAccountOwnsThePin() throws {
        try vault.setPin("482916", biometricsEnabled: false, accountID: "ravi")
        #expect(vault.belongs(to: "ravi"))
        #expect(!vault.belongs(to: "gianna"))
    }

    @Test func clearRemovesThePin() throws {
        try vault.setPin("482916", biometricsEnabled: true)
        vault.clear()
        #expect(!vault.hasPin)
        #expect(!vault.isBiometricsEnabled)
    }
}
