import Foundation

public enum BundledVocabularyPacks {
    /// Bundled profile vocabulary is transient runtime data.
    /// Keep recognition-oriented pairs here and leave user-owned custom vocabulary in `VocabularyManager.items`.
    public static func pack(for profile: AppProfile) -> [VocabularyItem] {
        switch profile {
        case .standard:
            return standard
        case .canadian:
            return canadian
        case .aussie:
            return aussie
        }
    }

    /// Standard pack: core app terms, common dictation corrections, and general queer vernacular support.
    public static let standard: [VocabularyItem] = [
        VocabularyItem(original: "dex dictate", replacement: "DexDictate"),
        VocabularyItem(original: "dex dictate mac os", replacement: "DexDictate macOS"),
        VocabularyItem(original: "mac os", replacement: "macOS"),
        VocabularyItem(original: "menu bar", replacement: "menubar"),
        VocabularyItem(original: "auto paste", replacement: "auto-paste"),
        VocabularyItem(original: "quick settings", replacement: "Quick Settings"),
        VocabularyItem(original: "whisper cpp", replacement: "whisper.cpp"),
        VocabularyItem(original: "voice memo", replacement: "Voice Memos"),
        VocabularyItem(original: "open ai", replacement: "OpenAI"),
        VocabularyItem(original: "git hub", replacement: "GitHub"),
        VocabularyItem(original: "pull request", replacement: "PR"),
        VocabularyItem(original: "user defaults", replacement: "UserDefaults"),
        VocabularyItem(original: "app kit", replacement: "AppKit"),
        VocabularyItem(original: "swift ui", replacement: "SwiftUI"),
        VocabularyItem(original: "menu bar extra", replacement: "MenuBarExtra"),
        VocabularyItem(original: "drag queen", replacement: "drag queen"),
        VocabularyItem(original: "drag king", replacement: "drag king"),
        VocabularyItem(original: "non binary", replacement: "non-binary"),
        VocabularyItem(original: "gender queer", replacement: "genderqueer"),
        VocabularyItem(original: "gender fluid", replacement: "genderfluid"),
        VocabularyItem(original: "two spirit", replacement: "Two-Spirit"),
        VocabularyItem(original: "top surgery", replacement: "top surgery"),
        VocabularyItem(original: "bottom surgery", replacement: "bottom surgery"),
        VocabularyItem(original: "dead name", replacement: "deadname"),
        VocabularyItem(original: "mis gender", replacement: "misgender"),
        VocabularyItem(original: "bind er", replacement: "binder"),
        VocabularyItem(original: "pack er", replacement: "packer"),
        VocabularyItem(original: "t girl", replacement: "t-girl"),
        VocabularyItem(original: "t boy", replacement: "t-boy"),
        VocabularyItem(original: "stud", replacement: "stud"),
        VocabularyItem(original: "butch", replacement: "butch"),
        VocabularyItem(original: "femme", replacement: "femme"),
        VocabularyItem(original: "twink", replacement: "twink"),
        VocabularyItem(original: "otter", replacement: "otter"),
        VocabularyItem(original: "bear", replacement: "bear"),
        VocabularyItem(original: "soft butch", replacement: "soft butch"),
        VocabularyItem(original: "stone butch", replacement: "stone butch"),
        VocabularyItem(original: "high femme", replacement: "high femme"),
        VocabularyItem(original: "camp", replacement: "camp"),
        VocabularyItem(original: "trade", replacement: "trade")
    ]

    /// Canadian pack: regional spellings, slang, and common Canadian queer-community terms.
    public static let canadian: [VocabularyItem] = [
        VocabularyItem(original: "colour", replacement: "colour"),
        VocabularyItem(original: "favourite", replacement: "favourite"),
        VocabularyItem(original: "centre", replacement: "centre"),
        VocabularyItem(original: "cheque", replacement: "cheque"),
        VocabularyItem(original: "neighbourhood", replacement: "neighbourhood"),
        VocabularyItem(original: "toque", replacement: "tuque"),
        VocabularyItem(original: "tim hortons", replacement: "Tim Hortons"),
        VocabularyItem(original: "timmies", replacement: "Timmies"),
        VocabularyItem(original: "double double", replacement: "double-double"),
        VocabularyItem(original: "loonie", replacement: "loonie"),
        VocabularyItem(original: "toonie", replacement: "toonie"),
        VocabularyItem(original: "washroom", replacement: "washroom"),
        VocabularyItem(original: "hydro bill", replacement: "hydro bill"),
        VocabularyItem(original: "chesterfield", replacement: "chesterfield"),
        VocabularyItem(original: "all dressed", replacement: "all-dressed"),
        VocabularyItem(original: "nanaimo bar", replacement: "Nanaimo bar"),
        VocabularyItem(original: "caesar", replacement: "Caesar"),
        VocabularyItem(original: "sorry not sorry", replacement: "sorry-not-sorry"),
        VocabularyItem(original: "cbc", replacement: "CBC"),
        VocabularyItem(original: "hoser", replacement: "hoser"),
        VocabularyItem(original: "gay village", replacement: "Gay Village"),
        VocabularyItem(original: "church and wellesley", replacement: "Church-Wellesley"),
        VocabularyItem(original: "the village toronto", replacement: "The Village"),
        VocabularyItem(original: "two s l g b t q plus", replacement: "2SLGBTQ+"),
        VocabularyItem(original: "two spirit", replacement: "Two-Spirit"),
        VocabularyItem(original: "queer as folk", replacement: "Queer as Folk"),
        VocabularyItem(original: "dyke march", replacement: "Dyke March"),
        VocabularyItem(original: "pride toronto", replacement: "Pride Toronto"),
        VocabularyItem(original: "fag hag", replacement: "fag hag"),
        VocabularyItem(original: "twink", replacement: "twink"),
        VocabularyItem(original: "bear", replacement: "bear"),
        VocabularyItem(original: "butch", replacement: "butch"),
        VocabularyItem(original: "femme", replacement: "femme"),
        VocabularyItem(original: "camp", replacement: "camp"),
        VocabularyItem(original: "trade", replacement: "trade"),
        VocabularyItem(original: "girlie pop", replacement: "girlypop"),
        VocabularyItem(original: "gaybourhood", replacement: "gaybourhood"),
        VocabularyItem(original: "serviette", replacement: "serviette"),
        VocabularyItem(original: "zed", replacement: "zed"),
        VocabularyItem(original: "eh", replacement: "eh")
    ]

    /// Aussie pack: Australian spellings/slang plus colloquial queer and reclaimed vernacular that users may intend literally.
    public static let aussie: [VocabularyItem] = [
        VocabularyItem(original: "colour", replacement: "colour"),
        VocabularyItem(original: "favourite", replacement: "favourite"),
        VocabularyItem(original: "organise", replacement: "organise"),
        VocabularyItem(original: "realise", replacement: "realise"),
        VocabularyItem(original: "centre", replacement: "centre"),
        VocabularyItem(original: "traveller", replacement: "traveller"),
        VocabularyItem(original: "arvo", replacement: "arvo"),
        VocabularyItem(original: "servo", replacement: "servo"),
        VocabularyItem(original: "esky", replacement: "esky"),
        VocabularyItem(original: "bogan", replacement: "bogan"),
        VocabularyItem(original: "maccas", replacement: "Macca's"),
        VocabularyItem(original: "brekkie", replacement: "brekkie"),
        VocabularyItem(original: "ripper", replacement: "ripper"),
        VocabularyItem(original: "no worries", replacement: "no worries"),
        VocabularyItem(original: "mate", replacement: "mate"),
        VocabularyItem(original: "fair dinkum", replacement: "fair dinkum"),
        VocabularyItem(original: "dag", replacement: "dag"),
        VocabularyItem(original: "drongo", replacement: "drongo"),
        VocabularyItem(original: "ute", replacement: "ute"),
        VocabularyItem(original: "bottle o", replacement: "bottle-o"),
        VocabularyItem(original: "mardi gras sydney", replacement: "Sydney Mardi Gras"),
        VocabularyItem(original: "oxford street", replacement: "Oxford Street"),
        VocabularyItem(original: "poofter", replacement: "poofter"),
        VocabularyItem(original: "poof", replacement: "poof"),
        VocabularyItem(original: "fairy", replacement: "fairy"),
        VocabularyItem(original: "fag hag", replacement: "fag hag"),
        VocabularyItem(original: "twink", replacement: "twink"),
        VocabularyItem(original: "bear", replacement: "bear"),
        VocabularyItem(original: "butch", replacement: "butch"),
        VocabularyItem(original: "femme", replacement: "femme"),
        VocabularyItem(original: "camp", replacement: "camp"),
        VocabularyItem(original: "trade", replacement: "trade"),
        VocabularyItem(original: "dyke march", replacement: "Dyke March"),
        VocabularyItem(original: "drag queen", replacement: "drag queen"),
        VocabularyItem(original: "drag king", replacement: "drag king"),
        VocabularyItem(original: "king hit", replacement: "king hit"),
        VocabularyItem(original: "dead set", replacement: "dead set"),
        VocabularyItem(original: "strewth", replacement: "strewth"),
        VocabularyItem(original: "reckon", replacement: "reckon"),
        VocabularyItem(original: "yeah nah", replacement: "yeah nah")
    ]
}
