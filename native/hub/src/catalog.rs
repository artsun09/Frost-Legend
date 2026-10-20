use crate::lexicon::{Ast, Txt, join, text};
use crate::math::{
    DAILY_WHEEL, Feature, KIND_REGULAR, KIND_SCATTER, KIND_WILD, PAYLINES, Prize, RoomMath,
    WheelSeg,
};
use crate::signals::{Catalog, RoomDef, Sprite, SymbolDef, WheelDef, WheelRim};
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
}

fn sym(sprite: Sprite, weight: u32, pays: [i64; 3], glow: u32) -> Sym {
    Sym {
        sprite,
        kind: KIND_REGULAR,
        weight,
        pays,
        glow,
    }
}

fn wild(sprite: Sprite, weight: u32) -> Sym {
    Sym {
        sprite,
        kind: KIND_WILD,
        weight,
        pays: [100, 400, 1_500],
        glow: 0xFFFFE27A,
    }
}

fn scatter(weight: u32) -> Sym {
    Sym {
        sprite: badge(0),
        kind: KIND_SCATTER,
        weight,
        pays: [0, 0, 0],
        glow: 0xFFFF7A2E,
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

const LOW: [[i64; 3]; 5] = [[5, 15, 50], [5, 15, 60], [10, 25, 75], [10, 30, 100], [15, 40, 125]];

struct Room {
    title: String,
    tagline: String,
    feature_title: String,
    feature_text: String,
    background: Ast,
    tint: u32,
    accent: u32,
    frame: u32,
    mascot: Sprite,
    card_art: Sprite,
    unlock_level: u32,
    feature: Feature,
    fs_multiplier: u32,
    /// Percentage applied to every line pay of the room.
    pay_scale: i64,
    symbols: Vec<Sym>,
    collectors: Vec<usize>,
    wheel_asset: Ast,
    wheel_offset: f32,
    wheel: Vec<WheelSeg>,
}

fn scaled(pays: [i64; 3], scale: i64) -> [i64; 3] {
    pays.map(|p| (p * scale + 50) / 100)
}

fn seg(prize: Prize, weight: u32) -> WheelSeg {
    WheelSeg { prize, weight }
}

fn ten_segment_wheel() -> Vec<WheelSeg> {
    vec![
        seg(Prize::Coins(10), 36),
        seg(Prize::FreeSpins(8), 26),
        seg(Prize::Jackpot(0), 22),
        seg(Prize::Coins(20), 26),
        seg(Prize::FreeSpins(10), 18),
        seg(Prize::Jackpot(1), 10),
        seg(Prize::Coins(40), 14),
        seg(Prize::FreeSpins(15), 10),
        seg(Prize::Jackpot(2), 3),
        seg(Prize::Jackpot(3), 1),
    ]
}

fn rooms() -> Vec<Room> {
    vec![
        Room {
            title: obfstring!("FROZEN LAKE"),
            tagline: obfstring!("Ice fishing for legendary catches"),
            feature_title: obfstring!("FISHERMAN COLLECT"),
            feature_text: obfstring!(
                "Every fish carries a coin value. When the Fisherman WILD lands, he collects all fish on the screen, up to 3 times."
            ),
            background: Ast::Bg1,
            tint: 0xFF0B2A5C,
            accent: 0xFF7FE3FF,
            frame: 0xFF9FD8FF,
            mascot: sprite(Ast::ManWinterRod, 1.0, 28.0, 300.0, 646.0),
            card_art: sprite(Ast::ManWinterRod2, 1.0, 30.0, 225.0, 649.0),
            unlock_level: 1,
            feature: Feature::FishCollect,
            fs_multiplier: 2,
            pay_scale: 122,
            symbols: vec![
                sym(gem(2), 22, LOW[0], 0xFF3DFF8F),
                sym(gem(4), 21, LOW[1], 0xFFC46BFF),
                sym(gem(5), 20, LOW[2], 0xFFFFB524),
                sym(gem(1), 19, LOW[3], 0xFFFF4D5E),
                sym(gem(0), 18, LOW[4], 0xFF4DA6FF),
                sym(fish(1), 12, [20, 60, 200], 0xFF4DC3FF),
                sym(fish(0), 11, [25, 75, 250], 0xFFFF6B4D),
                sym(sprite(Ast::Rod, 5.0, 280.0, 110.0, 200.0), 9, [30, 100, 300], 0xFF9FD8FF),
                sym(fish(2), 7, [50, 150, 500], 0xFFFFD84D),
                wild(sprite(Ast::ManWinter, 37.0, 22.0, 230.0, 230.0), 6),
                scatter(5),
            ],
            collectors: vec![5, 6, 8],
            wheel_asset: Ast::WheelIce,
            wheel_offset: -15.0,
            wheel: vec![
                seg(Prize::Coins(10), 34),
                seg(Prize::FreeSpins(8), 24),
                seg(Prize::Jackpot(0), 20),
                seg(Prize::Coins(15), 28),
                seg(Prize::FreeSpins(10), 18),
                seg(Prize::Jackpot(1), 10),
                seg(Prize::Coins(25), 20),
                seg(Prize::FreeSpins(12), 12),
                seg(Prize::Coins(40), 12),
                seg(Prize::Jackpot(2), 3),
                seg(Prize::FreeSpins(15), 8),
                seg(Prize::Jackpot(3), 1),
            ],
        },
        Room {
            title: obfstring!("JOKER CIRCUS"),
            tagline: obfstring!("Classic fruits under the big top"),
            feature_title: obfstring!("EXPANDING JOKER"),
            feature_text: obfstring!(
                "A Joker WILD landing on reels 2, 3 or 4 expands to cover the whole reel before wins are paid."
            ),
            background: Ast::Bg2,
            tint: 0xFF4A0A12,
            accent: 0xFFFFC640,
            frame: 0xFFFFB13B,
            mascot: sprite(Ast::Joker, 14.0, 14.0, 279.0, 727.0),
            card_art: sprite(Ast::Joker, 14.0, 14.0, 279.0, 727.0),
            unlock_level: 2,
            feature: Feature::ExpandingWild,
            fs_multiplier: 2,
            pay_scale: 146,
            symbols: vec![
                sym(fruit(3), 22, LOW[0], 0xFFB04DFF),
                sym(fruit2(2), 21, LOW[1], 0xFFFF4D4D),
                sym(fruit2(1), 20, LOW[2], 0xFFFF9A24),
                sym(fruit2(0), 19, LOW[3], 0xFFFFE04D),
                sym(fruit(1), 18, LOW[4], 0xFF9B4DFF),
                sym(fruit(0), 12, [20, 60, 200], 0xFFFF3D5A),
                sym(fruit(2), 11, [25, 75, 250], 0xFF4DFF7A),
                sym(sprite(Ast::Bells, 11.0, 8.0, 75.0, 83.0), 9, [30, 100, 300], 0xFFFFD24D),
                sym(sprite(Ast::Bar, 3.0, 26.0, 95.0, 49.0), 7, [50, 150, 500], 0xFFFF3D3D),
                wild(sprite(Ast::HeadJoker, 33.0, 35.0, 233.0, 227.0), 3),
                scatter(5),
            ],
            collectors: vec![],
            wheel_asset: Ast::WheelFire,
            wheel_offset: 0.0,
            wheel: ten_segment_wheel(),
        },
        Room {
            title: obfstring!("SWEET OLYMPUS"),
            tagline: obfstring!("Candy treasures of the thunder god"),
            feature_title: obfstring!("ZEUS LIGHTNING"),
            feature_text: obfstring!(
                "Zeus may strike any winning spin with a x2, x3, x5 or x10 multiplier. During free spins he strikes twice as often."
            ),
            background: Ast::Bg1,
            tint: 0xFF2A1458,
            accent: 0xFFFFD86B,
            frame: 0xFFE6C36A,
            mascot: sprite(Ast::Zeus, 2.0, 41.0, 315.0, 706.0),
            card_art: sprite(Ast::Zeus, 2.0, 41.0, 315.0, 706.0),
            unlock_level: 4,
            feature: Feature::Lightning,
            fs_multiplier: 1,
            pay_scale: 175,
            symbols: vec![
                sym(candy(3), 21, LOW[0], 0xFF4DA6FF),
                sym(candy(2), 20, LOW[1], 0xFF4DFF7A),
                sym(candy(1), 19, LOW[2], 0xFFC46BFF),
                sym(candy(0), 18, LOW[3], 0xFFFF4D6B),
                sym(sprite(Ast::Lollipop, 15.0, 14.0, 145.0, 137.0), 17, LOW[4], 0xFFFF6BC4),
                sym(magic(2), 12, [15, 50, 150], 0xFFFFC24D),
                sym(magic(3), 11, [20, 60, 200], 0xFFFF6B4D),
                sym(magic(0), 10, [25, 75, 250], 0xFFFFD84D),
                sym(magic(1), 9, [30, 100, 300], 0xFFFFE07A),
                sym(gem(3), 7, [50, 150, 500], 0xFF6BC4FF),
                wild(sprite(Ast::Zeus, 45.0, 30.0, 230.0, 230.0), 5),
                scatter(5),
            ],
            collectors: vec![],
            wheel_asset: Ast::WheelZeus,
            wheel_offset: 0.0,
            wheel: ten_segment_wheel(),
        },
    ]
}

pub fn room_maths() -> Vec<RoomMath> {
    rooms()
        .into_iter()
        .map(|room| {
            let wild = room.symbols.iter().position(|s| s.kind == KIND_WILD).unwrap_or(0);
            let scatter = room
                .symbols
                .iter()
                .position(|s| s.kind == KIND_SCATTER)
                .unwrap_or(0);
            RoomMath {
                weights: room.symbols.iter().map(|s| s.weight).collect(),
                pays: room.symbols.iter().map(|s| scaled(s.pays, room.pay_scale)).collect(),
                kinds: room.symbols.iter().map(|s| s.kind).collect(),
                wild,
                scatter,
                feature: room.feature,
                collectors: room.collectors,
                fs_multiplier: room.fs_multiplier,
                wheel: room.wheel,
                unlock_level: room.unlock_level,
            }
        })
        .collect()
}

pub fn jackpot_name(index: usize) -> String {
    match index {
        0 => obfstring!("MINI"),
        1 => obfstring!("MINOR"),
        2 => obfstring!("MAJOR"),
        _ => obfstring!("GRAND"),
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

pub fn prize_label(prize: Prize) -> String {
    match prize {
        Prize::Coins(m) => format!("{}{m}", text(Txt::Times)),
        Prize::FreeSpins(n) => join(&[n.to_string(), text(Txt::Spins)]),
        Prize::Jackpot(j) => jackpot_name(j),
    }
}

fn prize_kind(prize: Prize) -> u32 {
    match prize {
        Prize::Coins(_) => 0,
        Prize::FreeSpins(_) => 1,
        Prize::Jackpot(j) => 2 + j as u32,
    }
}

fn prize_color(prize: Prize) -> u32 {
    match prize {
        Prize::Coins(_) => 0xFFFFE27A,
        Prize::FreeSpins(_) => 0xFF8CF7FF,
        Prize::Jackpot(0) => 0xFF5DFF8A,
        Prize::Jackpot(1) => 0xFF6BB8FF,
        Prize::Jackpot(2) => 0xFFD48CFF,
        Prize::Jackpot(_) => 0xFFFF6B5A,
    }
}

fn wheel_rim(asset: Ast) -> WheelRim {
    let (hub_x, hub_y, disc, pointer_half, pointer_top, pointer_tip) = match asset {
        Ast::WheelIce => (0.5, 0.505, 0.35, 0.098, 0.458, 0.276),
        Ast::WheelFire => (0.5, 0.505, 0.336, 0.084, 0.462, 0.311),
        Ast::WheelZeus => (0.502, 0.507, 0.326, 0.076, 0.438, 0.27),
        _ => (0.5, 0.505, 0.353, 0.076, 0.449, 0.328),
    };
    WheelRim {
        hub_x,
        hub_y,
        disc,
        pointer_half,
        pointer_top,
        pointer_tip,
    }
}

pub fn daily_wheel() -> WheelDef {
    WheelDef {
        asset: Ast::WheelSweet.id(),
        rim: wheel_rim(Ast::WheelSweet),
        offset_deg: 0.0,
        labels: DAILY_WHEEL.iter().map(|(v, _)| short_amount(*v)).collect(),
        colors: DAILY_WHEEL
            .iter()
            .map(|(v, _)| if *v >= 25_000 { 0xFFFFF27A } else { 0xFFFFFFFF })
            .collect(),
        kinds: DAILY_WHEEL.iter().map(|_| 0).collect(),
    }
}

pub fn catalog() -> Catalog {
    let room_defs = rooms()
        .into_iter()
        .map(|room| {
            let lock_label = join(&[text(Txt::Lvl), room.unlock_level.to_string()]);
            RoomDef {
                title: room.title,
                tagline: room.tagline,
                feature_title: room.feature_title,
                feature_text: room.feature_text,
                lock_label,
                background: room.background.id(),
                tint: room.tint,
                accent: room.accent,
                frame: room.frame,
                mascot: room.mascot,
                card_art: room.card_art,
                unlock_level: room.unlock_level,
                symbols: room
                    .symbols
                    .iter()
                    .map(|s| SymbolDef {
                        sprite: s.sprite.clone(),
                        kind: s.kind,
                        pays: scaled(s.pays, room.pay_scale).to_vec(),
                        glow: s.glow,
                        badge: match s.kind {
                            KIND_WILD => text(Txt::Wild),
                            _ => String::new(),
                        },
                    })
                    .collect(),
                wheel: WheelDef {
                    asset: room.wheel_asset.id(),
                    rim: wheel_rim(room.wheel_asset),
                    offset_deg: room.wheel_offset,
                    labels: room.wheel.iter().map(|s| prize_label(s.prize)).collect(),
                    colors: room.wheel.iter().map(|s| prize_color(s.prize)).collect(),
                    kinds: room.wheel.iter().map(|s| prize_kind(s.prize)).collect(),
                },
            }
        })
        .collect();

    Catalog {
        rooms: room_defs,
        paylines: PAYLINES.iter().flatten().map(|r| *r as u32).collect(),
        daily_wheel: daily_wheel(),
        jackpot_badges: (1..5).map(badge).collect(),
        jackpot_colors: vec![0xFF3DDC6B, 0xFF3D8BFF, 0xFFA64DFF, 0xFFFF3D3D],
        jackpot_names: (0..4).map(jackpot_name).collect(),
        info_lines: vec![
            obfstring!("WILD substitutes for every symbol except SCATTER."),
            obfstring!("3 or more SCATTERS anywhere spin the Bonus Wheel: coins, free spins or a jackpot."),
            obfstring!("3 SCATTERS during free spins award 5 more free spins."),
            obfstring!("Wins pay left to right on 20 lines. Values shown are per line at the current bet."),
            obfstring!("Jackpots grow with every spin in the realm."),
        ],
    }
}
