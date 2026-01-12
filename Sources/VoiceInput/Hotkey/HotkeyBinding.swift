import Foundation

struct HotkeyBinding: Codable, Equatable, Identifiable {
    var id: UUID
    var keyCode: Int
    var modifierFlags: UInt

    init(id: UUID = UUID(), keyCode: Int, modifierFlags: UInt) {
        self.id = id
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
    }
}
