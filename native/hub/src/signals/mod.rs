use rinf::{DartSignal, RustSignal, SignalPiece};
use serde::{Deserialize, Serialize};

#[derive(Deserialize, DartSignal)]
pub struct BootRequest {
    pub storage_dir: String,
}

#[derive(Deserialize, DartSignal)]
pub struct ChangeBet {
    pub step: i32,
}

#[derive(Deserialize, DartSignal)]
pub struct SpinRequest {
    pub auto: bool,
}

#[derive(Deserialize, DartSignal)]
pub struct WheelSpinRequest {
    pub confirm: bool,
}

#[derive(Deserialize, DartSignal)]
pub struct FishRequest {
    pub confirm: bool,
}

#[derive(Deserialize, DartSignal)]
pub struct RefillRequest {
    pub accepted: bool,
}

#[derive(Serialize, RustSignal)]
pub struct Lexicon {
    pub texts: Vec<String>,
    pub assets: Vec<String>,
    pub links: Vec<String>,
}

#[derive(Clone, Serialize, SignalPiece)]
pub struct Sprite {
    pub asset: u32,
    pub x: f32,
    pub y: f32,
    pub w: f32,
    pub h: f32,
}

#[derive(Clone, Serialize, SignalPiece)]
pub struct SymbolDef {
    pub sprite: Sprite,
    pub kind: u32,
    pub pays: Vec<i64>,
    pub glow: u32,
    pub badge: String,
}

/// Wheel art geometry: hub position as fractions of the image size, the
/// spinning disc radius and the rim pointer triangle as fractions of the
/// image width, measured from the hub.
#[derive(Clone, Serialize, SignalPiece)]
pub struct WheelRim {
    pub hub_x: f32,
    pub hub_y: f32,
    pub disc: f32,
    pub pointer_half: f32,
    pub pointer_top: f32,
    pub pointer_tip: f32,
}

#[derive(Clone, Serialize, SignalPiece)]
pub struct FishDef {
    pub name: String,
    pub sprite: Sprite,
    pub color: u32,
    pub prizes: String,
}

/// `fish` holds -1 for a coin segment or the index into `Catalog.fish`.
#[derive(Clone, Serialize, SignalPiece)]
pub struct WheelDef {
    pub asset: u32,
    pub rim: WheelRim,
    pub hub_label: String,
    pub labels: Vec<String>,
    pub fish: Vec<i32>,
    pub light: u32,
    pub dark: u32,
}

#[derive(Clone, Serialize, SignalPiece)]
pub struct FeatureDef {
    pub title: String,
    pub text: String,
    pub sprite: Sprite,
    pub color: u32,
}

#[derive(Clone, Serialize, SignalPiece)]
pub struct SlotDef {
    pub title: String,
    pub background: u32,
    pub fishing_background: u32,
    pub tint: u32,
    pub accent: u32,
    pub frame: u32,
    pub left_mascot: Sprite,
    pub right_mascot: Sprite,
    pub fisherman: Sprite,
    pub angler: Sprite,
    pub rod: Sprite,
    pub decor_wheels: Vec<u32>,
    pub symbols: Vec<SymbolDef>,
    pub features: Vec<FeatureDef>,
}

#[derive(Serialize, RustSignal)]
pub struct Catalog {
    pub slot: SlotDef,
    pub paylines: Vec<u32>,
    pub wheel: WheelDef,
    pub fish: Vec<FishDef>,
    pub jackpot_badges: Vec<Sprite>,
    pub jackpot_colors: Vec<u32>,
    pub jackpot_names: Vec<String>,
    pub info_lines: Vec<String>,
}

#[derive(Clone, Serialize, SignalPiece)]
pub struct PlayerState {
    pub balance: i64,
    pub bet: i64,
    pub bet_index: u32,
    pub can_bet_down: bool,
    pub can_bet_up: bool,
    pub level: u32,
    pub xp: i64,
    pub xp_next: i64,
    pub level_label: String,
    pub wheel_pending: bool,
    pub fish_pending: i32,
    pub refill_ready: bool,
    pub refill_amount: i64,
    pub jackpots: Vec<i64>,
    pub spins: i64,
    pub biggest_win: i64,
}

#[derive(Serialize, RustSignal)]
pub struct StateUpdate {
    pub state: PlayerState,
}

#[derive(Clone, Serialize, SignalPiece)]
pub struct LineWin {
    pub line: u32,
    pub symbol: u32,
    pub count: u32,
    pub amount: i64,
    pub cells: Vec<u32>,
}

#[derive(Serialize, RustSignal)]
pub struct SpinOutcome {
    pub accepted: bool,
    pub grid: Vec<u32>,
    pub cell_values: Vec<i64>,
    pub expanded_reels: Vec<u32>,
    pub wins: Vec<LineWin>,
    pub scatter_cells: Vec<u32>,
    pub scatter_win: i64,
    pub collect_win: i64,
    pub multiplier: u32,
    pub feature_label: String,
    pub total_win: i64,
    pub tier: u32,
    pub tier_label: String,
    pub wheel_triggered: bool,
    pub level_up: bool,
    pub level_reward: i64,
    pub state: PlayerState,
}

#[derive(Serialize, RustSignal)]
pub struct WheelOutcome {
    pub segment: u32,
    pub coins: i64,
    pub fish: i32,
    pub headline: String,
    pub state: PlayerState,
}

/// `jackpot` holds -1 for a multiplier catch.
#[derive(Serialize, RustSignal)]
pub struct FishOutcome {
    pub fish: i32,
    pub multiplier: i64,
    pub jackpot: i32,
    pub coins: i64,
    pub plate: String,
    pub headline: String,
    pub state: PlayerState,
}

#[derive(Serialize, RustSignal)]
pub struct Toast {
    pub text: String,
}
