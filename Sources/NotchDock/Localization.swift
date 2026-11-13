import Foundation

enum AppLanguage: String, CaseIterable {
    case traditional = "zh-Hant"
    case simplified = "zh-Hans"
    case english = "en"
    case japanese = "ja"
    case korean = "ko"

    var nativeName: String {
        switch self {
        case .traditional: return "繁體中文"
        case .simplified: return "简体中文"
        case .english: return "English"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        }
    }
    var column: Int {
        switch self {
        case .simplified: return 0
        case .traditional: return 1
        case .english: return 2
        case .japanese: return 3
        case .korean: return 4
        }
    }
}

extension Notification.Name {
    static let languageChanged = Notification.Name("FloatIslandLanguageChanged")
}

enum Localization {
    // Keep the existing interface language until the user makes an explicit choice.
    static var language: AppLanguage {
        get { AppLanguage(rawValue: UserDefaults.standard.string(forKey: "interfaceLanguage") ?? "") ?? .simplified }
        set {
            guard newValue != language else { return }
            UserDefaults.standard.set(newValue.rawValue, forKey: "interfaceLanguage")
            NotificationCenter.default.post(name: .languageChanged, object: nil)
        }
    }
    static func text(_ key: String, language: AppLanguage? = nil) -> String {
        catalog[key]?[(language ?? self.language).column] ?? key
    }
    static let catalog: [String: [String]] = [
        "浮屿": ["Floatsland", "Floatsland", "Floatsland", "Floatsland", "Floatsland"],
        "隐藏浮屿": ["隐藏Floatsland", "隱藏Floatsland", "Hide Floatsland", "Floatslandを隠す", "Floatsland 가리기"],
        "显示浮屿": ["显示Floatsland", "顯示Floatsland", "Show Floatsland", "Floatslandを表示", "Floatsland 보기"],
        "设置…": ["设置…", "設定…", "Settings…", "設定…", "설정…"],
        "清空暂存": ["清空暂存", "清空暫存", "Clear Shelf", "すべて削除", "보관함 비우기"],
        "关于 浮屿": ["关于 Floatsland", "關於Floatsland", "About Floatsland", "Floatslandについて", "Floatsland 정보"],
        "退出 浮屿": ["退出 Floatsland", "結束Floatsland", "Quit Floatsland", "Floatslandを終了", "Floatsland 종료"],
        "浮屿 FloatIsland": ["Floatsland", "Floatsland", "Floatsland", "Floatsland", "Floatsland"],
        "好的": ["好的", "好", "OK", "OK", "확인"],
        "感应区域": ["感应区域", "感應區域", "Activation Area", "反応エリア", "감지 영역"],
        "浮屿设置": ["Floatsland设置", "Floatsland設定", "Floatsland Settings", "Floatslandの設定", "Floatsland 설정"],
        "仅拖拽文件时展开": ["仅拖拽文件时展开", "僅拖移時展開", "When dragging", "ドラッグ時のみ", "드래그할 때"],
        "悬停或拖拽时展开": ["悬停或拖拽时展开", "游標停留或拖移時展開", "On hover or drag", "ホバーまたはドラッグ時", "마우스를 올리거나 드래그할 때"],
        "仅点击小岛时展开": ["仅点击小岛时展开", "僅點擊時展開", "On click", "クリック時のみ", "클릭할 때"],
        "展开方式": ["展开方式", "展開方式", "Expand on", "展開方法", "펼치기 방식"],
        "自动收起延迟": ["自动收起延迟", "自動收合延遲", "Collapse delay", "閉じるまでの時間", "접기 지연 시간"],
        "感应区域（触发放大的范围与位置，实时生效）": ["感应区域（触发放大的范围与位置，实时生效）", "感應區域（範圍與位置即時生效）", "Activation area — live adjustments", "反応エリア（変更はすぐに反映）", "감지 영역 — 즉시 적용"],
        "感应高度": ["感应高度", "感應高度", "Area height", "エリアの高さ", "영역 높이"],
        "感应宽度": ["感应宽度", "感應寬度", "Area width", "エリアの幅", "영역 너비"],
        "感应水平偏移": ["感应水平偏移", "感應水平偏移", "Area horizontal offset", "エリアの左右位置", "영역 가로 위치"],
        "感应垂直偏移": ["感应垂直偏移", "感應垂直偏移", "Area vertical offset", "エリアの上下位置", "영역 세로 위치"],
        "感应区域与小岛重合（合并）": ["感应区域与小岛重合（合并）", "感應區域與小島重合", "Match activation area to capsule", "反応エリアをカプセルに合わせる", "감지 영역을 캡슐에 맞추기"],
        "显示感应区域预览（虚线框）": ["显示感应区域预览（虚线框）", "顯示感應區域預覽（虛線框）", "Preview activation area (dashed outline)", "反応エリアを点線で表示", "감지 영역 미리 보기 (점선)"],
        "小岛大小（实时生效）": ["小岛大小（实时生效）", "小島大小（即時生效）", "Island size — live adjustments", "サイズ（変更はすぐに反映）", "크기 — 즉시 적용"],
        "胶囊宽度": ["胶囊宽度", "膠囊寬度", "Capsule width", "カプセルの幅", "캡슐 너비"],
        "胶囊高度": ["胶囊高度", "膠囊高度", "Capsule height", "カプセルの高さ", "캡슐 높이"],
        "面板宽度": ["面板宽度", "面板寬度", "Panel width", "パネルの幅", "패널 너비"],
        "面板高度": ["面板高度", "面板高度", "Panel height", "パネルの高さ", "패널 높이"],
        "小岛位置（胶囊与展开面板一起移动，实时生效）": ["小岛位置（胶囊与展开面板一起移动，实时生效）", "小島位置（膠囊與展開面板同步移動）", "Island position — capsule and panel move together", "位置（カプセルとパネルが一緒に移動）", "위치 — 캡슐과 패널 함께 이동"],
        "小岛水平偏移": ["小岛水平偏移", "小島水平偏移", "Island horizontal offset", "小島の左右位置", "아일랜드 가로 위치"],
        "小岛垂直偏移": ["小岛垂直偏移", "小島垂直偏移", "Island vertical offset", "小島の上下位置", "아일랜드 세로 위치"],
        "负值向上，可移入刘海区域；正值向下": ["负值向上，可移入刘海区域；正值向下", "負值向上，可移入瀏海區域；正值向下", "Negative: up into the notch. Positive: down.", "負の値で上へ（ノッチ内も可）、正の値で下へ", "음수: 노치 쪽으로 위로. 양수: 아래로."],
        "收起时藏入刘海": ["收起时藏入刘海", "收合時藏入瀏海", "Hide capsule inside notch", "閉じたカプセルをノッチ内に配置", "접힌 캡슐을 노치 안에 숨기기"],
        "在所有显示器显示小岛": ["在所有显示器显示小岛", "在所有顯示器顯示小島", "Show on all displays", "すべてのディスプレイに表示", "모든 디스플레이에 표시"],
        "开机自动启动": ["开机自动启动", "登入時自動啟動", "Launch at login", "ログイン時に起動", "로그인 시 실행"],
        "拖出成功后自动移除条目（默认关：条目保留在小岛）": ["拖出成功后自动移除条目（默认关：条目保留在小岛）", "拖出成功後移除項目（預設保留）", "Remove items after dragging out (off by default)", "ドラッグ完了後に項目を削除（初期設定はオフ）", "드래그 완료 후 항목 제거 (기본값: 끔)"],
        "把文件拖到感应区域即可放大暂存；点击小岛展开，点击箭头收起。感应范围有虚线预览，小岛位置移动时屏幕上的胶囊会实时跟着动。": ["把文件拖到感应区域即可放大暂存；点击小岛展开，点击箭头收起。感应范围有虚线预览，小岛位置移动时屏幕上的胶囊会实时跟着动。", "拖入檔案即可暫存。點擊小島展開；再次點擊頂部中央、箭頭或介面外即可收合。設定會即時生效。", "Drop files to save them. Click the capsule to expand; click the top center, arrow or outside to collapse. Settings apply immediately.", "ファイルをドロップして一時保管。カプセルをクリックして展開し、上部中央・矢印・パネル外のクリックで閉じます。設定はすぐに反映されます。", "파일을 놓아 임시 보관하세요. 캡슐을 클릭하면 펼쳐지고 상단 중앙, 화살표 또는 바깥을 클릭하면 접힙니다. 설정은 즉시 적용됩니다."],
        "无法设置开机自动启动": ["无法设置开机自动启动", "無法設定登入時自動啟動", "Could not change login setting", "ログイン時の起動設定を変更できません", "로그인 시 실행 설정을 변경할 수 없습니다"],
        "%.1f 秒": ["%.1f 秒", "%.1f 秒", "%.1f s", "%.1f 秒", "%.1f초"],
        "清空": ["清空", "清空", "Clear", "クリア", "비우기"],
        "全选": ["全选", "全選", "All", "全選択", "전체 선택"],
        "拖入暂存  ·  拖出复制  ·  ⌘ 拖出移动": ["拖入暂存  ·  拖出复制  ·  ⌘ 拖出移动", "拖入暫存 · 拖出複製 · ⌘ 拖出移動", "Drop to save · Drag to copy · ⌘ Move", "ドロップで保管 · ドラッグでコピー · ⌘で移動", "놓아 보관 · 끌어 복사 · ⌘ 이동"],
        "✓ 已暂存": ["✓ 已暂存", "✓ 已暫存", "✓ Saved to shelf", "✓ 保管しました", "✓ 보관됨"],
        "收起": ["收起", "收合", "Collapse", "閉じる", "접기"],
        "%d 项": ["%d 项", "%d 項", "%d items", "%d 項目", "%d개"],
        "取消全选": ["取消全选", "取消全選", "Deselect All", "選択を解除", "전체 선택 해제"],
        "移除 %@": ["移除 %@", "移除 %@", "Remove %@", "%@を削除", "%@ 제거"],
        "(空白)": ["(空白)", "(空白)", "(Blank)", "(空白)", "(빈 항목)"],
        "移除文本": ["移除文本", "移除文字", "Remove Text", "テキストを削除", "텍스트 제거"],
        "移除": ["移除", "移除", "Remove", "削除", "제거"],
        "复制文本": ["复制文本", "複製文字", "Copy Text", "テキストをコピー", "텍스트 복사"],
        "在访达中显示": ["在访达中显示", "在Finder中顯示", "Show in Finder", "Finderで表示", "Finder에서 보기"],
        "让文件在这里停留片刻": ["让文件在这里停留片刻", "讓檔案在這裡停留片刻", "A place for your next move", "ファイルの一時置き場", "파일이 잠시 머무는 곳"],
        "拖入文件、文件夹或文字 · 随时带到下一处": ["拖入文件、文件夹或文字 · 随时带到下一处", "拖入檔案、資料夾或文字 · 隨時帶到下一處", "Drop files, folders or text here", "ファイル・フォルダ・テキストをドロップ", "파일, 폴더 또는 텍스트를 놓으세요"],
        "语言": ["语言", "語言", "Language", "言語", "언어"],
        "about.body": ["拖入文件、文件夹或文字即可暂存。拖出默认复制，按住 ⌘ 可移动。点击顶部中央、箭头或界面外即可收起。文件只保存位置引用，移除条目不会删除原文件。", "拖入檔案、資料夾或文字即可暫存。拖出預設為複製，按住 ⌘ 可移動。點擊頂部中央、箭頭或介面外即可收合。檔案僅儲存位置參照，移除項目不會刪除原檔。", "Drop files, folders or text onto the island. Drag out to copy; hold ⌘ to allow moving. Click the top center, arrow or outside to collapse. Files are stored as references; removing an item does not delete the original.", "ファイル・フォルダ・テキストをドロップして保管します。ドラッグでコピー、⌘を押しながらドラッグすると移動できます。上部中央・矢印・パネル外をクリックすると閉じます。ファイルは参照として保管され、項目を削除しても元のファイルは消えません。", "파일, 폴더 또는 텍스트를 놓아 보관하세요. 끌어내면 복사되고 ⌘를 누르면 이동할 수 있습니다. 상단 중앙, 화살표 또는 바깥을 클릭하면 접힙니다. 파일 위치만 저장하므로 항목을 제거해도 원본은 삭제되지 않습니다."]
    ]
}

func L(_ key: String) -> String { Localization.text(key) }
