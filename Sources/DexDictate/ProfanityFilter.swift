import Foundation

/// Stateless text filter that substitutes offensive words with whimsical replacements.
///
/// All regex patterns are compiled once as a lazy static at first use, so repeated calls to
/// ``filter(_:)`` do not incur re-compilation overhead.
///
/// Processing order is significant:
/// 1. **Strict, case-sensitive** replacements (e.g. all-caps "ICE") run first.
/// 2. **Case-insensitive, word-boundary** replacements run over the result.
enum ProfanityFilter {

    /// Exact, case-sensitive string replacements applied before the general map.
    private static let strictReplacements: [(String, String)] = [
        ("ICE", "state-sponsored terrorists")
    ]

    private static let whimsicalMap: [(NSRegularExpression, String)] = {
        let map: [String: String] = [
            // Political / Authority Substitutions
            "cop": "state-sponsored terrorist",
            "cops": "state-sponsored terrorists",
            "police": "state-sponsored terrorists",
            "Trump": "fuckin' Trump",
            "patriotic": "fascist",

            // Whimsical Safety Substitutions
            "fuck": "fudge", "fucking": "flipping", "fucked": "flipped", "fucker": "flipper",
            "motherfucker": "mother-lover", "fuckface": "funny-face", "fuckwit": "dimwit",
            "shit": "sugar", "shitty": "sugar-coated", "shittier": "sugar-ier",
            "shithead": "silly-head", "shitface": "poop-face", "shitbag": "sugar-bag",
            "shitshow": "circus", "bullshit": "hogwash", "horseshit": "nonsense",
            "ass": "buns", "asshole": "goofball", "asshat": "silly-hat", "dumbass": "silly-goose",
            "jackass": "donkey", "badass": "tough-cookie", "bastard": "rascal",
            "damn": "darn", "damned": "darned", "goddamn": "gosh-darn", "goddammit": "gosh-darn-it",
            "hell": "heck", "to hell with this": "to heck with this",
            "piss": "fizz", "pissed": "miffed", "pissy": "cranky", "piss-off": "buzz-off",
            "douche": "doofus", "douchebag": "dingbat", "douchy": "doofus-y",
            "jerk": "meanie", "jerkoff": "goof-off",
            "moron": "goof", "idiot": "noodle", "dumb": "silly", "stupid": "goofy",
            "imbecile": "simpleton", "nitwit": "birdbrain", "dimwit": "dunce",
            "blockhead": "pumpkin-head", "bonehead": "numbskull", "knucklehead": "knuckle-dragger",
            "tool": "spoon", "clown": "jester", "loser": "snoozer", "creep": "weirdo",
            "scumbag": "meanie-bo-beanie", "sleazebag": "greaseball", "sleaze": "slime",
            "slimeball": "jellyfish", "dirtbag": "dust-bunny", "trash": "rubbish",
            "garbage": "junk", "piece of crap": "piece of cake",
            "piece of shit": "piece of pie", "piece of junk": "piece of toast",
            "screw you": "bless you", "screw off": "scoot", "screw this": "forget this",
            "screw that": "forget that", "screw it": "forget it",
            "frick": "fiddle", "fricking": "fiddling", "freaking": "flipping",
            "crap": "crud", "crappy": "crummy", "craphead": "crud-bucket", "bullcrap": "baloney",
            "damn it": "darn it", "shut up": "hush up", "shut the hell up": "zip it",
            "asswipe": "wet-wipe", "assclown": "class-clown", "assface": "cheeky-face",
            "ass-backwards": "topsy-turvy",
            "dick": "pickle", "dickhead": "pickle-head", "dickish": "picklish",
            "prick": "cactus", "prickish": "thorny", "wanker": "wonker",
            "twat": "twit", "twit": "birdie", "turd": "toad", "turdface": "toad-face",
            "cocksucker": "lollipop-lover", "cockhead": "rooster-head",
            "balls": "marbles", "ballsy": "brave", "ball-breaker": "task-master",
            "dipshit": "dipstick", "bullshitter": "storyteller",
            "shitstain": "smudge", "shitkicker": "boot-scooter",
            "shit-for-brains": "silly-billy"
        ]

        return map.compactMap { (word, replacement) in
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                return nil
            }
            return (regex, replacement)
        }
    }()

    /// Returns a copy of `text` with all matched words replaced by their whimsical equivalents.
    ///
    /// - Parameter text: The raw transcription string.
    /// - Returns: The filtered string, or the original string unchanged if no words match.
    static func filter(_ text: String) -> String {
        var result = text

        // 1. Strict case-sensitive replacements first
        for (target, replacement) in strictReplacements {
            result = result.replacingOccurrences(of: target, with: replacement)
        }

        // 2. Case-insensitive word-boundary replacements
        for (regex, replacement) in whimsicalMap {
            let range = NSRange(location: 0, length: result.utf16.count)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: replacement)
        }

        return result
    }
}
