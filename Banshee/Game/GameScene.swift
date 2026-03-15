import SpriteKit

final class GameScene: SKScene {
    private weak var gameState: GameState?
    private let hexInnerRadius: CGFloat = 32
    private var unitNodes: [UUID: SKNode] = [:]
    private var ogreNode: SKNode?
    private var selectionNode: SKShapeNode?
    private var mapBounds: CGRect = .zero
    private let showHexCoords = true
    private var highlightNodes: [SKShapeNode] = []
    private let cameraNode = SKCameraNode()
    
    private let SQRT_3: CGFloat = sqrt(3.0)
    private let THREE_HALFS: CGFloat = 3.0/2.0

    func bind(to gameState: GameState) {
        self.gameState = gameState
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.08, green: 0.1, blue: 0.12, alpha: 1.0)
        ensureCamera()
        buildMap()
        syncUnits()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        ensureCamera()
        buildMap()
        syncUnits()
    }

    private func buildMap() {
        removeAllChildren()
        unitNodes.removeAll()
        ogreNode = nil

        guard let map = gameState?.map else { return }
        mapBounds = computeMapBounds(map)
        ensureCamera()

        let gridNode = SKShapeNode()
        let path = CGMutablePath()
        let labelNode = SKNode()
        
        let cutoff = (map.width / 2) + (map.width % 2)

        for q in 0..<map.width {
        //for q in 1...map.width {
            for r in 0..<map.height+cutoff {
            //for r in 1...map.height+cutoff {
            
                //let trueR = offset - q + (q % 2)
                let modBump = max(((q-1) % 2), 0)
                //let minBump = min((q-1) / 2, 1)
                let qBump = (q-1) / 2
                let offset = cutoff - qBump - modBump
                
                //let realQ = max(q-1, 0)
                
                let minR = offset - (q % 2)
                let maxR = map.height + offset //- max(((q-1) % 2), 0)
                
                if (q < 6 && r >= minR && r < (minR + 6)) {
                    print("trueR: \(q), \(r) --- \(qBump), \(modBump), \(offset) --- \(minR), \(maxR)")
                    //print("trueR: \(q), \(r) --- \(minR), \(maxR)")
                }
                
                if (r >= minR && r < maxR) {
                    let center = hexToPixel(Hex(q: q, r: r))
                    let hexPath = hexPathAt(center: center)
                    path.addPath(hexPath)
                    if showHexCoords {
                        //let s = -q-r
                        let label = SKLabelNode(text: "(\(q),\(r)")
                        label.fontSize = 12
                        label.fontColor = SKColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 0.8)
                        label.verticalAlignmentMode = .center
                        label.horizontalAlignmentMode = .center
                        label.position = center
                        labelNode.addChild(label)
                    }
                }
            }
        }
        gridNode.path = path
        gridNode.strokeColor = SKColor(white: 1.0, alpha: 0.12)
        gridNode.lineWidth = 1
        addChild(gridNode)
        if showHexCoords {
            addChild(labelNode)
        }
        
        // draw horizontal line across bottom
        var bottomR = 8
        for q in 0..<map.width {
            if q % 2 == 1 {
                bottomR -= 1
            }
            //print("\(q), \(bottomR)")
        }

        let craterNode = SKNode()
        for crater in map.craters {
            let center = hexToPixel(crater)
            let shape = SKShapeNode(circleOfRadius: hexOuterRadius() * 0.35)
            //let shape = SKShapeNode(circleOfRadius: hexInnerRadius * 0.35)
            shape.position = center
            shape.fillColor = SKColor(red: 0.2, green: 0.18, blue: 0.18, alpha: 1)
            shape.strokeColor = SKColor(red: 0.3, green: 0.25, blue: 0.25, alpha: 1)
            craterNode.addChild(shape)
        }
        addChild(craterNode)
    }

    func syncUnits() {
        guard let gameState else { return }

        let existingIDs = Set(gameState.units.map { $0.id })
        for unit in gameState.units {
            if unit.status == .destroyed {
                if let node = unitNodes[unit.id] {
                    node.removeFromParent()
                    unitNodes[unit.id] = nil
                }
                continue
            }
            if unitNodes[unit.id] == nil {
                let node = makeUnitNode(unit)
                unitNodes[unit.id] = node
                addChild(node)
            }
            updateUnitNode(unit)
        }

        for (id, node) in unitNodes where !existingIDs.contains(id) {
            node.removeFromParent()
            unitNodes[id] = nil
        }

        if let ogre = gameState.ogre {
            if ogreNode == nil {
                ogreNode = makeOgreNode()
                if let node = ogreNode {
                    addChild(node)
                }
            }
            if let node = ogreNode {
                node.position = hexToPixel(ogre.position)
            }
        }
        updateSelection()
    }

    func updateSelection() {
        selectionNode?.removeFromParent()
        selectionNode = nil
        guard let gameState else { return }

        if let selectedID = gameState.selectedUnitID {
            if let node = unitNodes[selectedID] {
                selectionNode = highlightNode(at: node.position)
            } else if let ogre = gameState.ogre, ogre.id == selectedID, let node = ogreNode {
                selectionNode = highlightNode(at: node.position)
            }
        }
    }

    func updateHighlightHexes(_ hexes: [Hex]) {
        highlightNodes.forEach { $0.removeFromParent() }
        highlightNodes.removeAll()
        guard !hexes.isEmpty else { return }
        for hex in hexes {
            let center = hexToPixel(hex)
            let shape = SKShapeNode(path: hexPathAt(center: center))
            shape.strokeColor = SKColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 0.5)
            shape.lineWidth = 2
            addChild(shape)
            highlightNodes.append(shape)
        }
    }

    func setCameraScale(_ scale: CGFloat) {
        ensureCamera()
        cameraNode.setScale(scale)
    }

    func panCamera(by delta: CGPoint) {
        ensureCamera()
        cameraNode.position = CGPoint(
            x: cameraNode.position.x - delta.x * cameraNode.xScale,
            y: cameraNode.position.y - delta.y * cameraNode.yScale
        )
    }

    func animateUnitMove(unitID: UUID) {
        guard let node = unitNodes[unitID], let unit = gameState?.units.first(where: { $0.id == unitID }) else { return }
        let target = hexToPixel(unit.position)
        node.run(SKAction.move(to: target, duration: 0.25))
    }

    func animateOgreMove() {
        guard let ogre = gameState?.ogre, let node = ogreNode else { return }
        let target = hexToPixel(ogre.position)
        node.run(SKAction.move(to: target, duration: 0.35))
    }

    func animateAttack(from: Hex, to: Hex, result: CombatResult) {
        let start = hexToPixel(from)
        let end = hexToPixel(to)

        let beam = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        beam.path = path
        beam.strokeColor = result == .destroyed ? .red : .yellow
        beam.lineWidth = 3
        addChild(beam)

        beam.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.removeFromParent()
        ]))
    }

    func animateRamming(from: Hex, to: Hex) {
        animateAttack(from: from, to: to, result: .destroyed)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self), let gameState else { return }
        let hex = pixelToHex(location)
        gameState.handleHexTap(hex)
        syncUnits()
    }

    private func makeUnitNode(_ unit: Unit) -> SKNode {
        let size = hexOuterRadius() * 0.6
        let shape = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: 6)
        shape.fillColor = color(for: unit.type)
        shape.strokeColor = .white
        let label = SKLabelNode(text: unit.type.displayName.prefix(1).uppercased())
        label.fontSize = 12
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        shape.addChild(label)
        return shape
    }

    private func updateUnitNode(_ unit: Unit) {
        guard let node = unitNodes[unit.id] else { return }
        node.position = hexToPixel(unit.position)
        node.alpha = unit.status == .disabled ? 0.6 : 1.0
    }

    private func makeOgreNode() -> SKNode {
        let size = hexOuterRadius() * 0.9
        let shape = SKShapeNode(rectOf: CGSize(width: size * 1.3, height: size), cornerRadius: 8)
        shape.fillColor = SKColor(red: 0.6, green: 0.1, blue: 0.1, alpha: 1)
        shape.strokeColor = .white
        let label = SKLabelNode(text: "OGRE")
        label.fontSize = 12
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        shape.addChild(label)
        return shape
    }

    private func color(for type: UnitType) -> SKColor {
        switch type {
        case .heavyTank: return SKColor(red: 0.2, green: 0.6, blue: 0.4, alpha: 1)
        case .missileTank: return SKColor(red: 0.2, green: 0.45, blue: 0.7, alpha: 1)
        case .gev: return SKColor(red: 0.7, green: 0.6, blue: 0.2, alpha: 1)
        case .howitzer: return SKColor(red: 0.5, green: 0.3, blue: 0.2, alpha: 1)
        case .infantry: return SKColor(red: 0.2, green: 0.5, blue: 0.2, alpha: 1)
        case .commandPost: return SKColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)
        }
    }

    private func highlightNode(at position: CGPoint) -> SKShapeNode {
        let ring = SKShapeNode(circleOfRadius: hexOuterRadius() * 0.7)
        ring.position = position
        ring.strokeColor = .yellow
        ring.lineWidth = 2
        addChild(ring)
        return ring
    }

    private func hexToPixel(_ hex: Hex) -> CGPoint {
        let raw = axialToPixel(hex)
        let origin = CGPoint(x: frame.midX - mapBounds.midX, y: frame.midY - mapBounds.midY)
        return CGPoint(x: origin.x + raw.x, y: origin.y + raw.y)
    }

    private func pixelToHex(_ point: CGPoint) -> Hex {
        let origin = CGPoint(x: frame.midX - mapBounds.midX, y: frame.midY - mapBounds.midY)
        let pt = CGPoint(x: point.x - origin.x, y: point.y - origin.y)
        let outer = hexOuterRadius()
        
        let q = (SQRT_3 / 3 * pt.x - 1.0 / 3 * pt.y) / outer
        let r = (2.0 / 3 * pt.y) / outer
        
        return hexRound(q: q, r: r)
    }

    private func hexRound(q: CGFloat, r: CGFloat) -> Hex {
        let x = q
        let z = r
        let y = -x - z

        var rx = round(x)
        var ry = round(y)
        var rz = round(z)

        let xDiff = abs(rx - x)
        let yDiff = abs(ry - y)
        let zDiff = abs(rz - z)

        if xDiff > yDiff && xDiff > zDiff {
            rx = -ry - rz
        } else if yDiff > zDiff {
            ry = -rx - rz
        } else {
            rz = -rx - ry
        }
        let cube = Hex.Cube(x: Int(rx), y: Int(ry), z: Int(rz))
        return Hex.offsetFromCube(cube)
    }

    private func hexPathAt(center: CGPoint) -> CGPath {
        let path = CGMutablePath()
        let corners = hexCorners(center: center)
        path.move(to: corners[0])
        for corner in corners.dropFirst() {
            path.addLine(to: corner)
        }
        path.closeSubpath()
        return path
    }

    private func hexCorners(center: CGPoint) -> [CGPoint] {
        //let outer = hexOuterRadius()
        let outer = hexInnerRadius
        let corners = (0..<6).map { i in
            let angle = CGFloat.pi / 180 * (60 * CGFloat(i))
            //return CGPoint(
            return CGPoint(
                x: center.x + outer * cos(angle),
                y: center.y + outer * sin(angle)
            )
        }
        return corners
    }

    private func axialToPixel(_ hex: Hex) -> CGPoint {
        let x = hexInnerRadius * 3.0/2.0 * CGFloat(hex.q)
        let y = hexInnerRadius * (SQRT_3/2.0 * CGFloat(hex.q) + SQRT_3 * CGFloat(hex.r)) - 1
        
        if (hex.q == 0) {
            //print("\(hex.q) \(hex.r) --- \(x) \(y)")
        }
        //test
        //let y = hexInnerRadius * (SQRT_3/2.0 * CGFloat(hex.q) + SQRT_3 * CGFloat(hex.r))
        
        return CGPoint(x: x, y: y)
    }

    private func hexOuterRadius() -> CGFloat {
        hexInnerRadius * 2.0 / SQRT_3
    }

    private func computeMapBounds(_ map: MapData) -> CGRect {
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for r in 0..<map.height {
            for q in 0..<map.width {
                let center = axialToPixel(Hex(q: q, r: r))
                minX = min(minX, center.x)
                minY = min(minY, center.y)
                maxX = max(maxX, center.x)
                maxY = max(maxY, center.y)
            }
        }

        let padding = hexOuterRadius()
        return CGRect(
            x: minX - padding,
            y: minY - padding,
            width: (maxX - minX) + padding * 2,
            height: (maxY - minY) + padding * 2
        )
    }

    private func ensureCamera() {
        if camera == nil {
            camera = cameraNode
        }
        if cameraNode.parent == nil {
            addChild(cameraNode)
        }
    }
}
