use obfstr::obfstring;

/// Order must match `enum T` in `lib/src/core/lexicon.dart`.
#[derive(Clone, Copy)]
pub enum Txt {
    AppTitle,
    FontFamily,
    Loading,
    Settings,
    Privacy,
    Support,
    Close,
    Balance,
    Bet,
    Win,
    Spin,
    Auto,
    Stop,
    Collect,
    BonusWheel,
    SpinWheel,
    YouWon,
    TotalWin,
    Jackpot,
    LevelUp,
    Reward,
    Refill,
    RefillText,
    Take,
    Info,
    Paytable,
    Disclaimer,
    WebError,
    Retry,
    TapToContinue,
    Lines,
    Separator,
    SufK,
    SufM,
    SufB,
    Times,
    Plus,
    Space,
    Wild,
    Scatter,
    Coins,
    Lvl,
    NotEnough,
    FinishBonus,
    BetLocked,
    BigWin,
    MegaWin,
    EpicWin,
    Catch,
    Expands,
    Lightning,
    Of,
    IceFishing,
    FishingBonus,
    HoldToReel,
    FishOn,
    YouCaught,
    Features,
    WheelPrizes,
    Tension,
}

const ALL_TXT: [Txt; 60] = [
    Txt::AppTitle,
    Txt::FontFamily,
    Txt::Loading,
    Txt::Settings,
    Txt::Privacy,
    Txt::Support,
    Txt::Close,
    Txt::Balance,
    Txt::Bet,
    Txt::Win,
    Txt::Spin,
    Txt::Auto,
    Txt::Stop,
    Txt::Collect,
    Txt::BonusWheel,
    Txt::SpinWheel,
    Txt::YouWon,
    Txt::TotalWin,
    Txt::Jackpot,
    Txt::LevelUp,
    Txt::Reward,
    Txt::Refill,
    Txt::RefillText,
    Txt::Take,
    Txt::Info,
    Txt::Paytable,
    Txt::Disclaimer,
    Txt::WebError,
    Txt::Retry,
    Txt::TapToContinue,
    Txt::Lines,
    Txt::Separator,
    Txt::SufK,
    Txt::SufM,
    Txt::SufB,
    Txt::Times,
    Txt::Plus,
    Txt::Space,
    Txt::Wild,
    Txt::Scatter,
    Txt::Coins,
    Txt::Lvl,
    Txt::NotEnough,
    Txt::FinishBonus,
    Txt::BetLocked,
    Txt::BigWin,
    Txt::MegaWin,
    Txt::EpicWin,
    Txt::Catch,
    Txt::Expands,
    Txt::Lightning,
    Txt::Of,
    Txt::IceFishing,
    Txt::FishingBonus,
    Txt::HoldToReel,
    Txt::FishOn,
    Txt::YouCaught,
    Txt::Features,
    Txt::WheelPrizes,
    Txt::Tension,
];

pub fn text(t: Txt) -> String {
    match t {
        Txt::AppTitle => obfstring!("Frost Legend"),
        Txt::FontFamily => obfstring!("Lilita"),
        Txt::Loading => obfstring!("LOADING"),
        Txt::Settings => obfstring!("SETTINGS"),
        Txt::Privacy => obfstring!("Privacy Policy"),
        Txt::Support => obfstring!("Support"),
        Txt::Close => obfstring!("CLOSE"),
        Txt::Balance => obfstring!("BALANCE"),
        Txt::Bet => obfstring!("BET"),
        Txt::Win => obfstring!("WIN"),
        Txt::Spin => obfstring!("SPIN"),
        Txt::Auto => obfstring!("AUTO"),
        Txt::Stop => obfstring!("STOP"),
        Txt::Collect => obfstring!("COLLECT"),
        Txt::BonusWheel => obfstring!("BONUS WHEEL"),
        Txt::SpinWheel => obfstring!("SPIN THE WHEEL"),
        Txt::YouWon => obfstring!("YOU WON"),
        Txt::TotalWin => obfstring!("TOTAL WIN"),
        Txt::Jackpot => obfstring!("JACKPOT"),
        Txt::LevelUp => obfstring!("LEVEL UP!"),
        Txt::Reward => obfstring!("REWARD"),
        Txt::Refill => obfstring!("FREE COINS"),
        Txt::RefillText => obfstring!("Out of coins? Take a gift and keep spinning!"),
        Txt::Take => obfstring!("TAKE"),
        Txt::Info => obfstring!("INFO"),
        Txt::Paytable => obfstring!("PAYTABLE"),
        Txt::Disclaimer => obfstring!(
            "Frost Legend is a social casino game for entertainment only. It does not offer real money gambling or an opportunity to win real money or prizes. Practice or success at social casino gaming does not imply future success at real money gambling. Intended for adults 18+."
        ),
        Txt::WebError => obfstring!("The page could not be loaded"),
        Txt::Retry => obfstring!("RETRY"),
        Txt::TapToContinue => obfstring!("TAP TO CONTINUE"),
        Txt::Lines => obfstring!("20 LINES"),
        Txt::Separator => obfstring!(","),
        Txt::SufK => obfstring!("K"),
        Txt::SufM => obfstring!("M"),
        Txt::SufB => obfstring!("B"),
        Txt::Times => obfstring!("x"),
        Txt::Plus => obfstring!("+"),
        Txt::Space => obfstring!(" "),
        Txt::Wild => obfstring!("WILD"),
        Txt::Scatter => obfstring!("SCATTER"),
        Txt::Coins => obfstring!("COINS"),
        Txt::Lvl => obfstring!("LVL"),
        Txt::NotEnough => obfstring!("Not enough coins for this bet"),
        Txt::FinishBonus => obfstring!("Finish your bonus first"),
        Txt::BetLocked => obfstring!("Level up to unlock higher bets"),
        Txt::BigWin => obfstring!("BIG WIN"),
        Txt::MegaWin => obfstring!("MEGA WIN"),
        Txt::EpicWin => obfstring!("EPIC WIN"),
        Txt::Catch => obfstring!("FISHERMAN COLLECTS"),
        Txt::Expands => obfstring!("JOKER EXPANDS"),
        Txt::Lightning => obfstring!("ZEUS LIGHTNING"),
        Txt::Of => obfstring!(" / "),
        Txt::IceFishing => obfstring!("ICE FISHING"),
        Txt::FishingBonus => obfstring!("FISHING BONUS"),
        Txt::HoldToReel => obfstring!("HOLD TO REEL IN"),
        Txt::FishOn => obfstring!("FISH ON!"),
        Txt::YouCaught => obfstring!("YOU CAUGHT"),
        Txt::Features => obfstring!("WILD FEATURES"),
        Txt::WheelPrizes => obfstring!("ICE FISHING WHEEL"),
        Txt::Tension => obfstring!("Keep the line in the green zone"),
    }
}

pub fn texts() -> Vec<String> {
    ALL_TXT.iter().map(|t| text(*t)).collect()
}

/// Order must match `enum A` in `lib/src/core/lexicon.dart`.
#[derive(Clone, Copy)]
pub enum Ast {
    Bg1,
    Bg2,
    Candies,
    Fishes,
    Fruits2,
    Fruits,
    Gems,
    HeadJoker,
    Joker,
    Lollipop,
    Magic,
    ManWinter,
    ManWinterRod,
    ManWinterRod2,
    Badges,
    Rod,
    Bar,
    Bells,
    WheelFire,
    WheelIce,
    WheelSweet,
    WheelZeus,
    Zeus,
    GameName,
    HLoading,
    Icon,
    VLoading,
}

impl Ast {
    pub fn id(self) -> u32 {
        self as u32
    }
}

pub fn assets() -> Vec<String> {
    let play = obfstring!("Frost_Legend_assets/Frost_Legend_gameplay_assets/");
    let extra = obfstring!("Frost_Legend_assets/Frost_Legend_additional_assets/");
    let gameplay = [
        obfstring!("bg1_asset.webp"),
        obfstring!("bg2_asset.webp"),
        obfstring!("candies_asset.webp"),
        obfstring!("fishes_asset.webp"),
        obfstring!("fruits_2_asset.webp"),
        obfstring!("fruits_asset.webp"),
        obfstring!("gem_asset.webp"),
        obfstring!("head_joker_asset.webp"),
        obfstring!("Joker_asset.webp"),
        obfstring!("lollipop_asset.webp"),
        obfstring!("Magic_Objects_Set_4_objects_asset.webp"),
        obfstring!("man_winter_asset.webp"),
        obfstring!("man_winter_with_road_asset.webp"),
        obfstring!("man_winter_with_road_asset2.webp"),
        obfstring!("Reward_Badges_Set_5_objects_asset.webp"),
        obfstring!("road_asset.webp"),
        obfstring!("bar_asset.webp"),
        obfstring!("bells_asset.webp"),
        obfstring!("wheel_asset_fire.webp"),
        obfstring!("wheel_asset_ice.webp"),
        obfstring!("wheel_asset_sweet.webp"),
        obfstring!("wheel_asset_zeus.webp"),
        obfstring!("zeus_asset.webp"),
    ];
    let additional = [
        obfstring!("Game_Name.webp"),
        obfstring!("Horizontal_Loading_Screen.webp"),
        obfstring!("Icon.webp"),
        obfstring!("Vertical_Loading_Screen.webp"),
    ];
    gameplay
        .iter()
        .map(|name| format!("{play}{name}"))
        .chain(additional.iter().map(|name| format!("{extra}{name}")))
        .collect()
}

/// Order must match `enum L` in `lib/src/core/lexicon.dart`.
pub fn links() -> Vec<String> {
    vec![
        obfstring!("https://frostlegend.online/privacy-policy.html"),
        obfstring!("https://frostlegend.online/support.html"),
    ]
}

pub fn group(value: i64) -> String {
    let digits = value.unsigned_abs().to_string();
    let sep = text(Txt::Separator);
    let mut out = String::new();
    for (i, ch) in digits.chars().enumerate() {
        if i > 0 && (digits.len() - i) % 3 == 0 {
            out.push_str(&sep);
        }
        out.push(ch);
    }
    if value < 0 {
        format!("-{out}")
    } else {
        out
    }
}

pub fn join(parts: &[String]) -> String {
    parts.join(&text(Txt::Space))
}
