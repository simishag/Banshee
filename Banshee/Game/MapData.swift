import Foundation

struct MapEdge: Hashable {
    let a: Hex
    let b: Hex

    init(_ a: Hex, _ b: Hex) {
        if a.q < b.q || (a.q == b.q && a.r <= b.r) {
            self.a = a
            self.b = b
        } else {
            self.a = b
            self.b = a
        }
    }
}

struct MapData {
    let width: Int
    let height: Int
    let craters: Set<Hex>
    let ridgeEdges: Set<MapEdge>

    static let classic = MapData(
        width: 15,
        height: 22,
        craters: [],
        ridgeEdges: []
    )

    func isInside(_ hex: Hex) -> Bool {
        hex.q >= 0 && hex.q < width && hex.r >= 0 && hex.r < height
    }

    func isBlocked(_ hex: Hex) -> Bool {
        craters.contains(hex)
    }

    func isEdgeBlocked(from: Hex, to: Hex) -> Bool {
        ridgeEdges.contains(MapEdge(from, to))
    }
}
