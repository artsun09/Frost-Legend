use crate::lexicon::{Ast, Txt, join, text};
use crate::math::{
    Catch, FISH_KINDS, Fish, KIND_REGULAR, KIND_SCATTER, KIND_WILD, PAYLINES, Segment, SlotMath,
    WHEEL, WildPower, catch_table,
};
use crate::signals::{
    Catalog, FeatureDef, FishDef, SlotDef, Sprite, SymbolDef, WheelDef, WheelRim,
};
use obfstr::obfstring;

fn sprite(asset: Ast, x: f32, y: f32, w: f32, h: f32) -> Sprite {
    Sprite {
        asset: asset.id(),
        x,
        y,
        w,
        h,
    }
}

struct Sym {
    sprite: Sprite,
    kind: u32,
    weight: u32,
    pays: [i64; 3],
    glow: u32,
    power: Option<WildPower>,
}

fn sym(sprite: Sprite, weight: u32, pays: [i64; 3], glow: u32) -> Sym {
    Sym {
        sprite,
        kind: KIND_REGULAR,
        weight,
        pays,
        glow,
        power: None,
    }
}

fn wild(sprite: Sprite, weight: u32, power: WildPower, glow: u32) -> Sym {
    Sym {
        sprite,
        kind: KIND_WILD,
        weight,
        pays: [100, 400, 1_500],
        glow,
        power: Some(power),
    }
}

fn scatter(weight: u32) -> Sym {
    Sym {
        sprite: badge(0),
        kind: KIND_SCATTER,
        weight,
        pays: [0, 0, 0],
        glow: 0xFFFF7A2E,
        power: None,
    }
}

fn badge(index: usize) -> Sprite {
    const RECTS: [[f32; 4]; 5] = [
        [68.0, 11.0, 280.0, 346.0],
        [356.0, 21.0, 277.0, 336.0],
        [643.0, 21.0, 277.0, 336.0],
        [930.0, 21.0, 277.0, 336.0],
        [1215.0, 20.0, 281.0, 338.0],
    ];
    let r = RECTS[index.min(4)];
    sprite(Ast::Badges, r[0], r[1], r[2], r[3])
}

fn gem(index: usize) -> Sprite {
    const RECTS: [[f32; 4]; 6] = [
        [24.0, 9.0, 123.0, 164.0],
        [182.0, 34.0, 158.0, 130.0],
        [18.0, 283.0, 156.0, 137.0],
        [196.0, 284.0, 143.0, 146.0],
        [19.0, 541.0, 155.0, 135.0],
        [207.0, 537.0, 133.0, 143.0],
    ];
    let r = RECTS[index.min(5)];
    sprite(Ast::Gems, r[0], r[1], r[2], r[3])
}

/// 0 red, 1 blue, 2 gold.
fn fish(index: usize) -> Sprite {
    const RECTS: [[f32; 4]; 3] = [
        [15.0, 17.0, 141.0, 176.0],
        [161.0, 16.0, 144.0, 184.0],
        [318.0, 20.0, 153.0, 176.0],
    ];
    let r = RECTS[index.min(2)];
    sprite(Ast::Fishes, r[0], r[1], r[2], r[3])
}

fn fruit(index: usize) -> Sprite {
    const RECTS: [[f32; 4]; 4] = [
        [10.0, 7.0, 81.0, 81.0],
        [2.0, 112.0, 87.0, 80.0],
        [5.0, 211.0, 90.0, 72.0],
        [12.0, 301.0, 79.0, 72.0],
    ];
    let r = RECTS[index.min(3)];
    sprite(Ast::Fruits, r[0], r[1], r[2], r[3])
}

fn fruit2(index: usize) -> Sprite {
    const RECTS: [[f32; 4]; 3] = [
        [5.0, 10.0, 91.0, 74.0],
        [10.0, 108.0, 81.0, 71.0],
        [11.0, 207.0, 78.0, 70.0],
    ];
    let r = RECTS[index.min(2)];
    sprite(Ast::Fruits2, r[0], r[1], r[2], r[3])
}

fn candy(index: usize) -> Sprite {
    const RECTS: [[f32; 4]; 4] = [
        [12.0, 10.0, 110.0, 86.0],
        [20.0, 100.0, 94.0, 91.0],
        [15.0, 195.0, 100.0, 88.0],
        [8.0, 292.0, 118.0, 86.0],
    ];
    let r = RECTS[index.min(3)];
    sprite(Ast::Candies, r[0], r[1], r[2], r[3])
}

fn magic(index: usize) -> Sprite {
    const RECTS: [[f32; 4]; 4] = [
        [8.0, 17.0, 150.0, 131.0],
        [166.0, 15.0, 144.0, 128.0],
        [30.0, 166.0, 117.0, 125.0],
        [191.0, 151.0, 92.0, 147.0],
    ];
    let r = RECTS[index.min(3)];
    sprite(Ast::Magic, r[0], r[1], r[2], r[3])
}

fn fisherman_bust() -> Sprite {
    sprite(Ast::ManWinter, 37.0, 22.0, 230.0, 230.0)
}

fn joker_head() -> Sprite {
    sprite(Ast::HeadJoker, 33.0, 35.0, 233.0, 227.0)
}

fn zeus_bust() -> Sprite {
    sprite(Ast::Zeus, 45.0, 30.0, 230.0, 230.0)
}

/// Percentage applied to every line pay.
const PAY_SCALE: i64 = 79;

fn symbols() -> Vec<Sym> {
    vec![
        sym(gem(2), 20, [5, 15, 50], 0xFF3DFF8F),
        sym(candy(0), 20, [5, 15, 60], 0xFFFF4D6B),
        sym(fruit2(0), 19, [10, 25, 75], 0xFFFFE04D),
        sym(fruit(0), 19, [10, 30, 100], 0xFFFF3D5A),
        sym(gem(0), 18, [15, 40, 125], 0xFF4DA6FF),
        sym(sprite(Ast::Lollipop, 15.0, 14.0, 145.0, 137.0), 13, [20, 60, 200], 0xFFFF6BC4),
        sym(sprite(Ast::Bells, 11.0, 8.0, 75.0, 83.0), 12, [25, 75, 250], 0xFFFFD24D),
        sym(sprite(Ast::Bar, 3.0, 26.0, 95.0, 49.0), 10, [30, 100, 300], 0xFFFF3D3D),
        sym(magic(1), 8, [50, 150, 500], 0xFFFFE07A),
        sym(fish(1), 10, [15, 50, 150], 0xFF4DC3FF),
        sym(fish(2), 8, [25, 75, 250], 0xFFFFB04D),
        sym(fish(0), 6, [40, 120, 400], 0xFFFF6B4D),
        wild(fisherman_bust(), 3, WildPower::Collect, 0xFF9FE6FF),
        wild(joker_head(), 3, WildPower::Expand, 0xFFFFC640),
        wild(zeus_bust(), 3, WildPower::Lightning, 0xFFFFE27A),
        scatter(6),
    ]
}

const COLLECTORS: [usize; 3] = [9, 10, 11];

fn scaled(pays: [i64; 3]) -> [i64; 3] {
    pays.map(|p| (p * PAY_SCALE + 50) / 100)
}

pub fn slot_math() -> SlotMath {
    let symbols = symbols();
    SlotMath {
        weights: symbols.iter().map(|s| s.weight).collect(),
        pays: symbols.iter().map(|s| scaled(s.pays)).collect(),
        wilds: symbols
            .iter()
            .enumerate()
            .filter_map(|(i, s)| s.power.map(|p| (i, p)))
            .collect(),
        scatter: symbols
            .iter()
            .position(|s| s.kind == KIND_SCATTER)
            .unwrap_or(0),
        collectors: COLLECTORS.to_vec(),
    }
}

pub fn jackpot_name(index: usize) -> String {
    match index {
        0 => obfstring!("MINI"),
        1 => obfstring!("MINOR"),
        2 => obfstring!("MAJOR"),
        _ => obfstring!("GRAND"),
    }
}

pub fn fish_name(fish: Fish) -> String {
    match fish {
        Fish::Blue => obfstring!("LIL' BLUES"),
        Fish::Orange => obfstring!("BIG ORANGES"),
        Fish::Red => obfstring!("HUGE REDS"),
    }
}

pub fn fish_color(fish: Fish) -> u32 {
    match fish {
        Fish::Blue => 0xFF2F7DE1,
        Fish::Orange => 0xFFF08A1C,
        Fish::Red => 0xFFD9262B,
    }
}

fn fish_sprite(fish: Fish) -> Sprite {
    match fish {
        Fish::Blue => self::fish(1),
        Fish::Orange => self::fish(2),
        Fish::Red => self::fish(0),
    }
}

pub fn short_amount(value: i64) -> String {
    let (scaled, suffix) = if value >= 1_000_000_000 {
        (value as f64 / 1e9, text(Txt::SufB))
    } else if value >= 1_000_000 {
        (value as f64 / 1e6, text(Txt::SufM))
    } else if value >= 1_000 {
        (value as f64 / 1e3, text(Txt::SufK))
    } else {
        return value.to_string();
    };
    let rounded = (scaled * 10.0).round() / 10.0;
    if (rounded - rounded.trunc()).abs() < f64::EPSILON {
        format!("{}{suffix}", rounded as i64)
    } else {
        format!("{rounded:.1}{suffix}")
    }
}

pub fn times(value: i64) -> String {
    format!("{}{value}", text(Txt::Times))
}

pub fn catch_label(catch: Catch) -> String {
    match catch {
        Catch::Multiplier(m) => times(m),
        Catch::Jackpot(j) => jackpot_name(j),
    }
}

/// Short prize range for a fish pool, e.g. `x10 - x50 + MINI`.
fn prize_range(fish: Fish) -> String {
    let table = catch_table(fish);
    let multipliers: Vec<i64> = table
        .iter()
        .filter_map(|(c, _)| match c {
            Catch::Multiplier(m) => Some(*m),
            Catch::Jackpot(_) => None,
        })
        .collect();
    let low = multipliers.iter().min().copied().unwrap_or(0);
    let high = multipliers.iter().max().copied().unwrap_or(0);
    let mut parts = vec![times(low), obfstring!("-"), times(high)];
    for (c, _) in table {
        if let Catch::Jackpot(j) = c {
            parts.push(text(Txt::Plus));
            parts.push(jackpot_name(*j));
        }
    }
    join(&parts)
}

fn wheel_rim() -> WheelRim {
    WheelRim {
        hub_x: 0.5,
        hub_y: 0.505,
        disc: 0.35,
        pointer_half: 0.098,
        pointer_top: 0.458,
        pointer_tip: 0.276,
    }
}

fn wheel_def() -> WheelDef {
    WheelDef {
        asset: Ast::WheelIce.id(),
        rim: wheel_rim(),
        hub_label: text(Txt::IceFishing),
        labels: WHEEL
            .iter()
            .map(|s| match s {
                Segment::Coins(m) => m.to_string(),
                Segment::Fishing(f) => fish_name(*f),
            })
            .collect(),
        fish: WHEEL
            .iter()
            .map(|s| match s {
                Segment::Coins(_) => -1,
                Segment::Fishing(f) => f.index() as i32,
            })
            .collect(),
        light: 0xFFE9F3FB,
        dark: 0xFF5D7F9E,
    }
}

fn features() -> Vec<FeatureDef> {
    vec![
        FeatureDef {
            title: obfstring!("FISHERMAN WILD"),
            text: obfstring!(
                "Every fish carries a coin value. The Fisherman collects all fish on screen, once for each Fisherman, up to 3 times."
            ),
            sprite: fisherman_bust(),
            color: 0xFF7FE3FF,
        },
        FeatureDef {
            title: obfstring!("JOKER WILD"),
            text: obfstring!("On reels 2, 3 and 4 the Joker expands to cover the whole reel."),
            sprite: joker_head(),
            color: 0xFFFFC640,
        },
        FeatureDef {
            title: obfstring!("ZEUS WILD"),
            text: obfstring!("Zeus strikes every winning spin he lands on with a x2, x3, x5 or x10 multiplier."),
            sprite: zeus_bust(),
            color: 0xFFFFE27A,
        },
    ]
}

pub fn catalog() -> Catalog {
    let symbols = symbols()
        .iter()
        .map(|s| SymbolDef {
            sprite: s.sprite.clone(),
            kind: s.kind,
            pays: scaled(s.pays).to_vec(),
            glow: s.glow,
            badge: match s.kind {
                KIND_WILD => text(Txt::Wild),
                _ => String::new(),
            },
        })
        .collect();

    Catalog {
        slot: SlotDef {
            title: text(Txt::AppTitle),
            background: Ast::Bg1.id(),
            fishing_background: Ast::Bg1.id(),
            tint: 0xFF0B2A5C,
            accent: 0xFF7FE3FF,
            frame: 0xFF9FD8FF,
            left_mascot: sprite(Ast::Zeus, 2.0, 41.0, 315.0, 706.0),
            right_mascot: sprite(Ast::Joker, 14.0, 14.0, 279.0, 727.0),
            fisherman: sprite(Ast::ManWinterRod, 1.0, 28.0, 300.0, 646.0),
            angler: sprite(Ast::ManWinterRod2, 1.0, 30.0, 225.0, 649.0),
            rod: sprite(Ast::Rod, 5.0, 8.0, 152.0, 712.0),
            decor_wheels: vec![
                Ast::WheelZeus.id(),
                Ast::WheelFire.id(),
                Ast::WheelSweet.id(),
            ],
            symbols,
            features: features(),
        },
        paylines: PAYLINES.iter().flatten().map(|r| *r as u32).collect(),
        wheel: wheel_def(),
        fish: FISH_KINDS
            .iter()
            .map(|f| FishDef {
                name: fish_name(*f),
                sprite: fish_sprite(*f),
                color: fish_color(*f),
                prizes: prize_range(*f),
            })
            .collect(),
        jackpot_badges: (1..5).map(badge).collect(),
        jackpot_colors: vec![0xFF3DDC6B, 0xFF3D8BFF, 0xFFA64DFF, 0xFFFF3D3D],
        jackpot_names: (0..4).map(jackpot_name).collect(),
        info_lines: vec![
            obfstring!("WILDS substitute for every symbol except SCATTER and never land on reel 1."),
            obfstring!("3 or more SCATTERS anywhere spin the Ice Fishing wheel. Numbers pay that many total bets."),
            obfstring!("Fish segments start the fishing bonus: reel in a Lil' Blue, Big Orange or Huge Red for a multiplier or a jackpot."),
            obfstring!("Wins pay left to right on 20 lines. Values shown are per line at the current bet."),
            obfstring!("Jackpots grow with every spin."),
        ],
    }
}
