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
    func onFrameChange(_ f: @escaping (CGRect) -> ()) -> some View {
        overlay(GeometryReader { proxy in
            Color.clear.preference(key: FrameKey.self, value: proxy.frame(in: .global))
        }).onPreferenceChange(FrameKey.self, perform: {
            f($0!)
        })
    }
}

extension CGRect {
    func point(for anchor: UnitPoint) -> CGPoint {
        CGPoint(x: minX + anchor.x * width, y: minY + anchor.y * height)
    }
}

struct MatchedGeometryEffect<ID: Hashable>: ViewModifier {
    var id: ID
    var namespace: Namespace.ID
    var properties: MatchedGeometryProperties
    var anchor: UnitPoint
    var isSource: Bool = true
    @Environment(\.geometryEffectDatabase) var database
    
    var key: GeometryKey {
        GeometryKey(namespace: namespace, id: id)
    }
    
    var frame: CGRect? { database[key] }
    var size: CGSize? {
        guard properties.contains(.size) else { return nil }
        return frame?.size
    }
    
    @State var originalFrame: CGRect = .zero
    
    var offset: CGSize {
        guard let target = frame, properties.contains(.position) else {
            return .zero
        }
        let targetP = target.point(for: anchor)
        let originalP = originalFrame.point(for: anchor)
        return CGSize(width: targetP.x - originalP.x, height: targetP.y - originalP.y)
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
                        self.originalFrame.origin = $0.origin
                    }
                    .hidden()
                    .overlay(
                        content
                            .offset(offset)
                            .onFrameChange {
                                self.originalFrame.size = $0.size
                            }
                            .frame(width: size?.width, height: size?.height, alignment: .topLeading)
                        , alignment: .topLeading
                    )
            }
        }
    }
}

extension View {
    func myMatchedGeometryEffect<ID: Hashable>(useBuiltin: Bool = true, id: ID, in ns: Namespace.ID, properties: MatchedGeometryProperties = .frame, anchor: UnitPoint = .center, isSource: Bool = true) -> some View {
        Group {
            if useBuiltin {
                self.matchedGeometryEffect(id: id, in: ns, properties: properties, anchor: anchor, isSource: isSource)
            } else {
                modifier(MatchedGeometryEffect(id: id, namespace: ns, properties: properties, anchor: anchor, isSource: isSource))
            }
        }
    }
}

struct Sample: View {
    var builtin = true
    var properties: MatchedGeometryProperties
    var anchor: UnitPoint
    @Namespace var ns

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.red)
                .myMatchedGeometryEffect(useBuiltin: builtin, id: "ID", in: ns, properties: properties, anchor: .center)
                .frame(width: 100, height: 100)
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.green)
                .myMatchedGeometryEffect(useBuiltin: builtin, id: "ID", in: ns, properties: properties, anchor: anchor, isSource: false)
                .frame(height: 50)
                .border(Color.blue)
            Circle()
                .fill(Color.blue)
                .frame(width: 25, height: 25)
                .myMatchedGeometryEffect(useBuiltin: builtin, id: "ID", in: ns, properties: properties, anchor: anchor, isSource: false)
            Text("Hello world")
                .myMatchedGeometryEffect(useBuiltin: builtin, id: "ID", in: ns, properties: properties, anchor: anchor, isSource: false)
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

struct ContentView: View {
    @State var properties: MatchedGeometryProperties = .frame
    @State var anchor: UnitPoint = .center
    
    var body: some View {
        VStack {
            Picker("Properties", selection: $properties) {
                Text("Position").tag(MatchedGeometryProperties.position)
                Text("Size").tag(MatchedGeometryProperties.size)
                Text("Frame").tag(MatchedGeometryProperties.frame)
            }
            Slider(value: $anchor.x, in: 0...1, label: { Text("Anchor X")})
            Slider(value: $anchor.y, in: 0...1, label: { Text("Anchor Y")})
            Sample(builtin: true, properties: properties, anchor: anchor)
            Sample(builtin: false, properties: properties, anchor: anchor)
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
