import SwiftUI
import AppKit

enum AgentState: String {
    case idle
    case working
    case waiting
}

struct BrandIcons {
    // MARK: - Clawd (Official Claude Character Animated Frames)

    private static let clawdBaseBody = """
      <path fill="#D97757" d="M32 56h104v8h-104zM32 64h104v8h-104zM32 72h104v8h-104zM32 80h104v8h-104zM16 88h120v8h-120zM16 96h120v8h-120zM32 104h104v8h-104zM32 112h104v8h-104zM32 120h8v8h-8zM48 120h8v8h-8zM112 120h8v8h-8zM128 120h8v8h-8zM32 128h8v8h-8zM48 128h8v8h-8zM112 128h8v8h-8zM128 128h8v8h-8z"/>
    """

    // 1. Idle (calm standing)
    static let clawdIdle: NSImage = {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 16 168 124" width="24" height="18" shape-rendering="crispEdges">
          <g transform="translate(8, 0)">
            \(clawdBaseBody)
            <rect x="56" y="72" width="8" height="16" fill="#141414"/>
            <rect x="120" y="72" width="8" height="16" fill="#141414"/>
          </g>
        </svg>
        """
        let img = NSImage(data: svg.data(using: .utf8)!)!
        img.size = NSSize(width: 22, height: 16)
        return img
    }()

    // 2. Think 1: Eyes looking up with 1 thought bubble
    static let clawdThink1: NSImage = {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 16 168 124" width="24" height="18" shape-rendering="crispEdges">
          <g transform="translate(8, 0)">
            \(clawdBaseBody)
            <rect x="56" y="64" width="8" height="16" fill="#141414"/>
            <rect x="120" y="64" width="8" height="16" fill="#141414"/>
            <circle cx="132" cy="42" r="4" fill="#E5E7EB"/>
          </g>
        </svg>
        """
        let img = NSImage(data: svg.data(using: .utf8)!)!
        img.size = NSSize(width: 22, height: 16)
        return img
    }()

    // 3. Think 2: Eyes looking up-right with 2 thought bubbles
    static let clawdThink2: NSImage = {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 16 168 124" width="24" height="18" shape-rendering="crispEdges">
          <g transform="translate(8, 0)">
            \(clawdBaseBody)
            <rect x="62" y="62" width="8" height="16" fill="#141414"/>
            <rect x="124" y="62" width="8" height="16" fill="#141414"/>
            <circle cx="132" cy="42" r="4" fill="#E5E7EB"/>
            <circle cx="146" cy="28" r="7" fill="#E5E7EB"/>
            <circle cx="146" cy="28" r="4" fill="#D97757"/>
          </g>
        </svg>
        """
        let img = NSImage(data: svg.data(using: .utf8)!)!
        img.size = NSSize(width: 22, height: 16)
        return img
    }()

    // 4. Type 1: Typing on keyboard, left hand down, right hand up
    static let clawdType1: NSImage = {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 16 168 124" width="24" height="18" shape-rendering="crispEdges">
          <g transform="translate(8, 0)">
            \(clawdBaseBody)
            <rect x="56" y="76" width="8" height="12" fill="#141414"/>
            <rect x="120" y="76" width="8" height="12" fill="#141414"/>
            <rect x="40" y="128" width="88" height="8" rx="2" fill="#4B5563"/>
            <rect x="48" y="124" width="16" height="4" fill="#9CA3AF"/>
            <rect x="72" y="124" width="24" height="4" fill="#9CA3AF"/>
            <rect x="104" y="124" width="16" height="4" fill="#9CA3AF"/>
            <rect x="36" y="108" width="16" height="12" fill="#D97757"/>
            <rect x="116" y="96" width="16" height="12" fill="#D97757"/>
          </g>
        </svg>
        """
        let img = NSImage(data: svg.data(using: .utf8)!)!
        img.size = NSSize(width: 22, height: 16)
        return img
    }()

    // 5. Type 2: Typing on keyboard, right hand down, left hand up
    static let clawdType2: NSImage = {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 16 168 124" width="24" height="18" shape-rendering="crispEdges">
          <g transform="translate(8, 0)">
            \(clawdBaseBody)
            <rect x="56" y="76" width="8" height="12" fill="#141414"/>
            <rect x="120" y="76" width="8" height="12" fill="#141414"/>
            <rect x="40" y="128" width="88" height="8" rx="2" fill="#4B5563"/>
            <rect x="48" y="124" width="16" height="4" fill="#9CA3AF"/>
            <rect x="72" y="124" width="24" height="4" fill="#9CA3AF"/>
            <rect x="104" y="124" width="16" height="4" fill="#9CA3AF"/>
            <rect x="36" y="96" width="16" height="12" fill="#D97757"/>
            <rect x="116" y="108" width="16" height="12" fill="#D97757"/>
          </g>
        </svg>
        """
        let img = NSImage(data: svg.data(using: .utf8)!)!
        img.size = NSSize(width: 22, height: 16)
        return img
    }()

    // 6. Run Left 1: Shifted left, eyes looking left, motion lines
    static let clawdRunL1: NSImage = {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 16 168 124" width="24" height="18" shape-rendering="crispEdges">
          <g transform="translate(-4, 0)">
            \(clawdBaseBody)
            <rect x="48" y="72" width="8" height="16" fill="#141414"/>
            <rect x="112" y="72" width="8" height="16" fill="#141414"/>
            <rect x="144" y="80" width="12" height="4" rx="2" fill="#D97757" opacity="0.6"/>
            <rect x="140" y="96" width="16" height="4" rx="2" fill="#D97757" opacity="0.4"/>
          </g>
        </svg>
        """
        let img = NSImage(data: svg.data(using: .utf8)!)!
        img.size = NSSize(width: 22, height: 16)
        return img
    }()

    // 7. Run Left 2: Lifted slightly, faster stride
    static let clawdRunL2: NSImage = {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 16 168 124" width="24" height="18" shape-rendering="crispEdges">
          <g transform="translate(-10, -2)">
            \(clawdBaseBody)
            <rect x="48" y="72" width="8" height="16" fill="#141414"/>
            <rect x="112" y="72" width="8" height="16" fill="#141414"/>
            <rect x="148" y="76" width="16" height="4" rx="2" fill="#D97757" opacity="0.7"/>
            <rect x="144" y="92" width="20" height="4" rx="2" fill="#D97757" opacity="0.5"/>
          </g>
        </svg>
        """
        let img = NSImage(data: svg.data(using: .utf8)!)!
        img.size = NSSize(width: 22, height: 16)
        return img
    }()

    // 8. Run Right 1: Shifted right, eyes looking right, motion lines
    static let clawdRunR1: NSImage = {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 16 168 124" width="24" height="18" shape-rendering="crispEdges">
          <g transform="translate(14, 0)">
            \(clawdBaseBody)
            <rect x="64" y="72" width="8" height="16" fill="#141414"/>
            <rect x="128" y="72" width="8" height="16" fill="#141414"/>
            <rect x="8" y="80" width="12" height="4" rx="2" fill="#D97757" opacity="0.6"/>
            <rect x="4" y="96" width="16" height="4" rx="2" fill="#D97757" opacity="0.4"/>
          </g>
        </svg>
        """
        let img = NSImage(data: svg.data(using: .utf8)!)!
        img.size = NSSize(width: 22, height: 16)
        return img
    }()

    // 9. Run Right 2: Lifted slightly, faster stride right
    static let clawdRunR2: NSImage = {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 16 168 124" width="24" height="18" shape-rendering="crispEdges">
          <g transform="translate(20, -2)">
            \(clawdBaseBody)
            <rect x="64" y="72" width="8" height="16" fill="#141414"/>
            <rect x="128" y="72" width="8" height="16" fill="#141414"/>
            <rect x="4" y="76" width="16" height="4" rx="2" fill="#D97757" opacity="0.7"/>
            <rect x="0" y="92" width="20" height="4" rx="2" fill="#D97757" opacity="0.5"/>
          </g>
        </svg>
        """
        let img = NSImage(data: svg.data(using: .utf8)!)!
        img.size = NSSize(width: 22, height: 16)
        return img
    }()

    // 10. Jump (Waiting / asking user)
    static let clawdJump: NSImage = {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 16 168 124" width="24" height="18" shape-rendering="crispEdges">
          <g transform="translate(8, -12)">
            \(clawdBaseBody)
            <rect x="56" y="72" width="8" height="16" fill="#141414"/>
            <rect x="120" y="72" width="8" height="16" fill="#141414"/>
            <circle cx="146" cy="48" r="3" fill="#FBBF24"/>
          </g>
        </svg>
        """
        let img = NSImage(data: svg.data(using: .utf8)!)!
        img.size = NSSize(width: 22, height: 16)
        return img
    }()

    // MARK: - Gemini (Official Google Gemini Sparkle)
    static let geminiIdle: NSImage = {
        let svg = """
        <svg viewBox="0 0 24 24" width="16" height="16" xmlns="http://www.w3.org/2000/svg"><path fill="#4E82EE" d="M11.04 19.32Q12 21.51 12 24q0-2.49.93-4.68.96-2.19 2.58-3.81t3.81-2.55Q21.51 12 24 12q-2.49 0-4.68-.93a12.3 12.3 0 0 1-3.81-2.58 12.3 12.3 0 0 1-2.58-3.81Q12 2.49 12 0q0 2.49-.96 4.68-.93 2.19-2.55 3.81a12.3 12.3 0 0 1-3.81 2.58Q2.49 12 0 12q2.49 0 4.68.96 2.19.93 3.81 2.55t2.55 3.81"/></svg>
        """
        let img = NSImage(data: svg.data(using: .utf8)!)!
        img.size = NSSize(width: 15, height: 15)
        return img
    }()

    static let geminiWork1: NSImage = {
        let svg = """
        <svg viewBox="0 0 24 24" width="16" height="16" xmlns="http://www.w3.org/2000/svg"><g transform="rotate(22 12 12) scale(0.95 0.95)"><path fill="#3B82F6" d="M11.04 19.32Q12 21.51 12 24q0-2.49.93-4.68.96-2.19 2.58-3.81t3.81-2.55Q21.51 12 24 12q-2.49 0-4.68-.93a12.3 12.3 0 0 1-3.81-2.58 12.3 12.3 0 0 1-2.58-3.81Q12 2.49 12 0q0 2.49-.96 4.68-.93 2.19-2.55 3.81a12.3 12.3 0 0 1-3.81 2.58Q2.49 12 0 12q2.49 0 4.68.96 2.19.93 3.81 2.55t2.55 3.81"/></g></svg>
        """
        let img = NSImage(data: svg.data(using: .utf8)!)!
        img.size = NSSize(width: 15, height: 15)
        return img
    }()

    static let geminiJump: NSImage = {
        let svg = """
        <svg viewBox="0 -6 24 28" width="16" height="18" xmlns="http://www.w3.org/2000/svg"><path fill="#3B82F6" d="M11.04 19.32Q12 21.51 12 24q0-2.49.93-4.68.96-2.19 2.58-3.81t3.81-2.55Q21.51 12 24 12q-2.49 0-4.68-.93a12.3 12.3 0 0 1-3.81-2.58 12.3 12.3 0 0 1-2.58-3.81Q12 2.49 12 0q0 2.49-.96 4.68-.93 2.19-2.55 3.81a12.3 12.3 0 0 1-3.81 2.58Q2.49 12 0 12q2.49 0 4.68.96 2.19.93 3.81 2.55t2.55 3.81"/></svg>
        """
        let img = NSImage(data: svg.data(using: .utf8)!)!
        img.size = NSSize(width: 15, height: 17)
        return img
    }()
}
