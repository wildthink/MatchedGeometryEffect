//
//  ContentView.swift
//  MatchedGeometryEffect
//
//  Created by Chris Eidhof on 25.05.21.
//

import SwiftUI

struct GeometryKey: Hashable {
    var namespace: Namespace.ID
    var id: AnyHashable
}

@dynamicMemberLookup
struct Frame: Equatable {
    var rect: CGRect
    var anchor: UnitPoint
    
    subscript<Value>(dynamicMember key: WritableKeyPath<CGRect,Value>) -> Value {
        get { rect[keyPath: key] }
        set { rect[keyPath: key] = newValue }
    }
    
    var width: CGFloat {
        get { rect.width }
        mutating set { rect.size.width = newValue }
    }
    
    var height: CGFloat {
        get { rect.height }
        mutating set { rect.size.height = newValue }
    }

    var pin: CGPoint { rect.point(for: anchor) }
    var offset: CGSize { .init(width: pin.x, height: pin.y) }

    mutating func set(pin newValue: CGPoint) {
        rect.origin.x = newValue.x + anchor.x * rect.width
        rect.origin.y = newValue.y + anchor.x * rect.height
    }
    
    mutating func move(pin newValue: CGSize) {
        rect.origin.x = newValue.width + anchor.x * rect.width
        rect.origin.y = newValue.height + anchor.x * rect.height
    }

}

extension Frame {
    static var zero: Frame { Frame(.zero) }
    
    init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, anchor: UnitPoint = .center) {
        self.init(origin: .init(x: x, y: y), size: .init(width: width, height: height))
    }

    init(origin: CGPoint, size: CGSize, anchor: UnitPoint = .center) {
        rect = .init(origin: origin, size: size)
        self.anchor = anchor
    }
    
    init(_ rect: CGRect, anchor: UnitPoint = .center) {
        self.rect = rect
        self.anchor = anchor
    }
}

typealias GeometryEffectDatabase = [GeometryKey: Frame]

struct GeometryEffectKey: PreferenceKey, EnvironmentKey {
    static var defaultValue: GeometryEffectDatabase = [:]
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue(), uniquingKeysWith: {
            print("Duplicate isSource views")
            return $1
        })
    }
}

extension EnvironmentValues {
    var geometryEffectDatabase: GeometryEffectKey.Value {
        get { self[GeometryEffectKey.self] }
        set { self[GeometryEffectKey.self] = newValue }
    }
}

struct FrameKey: PreferenceKey {
    static var defaultValue: Frame?
    static func reduce(value: inout Frame?, nextValue: () -> Frame?) {
        value = value ?? nextValue()
    }
}

extension View {
    func onFrameChange(
        in cs: CoordinateSpace = .global,
        anchor: UnitPoint,
        _ f: @escaping (Frame) -> ()
    ) -> some View {
        overlay(GeometryReader { proxy in
            Color.clear.preference(key: FrameKey.self,
                                   value: Frame(proxy.frame(in: cs), anchor: anchor))
        }).onPreferenceChange(FrameKey.self, perform: {
            f($0!)
        })
    }
}

extension CGRect: CustomStringConvertible {
    public var description: String {
        "[\(origin) \(size)]"
    }

    func point(for anchor: UnitPoint) -> CGPoint {
        CGPoint(x: minX + anchor.x * width, y: minY + anchor.y * height)
    }
}

// jmj

extension UnitPoint {
    static func *(size: CGSize, scale: UnitPoint) -> CGSize {
        .init(width: size.width * scale.x, height: size.height * scale.y)
    }
}

extension View {
    func position(_ size: CGSize) -> some View {
        self.position(x: size.width, y: size.height)
    }
}

extension View {
    @ViewBuilder
    func debug(_ anchor: UnitPoint = .center, in f: Frame? = .zero) -> some View {
        let f = f ?? .zero
        self
            .overlay(alignment: .center) {
            GeometryReader { g in
                ZStack {
                    VStack {
                        Text(verbatim: "\(g.size)")
                        Text(verbatim: "\(g.frame(in: .global).origin)")
                        Spacer()
                    }
                    Circle().fill(.blue)
                        .frame(width: 10, height: 10)
                        .position(g.size * f.anchor)
                }
                .frame(width: g.size.width, height: g.size.height)
                .border(.cyan)
            }
        }
    }
}

extension CGPoint: CustomStringConvertible {
    public var description: String {
        "\(Int(x)):\(Int(y))"
    }

    static func *(lhs: CGPoint, scale: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x * scale, y: lhs.y * scale)
    }
    
    static func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

}

extension CGSize: CustomStringConvertible {
    public var description: String {
        "\(Int(width))x\(Int(height))"
    }
    
    static func *(lhs: Self, scale: CGFloat) -> Self {
        Self.init(width: lhs.width * scale, height: lhs.height * scale)
    }
    
    static func +(lhs: Self, rhs: Self) -> Self {
        Self(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }
    
    static func -(lhs: Self, rhs: Self) -> Self {
        Self(width: lhs.width - rhs.width, height: lhs.height - rhs.height)
    }

}

extension CGRect {
    static func *(lhs: Self, scale: CGFloat) -> Self {
        Self.init(origin: lhs.origin * scale, size: lhs.size * scale)
    }
}

public func lerp(start: CGPoint, end: CGPoint, t: CGFloat) -> CGSize {
    let pt = start + (end - start) * t
    return CGSize(width: pt.x, height: pt.y)
}

public func lerp(start: CGSize, end: CGSize, t: CGFloat) -> CGSize {
    return start + (end - start) * t
}

// jmj end

struct MatchedGeometryEffect<ID: Hashable>: ViewModifier {
    var id: ID
    var namespace: Namespace.ID
    var properties: MatchedGeometryProperties
    var anchor: UnitPoint
    var isSource: Bool = true
    var progress: CGFloat = 0.5
    
    @Environment(\.geometryEffectDatabase) var database
    
    var key: GeometryKey {
        GeometryKey(namespace: namespace, id: id)
    }
    
    var frame: Frame? { database[key] }
    
    var pframe: Frame? {
        guard var target = frame else { return nil }
        let src = originalFrame

        if properties.contains(.size) {
            target.size = lerp(start: src.size, end: target.size, t: progress)
        }
        if properties.contains(.position) {
            target.move(pin: lerp(start: src.pin, end: target.pin, t: progress))
        }
        return target
    }

    var size: CGSize? {
        guard properties.contains(.size) else { return nil }
        guard let target = frame?.size else { return nil }
        let src = originalFrame.size
        return lerp(start: src, end: target, t: progress)
     }

    @State var originalFrame: Frame = .zero

    var offset: CGSize {
        guard properties.contains(.position) else { return .zero }
//        guard let target = frame?.pin else { return .zero }
//        let src = originalFrame.pin
//        return CGSize(width: target.x - src.x, height: target.y - src.y) * progress
        
        guard var target = frame else { return .zero }
        let src = originalFrame
//        target.rect.size = self.size ?? target.size
        let pt = target.pin - src.pin
        return CGSize(width: pt.x, height: pt.y) * progress
    }
    
    func body(content: Content) -> some View {
        Group {
            if isSource {
                content
                    .overlay(GeometryReader { proxy in
                        let f = Frame(proxy.frame(in: .global), anchor: anchor)
                        Color.clear.preference(key: GeometryEffectKey.self, value: [key: f])
                    })
            } else {
                content
                    .onFrameChange(anchor: anchor) {
                        self.originalFrame = $0
                    }
                    .hidden()
                    .overlay(
                        content
                            .debug(anchor)
                            .frame(width: size?.width, height: size?.height)
                            .offset(offset)
                    )
            }
        }
    }
}

extension View {
    func myMatchedGeometryEffect<ID: Hashable>(
        useBuiltin: Bool = true,
        id: ID, in ns: Namespace.ID,
        properties: MatchedGeometryProperties = .frame,
        progress: CGFloat = 1.0,
        anchor: UnitPoint = .center,
        isSource: Bool = true
    ) -> some View {
        Group {
            if useBuiltin {
                self.matchedGeometryEffect(id: id, in: ns, properties: properties, anchor: anchor, isSource: isSource)
            } else {
                modifier(MatchedGeometryEffect(id: id, namespace: ns, properties: properties, anchor: anchor, isSource: isSource, progress: progress))
            }
        }
    }
}

struct Sample: View {
    var builtin = true
    var properties: MatchedGeometryProperties
    var anchor: UnitPoint
    var active = true
    var progress: CGFloat = 1.0
    @Namespace var ns
    @Namespace var out

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.red)
                .myMatchedGeometryEffect(useBuiltin: builtin, id: "ID", in: active ? ns : out, properties: properties, progress: progress, anchor: .center)
                .frame(width: 100, height: 100)
                .debug()
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.green)
                .myMatchedGeometryEffect(useBuiltin: builtin, id: "ID", in: ns, properties: properties, progress: progress, anchor: anchor, isSource: false)
                .frame(height: 50)
//                .debug(anchor)
                .border(Color.blue)
//            Circle()
//                .fill(Color.blue)
//                .frame(width: 25, height: 25)
//                .myMatchedGeometryEffect(useBuiltin: builtin, id: "ID", in: ns, properties: properties, progress: progress, anchor: anchor, isSource: false)
//            Text(builtin ? "Old world" : "New World")
//                .myMatchedGeometryEffect(useBuiltin: builtin, id: "ID", in: ns, properties: properties, progress: progress, anchor: anchor, isSource: false)
//                .border(Color.red)

        }.frame(height: 100)
    }
}

struct ApplyGeometryEffects: ViewModifier {
    @State var database: GeometryEffectDatabase = [:]
    
    func body(content: Content) -> some View {
        content
            .environment(\.geometryEffectDatabase, database)
            .onPreferenceChange(GeometryEffectKey.self) {
                database = $0
            }
    }
}

extension MatchedGeometryProperties: Hashable {}

enum AnchorStop: Hashable, Identifiable, CaseIterable {
    case center
    case top, bottom, leading, trailing
    case topLeading, topTrailing
    case bottomLeading, bottomTrailing
    
    var id: Self { self }
    
    var anchor: UnitPoint {
        switch self {
            case .center: return .center
            case .top:  return .top
            case .bottom: return .bottom
            case .leading: return .leading
            case .trailing: return .trailing
            case .topLeading: return .topLeading
            case .topTrailing: return .topTrailing
            case .bottomLeading: return .bottomLeading
            case .bottomTrailing: return .bottomTrailing
        }
    }
}

struct ContentView: View {
    @State var properties: MatchedGeometryProperties = .frame
    @State var anchor: UnitPoint = .center
    @State var stop: AnchorStop = .center
    @State var active = true
    @State var progress: CGFloat = 1

    var body: some View {
        VStack {
            HStack {
                Picker("Properties", selection: $properties) {
                    Text("Position").tag(MatchedGeometryProperties.position)
                    Text("Size").tag(MatchedGeometryProperties.size)
                    Text("Frame").tag(MatchedGeometryProperties.frame)
                }
                Picker("Unit Stops", selection: $stop) {
                    ForEach(AnchorStop.allCases) {
                        Text(verbatim: "\($0)").tag($0.id)
                    }
                }
                .onChange(of: stop) {
                    anchor = $0.anchor
                }
            }
            Group {
                Toggle("Active", isOn: $active)
                Slider(value: $progress, in: 0...1, label: { Text("Progress")})
                Slider(value: $anchor.x, in: 0...1, label: { Text("Anchor X")})
                Slider(value: $anchor.y, in: 0...1, label: { Text("Anchor Y")})
            }
            Divider()
//            Text("Builtin")
//            Sample(builtin: true, properties: properties, anchor: anchor, active: active, progress: progress)
//                .animation(.default, value: active)
//            Divider()
            Text("Custom")
            Sample(builtin: false, properties: properties, anchor: anchor, active: active, progress: progress)
                .animation(.default, value: active)
        }
        .modifier(ApplyGeometryEffects())
        .padding(100)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
