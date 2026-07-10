//
//  DoodleIcons.swift
//  Leftover
//
//  The hand-drawn icon set. Every icon is line art defined in a unit
//  square, run through a deterministic wobble so strokes look sketched
//  — same doodle every render, crisp at any size.
//

import SwiftUI

enum Doodle: CaseIterable {
    case sparkle      // Memory Burst
    case screenshot   // Screenshots
    case clock        // Time Capsule
    case stack        // Similar Shots
    case duplicate    // Duplicates
    case blur         // Blurry
    case film         // Large Videos
    case folder       // Albums
    case trash, undo, star, check, cross, gear, flame
}

struct DoodleIcon: View {
    let kind: Doodle
    var lineWidth: CGFloat = 1.8

    var body: some View {
        DoodleShape(kind: kind)
            .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }
}

struct DoodleShape: Shape {
    let kind: Doodle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var seed = kind.hashValue & 0xFFFF
        for polyline in Self.art(for: kind) {
            seed += 13
            Self.sketch(polyline, seed: seed, in: &path, rect: rect)
        }
        return path
    }

    /// Subdivides each segment and nudges points perpendicular by a
    /// deterministic pseudo-random amount — the hand wobble.
    private static func sketch(_ points: [CGPoint], seed: Int, in path: inout Path, rect: CGRect) {
        guard points.count > 1 else { return }
        func map(_ p: CGPoint) -> CGPoint {
            CGPoint(x: rect.minX + p.x * rect.width, y: rect.minY + p.y * rect.height)
        }
        var wob = seed
        func jitter() -> CGFloat {
            wob = (wob &* 1103515245 &+ 12345) & 0x7FFFFFFF
            return (CGFloat(wob % 1000) / 1000 - 0.5) * rect.width * 0.045
        }

        var started = false
        for i in 0..<(points.count - 1) {
            let a = map(points[i]), b = map(points[i + 1])
            let dx = b.x - a.x, dy = b.y - a.y
            let len = max(sqrt(dx * dx + dy * dy), 0.001)
            let (nx, ny) = (-dy / len, dx / len)
            let steps = max(Int(len / (rect.width * 0.25)), 1)
            if !started {
                path.move(to: a)
                started = true
            }
            for s in 1...steps {
                let t = CGFloat(s) / CGFloat(steps)
                let mid = CGPoint(x: a.x + dx * t, y: a.y + dy * t)
                let j = (s == steps && i == points.count - 2) ? 0 : jitter()
                path.addLine(to: CGPoint(x: mid.x + nx * j, y: mid.y + ny * j))
            }
        }
    }

    private static func circle(cx: CGFloat, cy: CGFloat, r: CGFloat, segments: Int = 14) -> [CGPoint] {
        (0...segments).map { i in
            let a = CGFloat(i) / CGFloat(segments) * 2 * .pi - .pi / 2
            return CGPoint(x: cx + cos(a) * r, y: cy + sin(a) * r)
        }
    }

    private static func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> [CGPoint] {
        [CGPoint(x: x, y: y), CGPoint(x: x + w, y: y), CGPoint(x: x + w, y: y + h),
         CGPoint(x: x, y: y + h), CGPoint(x: x, y: y)]
    }

    /// Line art per icon, polylines in unit coordinates.
    private static func art(for kind: Doodle) -> [[CGPoint]] {
        switch kind {
        case .sparkle:
            return [
                [CGPoint(x: 0.5, y: 0.08), CGPoint(x: 0.58, y: 0.42), CGPoint(x: 0.92, y: 0.5),
                 CGPoint(x: 0.58, y: 0.58), CGPoint(x: 0.5, y: 0.92), CGPoint(x: 0.42, y: 0.58),
                 CGPoint(x: 0.08, y: 0.5), CGPoint(x: 0.42, y: 0.42), CGPoint(x: 0.5, y: 0.08)],
                [CGPoint(x: 0.82, y: 0.12), CGPoint(x: 0.82, y: 0.26)],
                [CGPoint(x: 0.75, y: 0.19), CGPoint(x: 0.89, y: 0.19)],
            ]
        case .screenshot:
            return [
                rect(0.3, 0.12, 0.4, 0.76),
                [CGPoint(x: 0.42, y: 0.8), CGPoint(x: 0.58, y: 0.8)],
                [CGPoint(x: 0.12, y: 0.3), CGPoint(x: 0.12, y: 0.12), CGPoint(x: 0.24, y: 0.12)],
                [CGPoint(x: 0.88, y: 0.7), CGPoint(x: 0.88, y: 0.88), CGPoint(x: 0.76, y: 0.88)],
            ]
        case .clock:
            return [
                circle(cx: 0.5, cy: 0.5, r: 0.38),
                [CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.5, y: 0.26)],
                [CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.68, y: 0.6)],
            ]
        case .stack:
            return [
                rect(0.14, 0.3, 0.5, 0.5),
                [CGPoint(x: 0.3, y: 0.3), CGPoint(x: 0.32, y: 0.18), CGPoint(x: 0.8, y: 0.24),
                 CGPoint(x: 0.76, y: 0.72), CGPoint(x: 0.64, y: 0.7)],
            ]
        case .duplicate:
            return [
                rect(0.14, 0.14, 0.5, 0.5),
                [CGPoint(x: 0.64, y: 0.36), CGPoint(x: 0.86, y: 0.36), CGPoint(x: 0.86, y: 0.86),
                 CGPoint(x: 0.36, y: 0.86), CGPoint(x: 0.36, y: 0.64)],
            ]
        case .blur:
            return [
                rect(0.14, 0.14, 0.72, 0.72),
                [CGPoint(x: 0.28, y: 0.42), CGPoint(x: 0.42, y: 0.34), CGPoint(x: 0.56, y: 0.44),
                 CGPoint(x: 0.72, y: 0.36)],
                [CGPoint(x: 0.28, y: 0.62), CGPoint(x: 0.44, y: 0.54), CGPoint(x: 0.58, y: 0.66),
                 CGPoint(x: 0.72, y: 0.58)],
            ]
        case .film:
            return [
                rect(0.12, 0.2, 0.76, 0.6),
                [CGPoint(x: 0.28, y: 0.2), CGPoint(x: 0.28, y: 0.8)],
                [CGPoint(x: 0.72, y: 0.2), CGPoint(x: 0.72, y: 0.8)],
                [CGPoint(x: 0.12, y: 0.4), CGPoint(x: 0.28, y: 0.4)],
                [CGPoint(x: 0.12, y: 0.6), CGPoint(x: 0.28, y: 0.6)],
                [CGPoint(x: 0.72, y: 0.4), CGPoint(x: 0.88, y: 0.4)],
                [CGPoint(x: 0.72, y: 0.6), CGPoint(x: 0.88, y: 0.6)],
                [CGPoint(x: 0.44, y: 0.42), CGPoint(x: 0.6, y: 0.5), CGPoint(x: 0.44, y: 0.58),
                 CGPoint(x: 0.44, y: 0.42)],
            ]
        case .folder:
            return [
                [CGPoint(x: 0.1, y: 0.82), CGPoint(x: 0.1, y: 0.26), CGPoint(x: 0.38, y: 0.26),
                 CGPoint(x: 0.46, y: 0.36), CGPoint(x: 0.9, y: 0.36), CGPoint(x: 0.9, y: 0.82),
                 CGPoint(x: 0.1, y: 0.82)],
            ]
        case .trash:
            return [
                [CGPoint(x: 0.2, y: 0.26), CGPoint(x: 0.8, y: 0.26)],
                [CGPoint(x: 0.4, y: 0.26), CGPoint(x: 0.42, y: 0.14), CGPoint(x: 0.58, y: 0.14),
                 CGPoint(x: 0.6, y: 0.26)],
                [CGPoint(x: 0.26, y: 0.26), CGPoint(x: 0.32, y: 0.88), CGPoint(x: 0.68, y: 0.88),
                 CGPoint(x: 0.74, y: 0.26)],
                [CGPoint(x: 0.44, y: 0.4), CGPoint(x: 0.45, y: 0.74)],
                [CGPoint(x: 0.58, y: 0.4), CGPoint(x: 0.57, y: 0.74)],
            ]
        case .undo:
            return [
                [CGPoint(x: 0.78, y: 0.72), CGPoint(x: 0.82, y: 0.5), CGPoint(x: 0.68, y: 0.32),
                 CGPoint(x: 0.44, y: 0.28), CGPoint(x: 0.26, y: 0.4), CGPoint(x: 0.2, y: 0.56)],
                [CGPoint(x: 0.2, y: 0.56), CGPoint(x: 0.12, y: 0.4)],
                [CGPoint(x: 0.2, y: 0.56), CGPoint(x: 0.38, y: 0.54)],
            ]
        case .star:
            return [
                [CGPoint(x: 0.5, y: 0.1), CGPoint(x: 0.62, y: 0.38), CGPoint(x: 0.92, y: 0.4),
                 CGPoint(x: 0.68, y: 0.6), CGPoint(x: 0.78, y: 0.9), CGPoint(x: 0.5, y: 0.72),
                 CGPoint(x: 0.22, y: 0.9), CGPoint(x: 0.32, y: 0.6), CGPoint(x: 0.08, y: 0.4),
                 CGPoint(x: 0.38, y: 0.38), CGPoint(x: 0.5, y: 0.1)],
            ]
        case .check:
            return [
                [CGPoint(x: 0.14, y: 0.55), CGPoint(x: 0.4, y: 0.8), CGPoint(x: 0.88, y: 0.22)],
            ]
        case .cross:
            return [
                [CGPoint(x: 0.2, y: 0.2), CGPoint(x: 0.8, y: 0.8)],
                [CGPoint(x: 0.8, y: 0.2), CGPoint(x: 0.2, y: 0.8)],
            ]
        case .gear:
            var lines = [circle(cx: 0.5, cy: 0.5, r: 0.22)]
            for i in 0..<8 {
                let a = CGFloat(i) / 8 * 2 * .pi
                lines.append([
                    CGPoint(x: 0.5 + cos(a) * 0.3, y: 0.5 + sin(a) * 0.3),
                    CGPoint(x: 0.5 + cos(a) * 0.42, y: 0.5 + sin(a) * 0.42),
                ])
            }
            return lines
        case .flame:
            return [
                [CGPoint(x: 0.5, y: 0.1), CGPoint(x: 0.26, y: 0.4), CGPoint(x: 0.24, y: 0.66),
                 CGPoint(x: 0.4, y: 0.88), CGPoint(x: 0.62, y: 0.88), CGPoint(x: 0.76, y: 0.66),
                 CGPoint(x: 0.72, y: 0.42), CGPoint(x: 0.58, y: 0.26), CGPoint(x: 0.5, y: 0.1)],
                [CGPoint(x: 0.5, y: 0.56), CGPoint(x: 0.42, y: 0.7), CGPoint(x: 0.5, y: 0.8),
                 CGPoint(x: 0.58, y: 0.7), CGPoint(x: 0.5, y: 0.56)],
            ]
        }
    }
}

/// A rounded rectangle that looks sketched by hand — used for card and
/// button borders across the doodle theme.
struct SketchyRoundedRectangle: Shape {
    var cornerRadius: CGFloat = 16
    var seed: Int = 7

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        var pts: [CGPoint] = []

        func arc(cx: CGFloat, cy: CGFloat, from: CGFloat, to: CGFloat) {
            for i in 0...4 {
                let a = from + (to - from) * CGFloat(i) / 4
                pts.append(CGPoint(x: cx + cos(a) * r, y: cy + sin(a) * r))
            }
        }
        pts.append(CGPoint(x: rect.minX + r, y: rect.minY))
        pts.append(CGPoint(x: rect.maxX - r, y: rect.minY))
        arc(cx: rect.maxX - r, cy: rect.minY + r, from: -.pi / 2, to: 0)
        pts.append(CGPoint(x: rect.maxX, y: rect.maxY - r))
        arc(cx: rect.maxX - r, cy: rect.maxY - r, from: 0, to: .pi / 2)
        pts.append(CGPoint(x: rect.minX + r, y: rect.maxY))
        arc(cx: rect.minX + r, cy: rect.maxY - r, from: .pi / 2, to: .pi)
        pts.append(CGPoint(x: rect.minX, y: rect.minY + r))
        arc(cx: rect.minX + r, cy: rect.minY + r, from: .pi, to: 3 * .pi / 2)

        var path = Path()
        var wob = seed
        func jitter() -> CGFloat {
            wob = (wob &* 1103515245 &+ 12345) & 0x7FFFFFFF
            return (CGFloat(wob % 1000) / 1000 - 0.5) * 2.4
        }
        path.move(to: pts[0])
        for p in pts.dropFirst() {
            path.addLine(to: CGPoint(x: p.x + jitter(), y: p.y + jitter()))
        }
        path.closeSubpath()
        return path
    }
}
