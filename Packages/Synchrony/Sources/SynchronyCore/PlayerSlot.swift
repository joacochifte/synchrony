/// Which of the two cooperating players an answer belongs to. Deliberately
/// not "host"/"peer": the domain layer has no concept of network roles.
public enum PlayerSlot: Sendable {
    case one
    case two
}
