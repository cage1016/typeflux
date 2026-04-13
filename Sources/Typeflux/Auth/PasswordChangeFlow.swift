enum PasswordChangeDialog: String, Identifiable {
    case form
    case successConfirmation

    var id: String {
        rawValue
    }
}

struct PasswordChangeFlow: Equatable {
    private(set) var activeDialog: PasswordChangeDialog?

    mutating func presentForm() {
        activeDialog = .form
    }

    mutating func showSuccessConfirmation() {
        activeDialog = .successConfirmation
    }

    mutating func dismiss() {
        activeDialog = nil
    }
}
