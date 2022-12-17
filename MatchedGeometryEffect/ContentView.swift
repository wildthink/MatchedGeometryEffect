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

typealias GeometryEffectDatabase = [GeometryKey: CGRect]

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
    static var defaultValue: CGRect?
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = value ?? nextValue()
    }
}

extension View {
    func onFrameChange(in cs: CoordinateSpace = .global, _ f: @escaping (CGRect) -> ()) -> some View {
        overlay(GeometryReader { proxy in
            Color.clear.preference(key: FrameKey.self, value: proxy.frame(in: cs))
        }).onPreferenceChange(FrameKey.self, perform: {
            f($0!)
        })
    }
    
//    func measureInitialFrame(in cs: CoordinateSpace = .global,
//                             _ f: @escaping (CGRect) -> ()
//    ) -> some View {
//        overlay(GeometryReader { proxy in
//            Color.clear
//                .onAppear {
//                    f(proxy.frame(in: cs))
//                }
//        })
//    }
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
extension View {
    @ViewBuilder
    func debug() -> some View {
        self
            .overlay(alignment: .center) {
            GeometryReader { g in
                Text(verbatim: "\(g.size)")
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

public func lerp(start: CGPoint, end: CGPoint, t: CGFloat) -> CGPoint {
    return start + (end - start) * t
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
    
    var frame: CGRect? { database[key] }
    
    var size: CGSize? {
        guard properties.contains(.size) else { return nil }
        guard let frame else { return nil }
        return frame.size
    }
    
    var psize: CGSize? {
        guard properties.contains(.size) else { return nil }
        guard let dest = frame?.size else { return nil }
//        let dest = size
        let src = originalFrame.size
        return lerp(start: src, end: dest, t: progress)
//        let dx = abs(originalFrame.width - size.width)
//        let dx = abs (src.width - dest.width)
//        let min_w = min(src.width, dest.width)
//        let max_w = max(src.width, dest.width)
//
//        let d = lerp(start: src, end: dest, t: progress)
//        if dest.width > 0 {
//            print("src", src, "dest", dest, "lerp", d, "dx", dx, dx * progress)
//        }
//        var mid = size
//        mid.width = max_w - (dx * progress)
//
//        return d
     }

//    @State var initialFrame: CGRect = .zero
    @State var originalFrame: CGRect = .zero

    var offset: CGSize {
        guard let target = frame, properties.contains(.position) else {
            return .zero
        }
        let targetP = target.point(for: anchor)
        let originalP = originalFrame.point(for: anchor)
        let size = CGSize(width: targetP.x - originalP.x, height: targetP.y - originalP.y)
//        if !isSource {
//            print(#function, "\(Int(size.width)) x \(Int(size.height))")
//        }
        return size * progress
    }
    
    func body(content: Content) -> some View {
        Group {
            if isSource {
                content
                    .overlay(GeometryReader { proxy in
                        let f = proxy.frame(in: .global)
                        Color.clear.preference(key: GeometryEffectKey.self, value: [key: f])
                    })
            } else {
                content
                    .onFrameChange {
//                        self.originalFrame.origin = $0.origin
                        self.originalFrame = $0
                    }
                    .hidden()
                    .overlay(
                        content
                            .offset(offset)
//                            .onFrameChange {
//                                self.originalFrame.size = $0.size
//                            }
                            .frame(width: psize?.width, height: psize?.height, alignment: .topLeading)
//                            .debug()
                        , alignment: .topLeading
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
                .debug()
                .border(Color.blue)
            Circle()
                .fill(Color.blue)
                .frame(width: 25, height: 25)
                .myMatchedGeometryEffect(useBuiltin: builtin, id: "ID", in: ns, properties: properties, progress: progress, anchor: anchor, isSource: false)
            Text(builtin ? "Old world" : "New World")
                .myMatchedGeometryEffect(useBuiltin: builtin, id: "ID", in: ns, properties: properties, progress: progress, anchor: anchor, isSource: false)
                .border(Color.red)

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
            Text("Builtin")
            Sample(builtin: true, properties: properties, anchor: anchor, active: active, progress: progress)
                .animation(.default, value: active)
            Divider()
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
