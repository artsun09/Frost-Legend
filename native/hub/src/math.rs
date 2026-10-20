use crate::rng::Rng;

pub const REELS: usize = 5;
pub const ROWS: usize = 3;
pub const CELLS: usize = REELS * ROWS;
pub const LINE_DIVISOR: i64 = 20;

pub const KIND_REGULAR: u32 = 0;
pub const KIND_WILD: u32 = 1;
pub const KIND_SCATTER: u32 = 2;

pub const BETS: [i64; 10] = [100, 200, 500, 1_000, 2_000, 5_000, 10_000, 20_000, 50_000, 100_000];

pub const JACKPOT_BASE: [i64; 4] = [20, 50, 200, 1_000];
pub const JACKPOT_FEED: [i64; 4] = [6, 4, 2, 1];

pub const PAYLINES: [[usize; REELS]; 20] = [
    [1, 1, 1, 1, 1],
    [0, 0, 0, 0, 0],
    [2, 2, 2, 2, 2],
    [0, 1, 2, 1, 0],
    [2, 1, 0, 1, 2],
    [0, 0, 1, 2, 2],
    [2, 2, 1, 0, 0],
    [1, 0, 0, 0, 1],
    [1, 2, 2, 2, 1],
    [0, 1, 1, 1, 0],
    [2, 1, 1, 1, 2],
    [1, 0, 1, 2, 1],
    [1, 2, 1, 0, 1],
    [0, 1, 0, 1, 0],
    [2, 1, 2, 1, 2],
    [1, 1, 0, 1, 1],
    [1, 1, 2, 1, 1],
    [0, 2, 0, 2, 0],
    [2, 0, 2, 0, 2],
    [0, 2, 2, 2, 0],
];

const SCATTER_PAYS: [i64; 6] = [0, 0, 0, 2, 5, 20];

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum Feature {
    /// Fish carry coin values that every WILD on screen collects.
    FishCollect,
    /// A WILD on reels 2-4 grows to cover the whole reel.
    ExpandingWild,
    /// Zeus throws a random multiplier onto a winning spin.
    Lightning,
}

#[derive(Clone, Copy)]
pub enum Prize {
    Coins(i64),
    FreeSpins(u32),
    Jackpot(usize),
}

#[derive(Clone, Copy)]
pub struct WheelSeg {
    pub prize: Prize,
    pub weight: u32,
}

pub struct RoomMath {
    pub weights: Vec<u32>,
    pub pays: Vec<[i64; 3]>,
    pub kinds: Vec<u32>,
    pub wild: usize,
    pub scatter: usize,
    pub feature: Feature,
    pub collectors: Vec<usize>,
    pub fs_multiplier: u32,
    pub wheel: Vec<WheelSeg>,
    pub unlock_level: u32,
}

pub struct LineHit {
    pub line: usize,
    pub symbol: usize,
    pub count: usize,
    pub amount: i64,
    pub cells: Vec<usize>,
}

pub struct SpinResult {
    pub grid: [usize; CELLS],
    pub cell_values: [i64; CELLS],
    pub expanded: Vec<usize>,
    pub hits: Vec<LineHit>,
    pub scatter_cells: Vec<usize>,
    pub scatter_win: i64,
    pub collect_win: i64,
    pub multiplier: u32,
    pub lightning: bool,
    pub total_win: i64,
    pub wheel_triggered: bool,
    pub free_spins_added: u32,
}

pub fn cell(reel: usize, row: usize) -> usize {
    reel * ROWS + row
}

/// Fish value in hundredths of the total bet.
const FISH_VALUES: [(i64, u32); 7] = [
    (5, 30),
    (10, 28),
    (20, 20),
    (25, 10),
    (50, 7),
    (100, 4),
    (250, 1),
];

const LIGHTNING: [(u32, u32); 4] = [(2, 46), (3, 30), (5, 17), (10, 7)];

fn pick_pair<T: Copy>(rng: &mut Rng, table: &[(T, u32)]) -> T {
    let weights: Vec<u32> = table.iter().map(|(_, w)| *w).collect();
    table[rng.weighted(&weights)].0
}

impl RoomMath {
    fn draw_reel(&self, rng: &mut Rng, reel: usize) -> [usize; ROWS] {
        let mut weights = self.weights.clone();
        if reel == 0 {
            weights[self.wild] = 0;
        }
        let mut column = [0usize; ROWS];
        for slot in column.iter_mut() {
            let symbol = rng.weighted(&weights);
            if symbol == self.scatter || symbol == self.wild {
                weights[symbol] = 0;
            }
            *slot = symbol;
        }
        column
    }

    pub fn spin(&self, rng: &mut Rng, bet: i64, free_spin: bool) -> SpinResult {
        let mut grid = [0usize; CELLS];
        for reel in 0..REELS {
            let column = self.draw_reel(rng, reel);
            for (row, symbol) in column.iter().enumerate() {
                grid[cell(reel, row)] = *symbol;
            }
        }

        let mut expanded = Vec::new();
        if self.feature == Feature::ExpandingWild {
            for reel in 1..REELS - 1 {
                if (0..ROWS).any(|row| grid[cell(reel, row)] == self.wild) {
                    expanded.push(reel);
                    for row in 0..ROWS {
                        grid[cell(reel, row)] = self.wild;
                    }
                }
            }
        }

        let mut cell_values = [0i64; CELLS];
        if self.feature == Feature::FishCollect {
            for (index, symbol) in grid.iter().enumerate() {
                if self.collectors.contains(symbol) {
                    cell_values[index] = bet * pick_pair(rng, &FISH_VALUES) / 100;
                }
            }
        }

        let hits = self.evaluate_lines(&grid, bet);
        let line_total: i64 = hits.iter().map(|h| h.amount).sum();

        let scatter_cells: Vec<usize> = (0..CELLS).filter(|i| grid[*i] == self.scatter).collect();
        let scatter_count = scatter_cells.len().min(SCATTER_PAYS.len() - 1);
        let scatter_win = bet * SCATTER_PAYS[scatter_count];

        let wilds = grid.iter().filter(|s| **s == self.wild).count() as i64;
        let collect_win = if self.feature == Feature::FishCollect && wilds > 0 {
            cell_values.iter().sum::<i64>() * wilds.min(3)
        } else {
            0
        };

        let mut multiplier = if free_spin { self.fs_multiplier } else { 1 };
        let mut lightning = false;
        if self.feature == Feature::Lightning && line_total > 0 {
            let odds = if free_spin { 45 } else { 22 };
            if rng.chance(odds, 100) {
                lightning = true;
                multiplier = multiplier.max(1) * pick_pair(rng, &LIGHTNING);
            }
        }

        let total_win = (line_total + collect_win) * i64::from(multiplier) + scatter_win;
        let triggered = scatter_cells.len() >= 3;

        SpinResult {
            grid,
            cell_values,
            expanded,
            hits,
            scatter_cells,
            scatter_win,
            collect_win,
            multiplier,
            lightning,
            total_win,
            wheel_triggered: triggered && !free_spin,
            free_spins_added: if triggered && free_spin { 5 } else { 0 },
        }
    }

    fn evaluate_lines(&self, grid: &[usize; CELLS], bet: i64) -> Vec<LineHit> {
        let mut hits = Vec::new();
        for (index, line) in PAYLINES.iter().enumerate() {
            let symbols: Vec<usize> = (0..REELS).map(|reel| grid[cell(reel, line[reel])]).collect();

            let wild_run = symbols.iter().take_while(|s| **s == self.wild).count();
            let wild_pay = if wild_run >= 3 { self.pays[self.wild][wild_run - 3] } else { 0 };

            let base = symbols.iter().copied().find(|s| *s != self.wild);
            let (mut symbol, mut count, mut pay) = (self.wild, wild_run, wild_pay);
            if let Some(base) = base.filter(|b| *b != self.scatter) {
                let run = symbols
                    .iter()
                    .take_while(|s| **s == base || **s == self.wild)
                    .count();
                if run >= 3 && self.pays[base][run - 3] > pay {
                    symbol = base;
                    count = run;
                    pay = self.pays[base][run - 3];
                }
            }

            if pay > 0 {
                hits.push(LineHit {
                    line: index,
                    symbol,
                    count,
                    amount: pay * bet / LINE_DIVISOR,
                    cells: (0..count).map(|reel| cell(reel, line[reel])).collect(),
                });
            }
        }
        hits
    }

    pub fn spin_wheel(&self, rng: &mut Rng) -> usize {
        let weights: Vec<u32> = self.wheel.iter().map(|s| s.weight).collect();
        rng.weighted(&weights)
    }
}

pub fn jackpot_value(index: usize, bet: i64, pool: i64) -> i64 {
    JACKPOT_BASE[index] * bet + pool
}

pub fn max_bet_index(level: u32) -> usize {
    (3 + (level.saturating_sub(1) / 2) as usize).min(BETS.len() - 1)
}

pub fn xp_for_spin(bet: i64) -> i64 {
    (bet / LINE_DIVISOR).max(5)
}

pub fn xp_to_next(level: u32) -> i64 {
    let l = i64::from(level);
    400 + 250 * l * l
}

pub fn level_reward(level: u32) -> i64 {
    2_500 * i64::from(level)
}

pub fn win_tier(win: i64, bet: i64) -> u32 {
    if bet <= 0 {
        return 0;
    }
    let ratio = win / bet;
    match ratio {
        r if r >= 50 => 3,
        r if r >= 25 => 2,
        r if r >= 12 => 1,
        _ => 0,
    }
}

pub const DAILY_COOLDOWN_SECS: i64 = 4 * 3600;
pub const REFILL_AMOUNT: i64 = 25_000;
pub const START_BALANCE: i64 = 50_000;

pub const DAILY_WHEEL: [(i64, u32); 10] = [
    (2_500, 22),
    (10_000, 9),
    (5_000, 18),
    (25_000, 4),
    (3_000, 20),
    (15_000, 7),
    (4_000, 19),
    (50_000, 2),
    (7_500, 12),
    (100_000, 1),
];

pub fn daily_scale(level: u32) -> i64 {
    10 + i64::from(level.saturating_sub(1)) * 2
}

#[cfg(test)]
mod tests {
    use super::{BETS, Prize, max_bet_index};
    use crate::catalog::room_maths;
    use crate::rng::Rng;

    #[test]
    fn return_to_player_is_in_social_range() {
        let maths = room_maths();
        let bet = BETS[3];
        let mut failures = Vec::new();
        for (room, math) in maths.iter().enumerate() {
            let mut rng = Rng::seeded(42 + room as u64);
            let spins = 400_000;
            let mut base_win = 0i64;
            let mut line_win = 0i64;
            let mut collect_win = 0i64;
            let mut scatter_win = 0i64;
            let mut fs_win = 0i64;
            let mut wheel_win = 0i64;
            let mut hits = 0u32;
            let mut triggers = 0u32;
            for _ in 0..spins {
                let r = math.spin(&mut rng, bet, false);
                base_win += r.total_win;
                line_win += r.hits.iter().map(|h| h.amount).sum::<i64>();
                collect_win += r.collect_win;
                scatter_win += r.scatter_win;
                if r.total_win > 0 {
                    hits += 1;
                }
                if r.wheel_triggered {
                    triggers += 1;
                    match math.wheel[math.spin_wheel(&mut rng)].prize {
                        Prize::Coins(m) => wheel_win += m * bet,
                        Prize::Jackpot(j) => wheel_win += super::JACKPOT_BASE[j] * bet,
                        Prize::FreeSpins(n) => {
                            let mut left = n;
                            while left > 0 {
                                left -= 1;
                                let f = math.spin(&mut rng, bet, true);
                                fs_win += f.total_win;
                                left += f.free_spins_added;
                            }
                        }
                    }
                }
            }
            let staked = bet * spins as i64;
            let pct = |v: i64| v as f64 * 100.0 / staked as f64;
            println!(
                "room {room}: rtp {:.1}% (base {:.1}% = lines {:.1}% + collect {:.1}% + scatter {:.1}%, fs {:.1}%, wheel {:.1}%), hit {:.1}%, trigger 1/{}",
                pct(base_win + fs_win + wheel_win),
                pct(base_win),
                pct(line_win),
                pct(collect_win),
                pct(scatter_win),
                pct(fs_win),
                pct(wheel_win),
                hits as f64 * 100.0 / spins as f64,
                spins / triggers.max(1)
            );
            let total = pct(base_win + fs_win + wheel_win);
            if !(90.0..=98.0).contains(&total) {
                failures.push(room);
            }
        }
        assert!(failures.is_empty(), "rooms out of range: {failures:?}");
        assert_eq!(max_bet_index(1), 3);
    }
}
