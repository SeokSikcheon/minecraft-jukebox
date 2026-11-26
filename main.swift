import AppKit
import SwiftUI
import CoreText

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let deck = Deck()
    func applicationDidFinishLaunching(_ note: Notification) {
        CTFontManagerRegisterFontsForURL(file("unifont","otf") as CFURL, .process, nil)
        let menu = NSMenu()
        let appMenu = NSMenu()
        let appItem = NSMenuItem()
        menu.addItem(appItem)
        appItem.submenu = appMenu
        appMenu.addItem(withTitle:"关于唱片机",action:#selector(about),keyEquivalent:"").target=self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle:"退出唱片机",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
        let edit = NSMenu(title:"编辑")
        for (name,action,key) in [("剪切","cut:","x"),("复制","copy:","c"),("粘贴","paste:","v"),("全选","selectAll:","a")] {
            edit.addItem(withTitle:name,action:Selector(action),keyEquivalent:key)
        }
        menu.addItem(withTitle:"编辑",action:nil,keyEquivalent:"").submenu=edit
        let playback=NSMenu(title:"播放")
        for (name,action,key) in [("播放 / 暂停",#selector(toggle)," "),("上一张",#selector(previous),"["),("下一张",#selector(next),"]")] {
            let item=playback.addItem(withTitle:name,action:action,keyEquivalent:key)
            item.target=self
        }
        menu.addItem(withTitle:"播放",action:nil,keyEquivalent:"").submenu=playback
        NSApp.mainMenu = menu
        window=NSWindow(contentRect:NSRect(x:0,y:0,width:830,height:598),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        window.title="唱片机"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent=true
        window.backgroundColor=NSColor(srgbRed:248/255,green:247/255,blue:239/255,alpha:1)
        window.contentMinSize=NSSize(width:740,height:575)
        window.contentView=NSHostingView(rootView:MainView(deck:deck))
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(nil)
        NSApp.activate(ignoringOtherApps:true)
    }
    @objc func about() {
        NSApp.orderFrontStandardAboutPanel(options:[.applicationName:"唱片机",.applicationVersion:"1.0", .credits:NSAttributedString(string:"Minecraft Java 26.3 · 22 张正式版唱片\n26.4 Pre-Release 1 · 另含 Flurry\n\n音乐作者见唱片收藏。本应用为独立制作的非官方播放器。")])
    }
    @objc func toggle(){deck.toggle()}
    @objc func next(){deck.skip(1)}
    @objc func previous(){deck.skip(-1)}
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool {true}
}
let app=NSApplication.shared
let delegate=AppDelegate()
app.delegate=delegate
app.setActivationPolicy(.regular)
app.run()
