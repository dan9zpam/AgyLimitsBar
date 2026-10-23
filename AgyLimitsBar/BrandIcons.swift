import SwiftUI
import AppKit

enum AgentState: String {
    case idle
    case working
    case waiting
}

struct BrandIcons {
    // MARK: - Clawd (Official Claude Character)
    static let clawdIdle: NSImage = {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="12 48 128 92" width="20" height="15" shape-rendering="crispEdges">
          <path fill="#D97757" d="M32 56h104v8h-104zM32 64h104v8h-104zM32 72h104v8h-104zM32 80h104v8h-104zM16 88h120v8h-120zM16 96h120v8h-120zM32 104h104v8h-104zM32 112h104v8h-104zM32 120h8v8h-8zM48 120h8v8h-8zM112 120h8v8h-8zM128 120h8v8h-8zM32 128h8v8h-8zM48 128h8v8h-8zM112 128h8v8h-8zM128 128h8v8h-8z"/>
          <rect x="56" y="72" width="8" height="16" fill="#141414"/>
          <rect x="120" y="72" width="8" height="16" fill="#141414"/>
        </svg>
        """
        let img = NSImage(data: svg.data(using: .utf8)!)!
        img.size = NSSize(width: 18, height: 13)
        return img
    }()

    static let clawdWork1: NSImage = {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="12 30 160 110" width="22" height="15" shape-rendering="crispEdges">
          <path fill="#D97757" d="M32 56h104v8h-104zM32 64h104v8h-104zM32 72h104v8h-104zM32 80h104v8h-104zM16 88h120v8h-120zM16 96h120v8h-120zM32 104h104v8h-104zM32 112h104v8h-104zM32 120h8v8h-8zM48 120h8v8h-8zM112 120h8v8h-8zM128 120h8v8h-8zM32 128h8v8h-8zM48 128h8v8h-8zM112 128h8v8h-8zM128 128h8v8h-8z"/>
          <rect x="56" y="72" width="8" height="16" fill="#141414"/>
          <rect x="120" y="72" width="8" height="16" fill="#141414"/>
          <rect x="136" y="72" width="16" height="8" fill="#D97757"/>
          <rect x="144" y="64" width="16" height="8" fill="#D97757"/>
          <rect x="152" y="56" width="16" height="8" fill="#D97757"/>
        </svg>
        """
        let img = NSImage(data: svg.data(using: .utf8)!)!
        img.size = NSSize(width: 20, height: 13)
        return img
    }()

    static let clawdWork2: NSImage = {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="12 30 160 110" width="22" height="15" shape-rendering="crispEdges">
          <path fill="#D97757" d="M32 56h104v8h-104zM32 64h104v8h-104zM32 72h104v8h-104zM32 80h104v8h-104zM16 88h120v8h-120zM16 96h120v8h-120zM32 104h104v8h-104zM32 112h104v8h-104zM32 120h8v8h-8zM48 120h8v8h-8zM112 120h8v8h-8zM128 120h8v8h-8zM32 128h8v8h-8zM48 128h8v8h-8zM112 128h8v8h-8zM128 128h8v8h-8z"/>
          <rect x="56" y="72" width="8" height="16" fill="#141414"/>
          <rect x="120" y="72" width="8" height="16" fill="#141414"/>
          <rect x="136" y="80" width="16" height="8" fill="#D97757"/>
          <rect x="144" y="88" width="16" height="8" fill="#D97757"/>
          <rect x="152" y="96" width="16" height="8" fill="#D97757"/>
        </svg>
        """
        let img = NSImage(data: svg.data(using: .utf8)!)!
        img.size = NSSize(width: 20, height: 13)
        return img
    }()

    static let clawdJump: NSImage = {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="12 28 128 112" width="20" height="17" shape-rendering="crispEdges">
          <path fill="#D97757" d="M32 36h104v8h-104zM32 44h104v8h-104zM32 52h104v8h-104zM32 60h104v8h-104zM16 68h120v8h-120zM16 76h120v8h-120zM32 84h104v8h-104zM32 92h104v8h-104zM32 100h8v8h-8zM48 100h8v8h-8zM112 100h8v8h-8zM128 100h8v8h-8zM32 108h8v8h-8zM48 108h8v8h-8zM112 108h8v8h-8zM128 108h8v8h-8z"/>
          <rect x="56" y="52" width="8" height="16" fill="#141414"/>
          <rect x="120" y="52" width="8" height="16" fill="#141414"/>
        </svg>
        """
        let img = NSImage(data: svg.data(using: .utf8)!)!
        img.size = NSSize(width: 18, height: 15)
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
