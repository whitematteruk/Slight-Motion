enum ScrollAxis: Sendable, Equatable {
    case horizontal
    case vertical
}

/// Positive movement follows the user's physical right or up direction.
struct ScrollMovement: Sendable, Equatable {
    let axis: ScrollAxis
    let pixels: Int
}
