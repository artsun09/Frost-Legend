use rinf::{DartSignal, RustSignal, SignalPiece};
use serde::{Deserialize, Serialize};

#[derive(Deserialize, DartSignal)]
pub struct BootRequest {
    pub storage_dir: String,
}

#[derive(Deserialize, DartSignal)]
pub struct EnterRoom {
    pub room: i32,
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
    pub daily: bool,
}

#[derive(Deserialize, DartSignal)]
pub struct RefillRequest {
    pub accepted: bool,
}

#[derive(Deserialize, DartSignal)]
pub struct NotificationsAnswered {
    pub granted: bool,
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
pub struct WheelDef {
    pub asset: u32,
    pub rim: WheelRim,
    pub offset_deg: f32,
    pub labels: Vec<String>,
    pub colors: Vec<u32>,
    pub kinds: Vec<u32>,
}

#[derive(Clone, Serialize, SignalPiece)]
pub struct RoomDef {
    pub title: String,
    pub tagline: String,
    pub feature_title: String,
    pub feature_text: String,
    pub lock_label: String,
    pub background: u32,
    pub tint: u32,
    pub accent: u32,
    pub frame: u32,
    pub mascot: Sprite,
    pub card_art: Sprite,
    pub unlock_level: u32,
    pub symbols: Vec<SymbolDef>,
    pub wheel: WheelDef,
}

#[derive(Serialize, RustSignal)]
pub struct Catalog {
    pub rooms: Vec<RoomDef>,
    pub paylines: Vec<u32>,
    pub daily_wheel: WheelDef,
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
    pub room: i32,
    pub free_spins_left: u32,
    pub free_spins_total: u32,
    pub free_spins_win: i64,
    pub free_spins_label: String,
    pub fs_multiplier: u32,
    pub wheel_pending: bool,
    pub daily_ready: bool,
    pub daily_label: String,
    pub refill_ready: bool,
    pub refill_amount: i64,
    pub jackpots: Vec<i64>,
    pub notifications_asked: bool,
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
    pub free_spins_added: u32,
    pub free_spins_finished: bool,
    pub level_up: bool,
    pub level_reward: i64,
    pub state: PlayerState,
}

#[derive(Serialize, RustSignal)]
pub struct WheelOutcome {
    pub daily: bool,
    pub segment: u32,
    pub coins: i64,
    pub free_spins: u32,
    pub jackpot: i32,
    pub headline: String,
    pub state: PlayerState,
}

#[derive(Serialize, RustSignal)]
pub struct Toast {
    pub text: String,
}
