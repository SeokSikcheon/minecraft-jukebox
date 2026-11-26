import AppKit
import SwiftUI
import AVFoundation

struct Disc: Codable, Identifiable, Equatable {
    let id, title, artist: String
    let duration: Double
    let preview: Bool
}
func stamp(_ seconds: Double) -> String {
    let s = max(0, Int(seconds))
    return String(format: "%d:%02d", s / 60, s % 60)
}
func file(_ name: String, _ ext: String) -> URL {
    Bundle.main.resourceURL!.appendingPathComponent(name).appendingPathExtension(ext)
}
final class Deck: NSObject, ObservableObject, AVAudioPlayerDelegate {
    let discs: [Disc]
    @Published var index: Int
    @Published var playing = false
    @Published var elapsed: Double = 0
    @Published var loop = false
    @Published var volume = UserDefaults.standard.object(forKey: "volume") as? Double ?? 0.7 {
        didSet { audio?.volume = Float(volume); UserDefaults.standard.set(volume, forKey: "volume") }
    }
    @Published var problem: String?
    private var audio: AVAudioPlayer?
    private var timer: Timer?
    var selected: Disc { discs[index] }
    override init() {
        discs = try! JSONDecoder().decode([Disc].self, from: Data(contentsOf: file("library","json")))
        index = discs.firstIndex { $0.id == "cat" } ?? 0
        super.init()
    }
    func start(_ i: Int) {
        timer?.invalidate()
        audio?.stop()
        audio = nil
        playing = false
        index = i
        elapsed = 0
        do {
            let next = try AVAudioPlayer(contentsOf: file(selected.id,"m4a"))
            next.volume = Float(volume)
            next.delegate = self
            audio = next
            play()
        } catch { problem = "读取《" + selected.title + "》时遇到了问题。" }
    }
    private func play() {
        guard audio?.play() == true else {
            problem = "播放未能开始，请检查声音输出设备后重试。"
            return
        }
        playing = true
        timer?.invalidate()
        let ticker = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self, let audio = self.audio else { return }
            self.elapsed = audio.currentTime
        }
        RunLoop.main.add(ticker, forMode: .common)
        timer = ticker
    }
    func toggle() {
        if playing {
            audio?.pause()
            playing = false
            elapsed = audio?.currentTime ?? elapsed
            timer?.invalidate()
        } else if audio == nil { 
            let at = elapsed
            start(index)
            if at > 0 { seek(at) }
        } else { play() }
    }
    func seek(_ value: Double) {
        elapsed = min(max(0,value),selected.duration)
        audio?.currentTime = elapsed
    }
    func skip(_ by: Int) { start((index + by + discs.count) % discs.count) }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard player === audio else { return }
        if flag { skip(loop ? 0 : 1) }
        else {
            timer?.invalidate()
            playing = false
            problem = "音频播放中断，请重新选择这张唱片。"
        }
    }
}

extension Color {
    init(hex n: Int) {
        self.init(.sRGB, red: Double((n >> 16) & 255)/255, green: Double((n >> 8) & 255)/255, blue: Double(n & 255)/255, opacity: 1)
    }
}
func pixel(_ name: String) -> Image {
    Image(nsImage: NSImage(contentsOf: file(name,"png"))!).interpolation(.none).resizable()
}
struct Slot: ViewModifier {
    var selected = false
    func body(content: Content) -> some View {
        content.background(selected ? Color(hex:0xb6b6b6) : Color(hex:0x8b8b8b))
            .overlay(alignment:.top) { Color(hex:0x373737).frame(height:3) }
            .overlay(alignment:.leading) { Color(hex:0x373737).frame(width:3) }
            .overlay(alignment:.bottom) { Color.white.frame(height:3) }
            .overlay(alignment:.trailing) { Color.white.frame(width:3) }
    }
}
func gameSprite(_ name: String, left: CGFloat, top: CGFloat, right: CGFloat, bottom: CGFloat) -> Image {
    let image = NSImage(contentsOf: file(name,"png"))!
    image.size = NSSize(width:image.size.width * 2, height:image.size.height * 2)
    return Image(nsImage:image).interpolation(.none)
        .resizable(capInsets:EdgeInsets(top:top * 2,leading:left * 2,bottom:bottom * 2,trailing:right * 2),resizingMode:.tile)
}
struct GameButton: View {
    let title: String
    let action: () -> Void
    @State private var hovering = false
    var body: some View {
        Button(action:action) {
            Text(title).font(.custom("Unifont", size:16)).foregroundStyle(.white)
                .shadow(color:.black.opacity(0.8),radius:0,x:2,y:2)
                .frame(maxWidth:.infinity).frame(height:40)
                .background(gameSprite(hovering ? "button_highlighted":"button",left:3,top:3,right:3,bottom:3))
        }.buttonStyle(.plain).onHover { hovering = $0 }
    }
}
struct GameSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let label: String
    @State private var hovering = false
    @State private var dragging = false

    var body: some View {
        GeometryReader { geometry in
            let width = max(0, geometry.size.width - 16)
            let fraction = min(1, max(0, (value - range.lowerBound) / (range.upperBound - range.lowerBound)))
            ZStack(alignment:.leading) {
                gameSprite(hovering || dragging ? "slider_highlighted":"slider",left:1,top:1,right:1,bottom:1)
                gameSprite(hovering || dragging ? "slider_handle_highlighted":"slider_handle",left:2,top:2,right:2,bottom:3)
                    .frame(width:16)
                    .offset(x:width * fraction)
                Text(label).font(.custom("Unifont",size:16)).foregroundStyle(.white)
                    .shadow(color:.black,radius:0,x:2,y:2)
                    .frame(maxWidth:.infinity).allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance:0).onChanged { event in
                dragging = true
                let position = min(1, max(0, (event.location.x - 8) / max(1, width)))
                value = range.lowerBound + position * (range.upperBound - range.lowerBound)
            }.onEnded { _ in dragging = false })
            .onHover { hovering = $0 }
        }
        .frame(height:40)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(value))")
        .accessibilityAdjustableAction { direction in
            let step = (range.upperBound - range.lowerBound) / 20
            switch direction {
            case .increment: value = min(range.upperBound, value + step)
            case .decrement: value = max(range.lowerBound, value - step)
            @unknown default: break
            }
        }
    }
}
struct MainView: View {
    @ObservedObject var deck: Deck
    @State private var query = ""
    var filtered: [Disc] {
        let q = query.trimmingCharacters(in:.whitespacesAndNewlines)
        return q.isEmpty ? deck.discs : deck.discs.filter {
            $0.title.localizedCaseInsensitiveContains(q) || $0.artist.localizedCaseInsensitiveContains(q)
        }
    }
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {
                Text("唱片机").font(.custom("Unifont", size:24))
                Spacer()
                Text(deck.playing ? "正在播放" : "已暂停").font(.custom("Unifont", size:16))
            }
            HStack(alignment:.top,spacing:18) {
                VStack(alignment:.leading,spacing:10) {
                    HStack(spacing:14) {
                        pixel("block").scaledToFit().frame(width:100,height:100)
                        VStack(alignment:.leading,spacing:5) {
                            Text(deck.selected.title).font(.custom("Unifont", size:20)).lineLimit(2)
                            Text(deck.selected.artist).font(.custom("Unifont", size:16))
                            if deck.selected.preview { Text("预发布").font(.custom("Unifont", size:13)) }
                        }
                        Spacer(minLength:0)
                    }.padding(10).frame(maxWidth:.infinity,minHeight:120).modifier(Slot())
                    GameSlider(value:Binding(get:{deck.elapsed},set:{deck.seek($0)}),
                               range:0...deck.selected.duration,
                               label:"进度：\(stamp(deck.elapsed)) / \(stamp(deck.selected.duration))")
                    HStack(spacing:5) {
                        GameButton(title:"上一张") { deck.skip(-1) }
                        GameButton(title:deck.playing ? "暂停":"播放",action:deck.toggle)
                        GameButton(title:"下一张") { deck.skip(1) }
                    }
                    HStack(spacing:5) {
                        GameButton(title:"随机") { deck.skip(Int.random(in:1..<deck.discs.count)) }
                        GameButton(title:deck.loop ? "单曲循环 ✓":"单曲循环") { deck.loop.toggle() }
                    }
                    GameSlider(value:$deck.volume,range:0...1,
                               label:"音量：\(Int(deck.volume * 100))")
                        .padding(.top,5)
                    Spacer()
                }.frame(width:260)
                VStack(alignment:.leading,spacing:8) {
                    HStack {
                        Text("唱片库").font(.custom("Unifont", size:18))
                        Spacer()
                        TextField("",text:$query).textFieldStyle(.plain)
                            .font(.custom("Unifont", size:16)).padding(6)
                            .frame(maxWidth:240).background(Color(hex:0x8b8b8b)).modifier(Slot())
                    }
                    if filtered.isEmpty {
                        Text("没有找到匹配的唱片").frame(maxWidth:.infinity,maxHeight:.infinity)
                    } else {
                        ScrollView {
                            LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:0),count:9),spacing:0) {
                                ForEach(filtered) { record in
                                    Button {
                                        if let i = deck.discs.firstIndex(of:record) { deck.start(i) }
                                    } label: {
                                        pixel(record.id).scaledToFit().padding(6)
                                            .frame(maxWidth:.infinity).aspectRatio(1,contentMode:.fit)
                                            .modifier(Slot(selected:deck.selected == record))
                                    }.buttonStyle(.plain)
                                        .help(record.title + " — " + record.artist + (record.preview ? "（预发布）" : ""))
                                        .accessibilityLabel(record.title + "，" + record.artist)
                                }
                            }
                        }
                    }
                }.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.top)
            }.frame(maxHeight:.infinity)
        }
        .padding(24).padding(.top,12)
        .frame(minWidth:740,minHeight:555)
        .background(Color(hex:0xc6c6c6))
        .overlay(alignment:.top) { Color.white.frame(height:5) }
        .overlay(alignment:.leading) { Color.white.frame(width:5) }
        .overlay(alignment:.bottom) { Color(hex:0x555555).frame(height:5) }
        .overlay(alignment:.trailing) { Color(hex:0x555555).frame(width:5) }
        .border(.black,width:4)
        .foregroundStyle(Color(hex:0x363636)).preferredColorScheme(.light)
        .alert("无法播放",isPresented:Binding(get:{deck.problem != nil},set:{if !$0 {deck.problem=nil}})) {
            Button("好") {deck.problem=nil}
        } message: {Text(deck.problem ?? "")}
    }
}
