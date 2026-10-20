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

/// What a WILD does on top of substituting.
#[derive(Clone, Copy, PartialEq, Eq)]
pub enum WildPower {
    /// Collects the coin value of every fish on screen.
    Collect,
    /// Grows to cover its whole reel on reels 2-4.
    Expand,
    /// Multiplies the spin's line and collect wins.
    Lightning,
}

/// One of the three fishing bonus pools on the wheel.
#[derive(Clone, Copy, PartialEq, Eq)]
pub enum Fish {
    Blue,
    Orange,
    Red,
}

pub const FISH_KINDS: [Fish; 3] = [Fish::Blue, Fish::Orange, Fish::Red];

impl Fish {
    pub fn index(self) -> usize {
        match self {
            Fish::Blue => 0,
            Fish::Orange => 1,
            Fish::Red => 2,
        }
    }

    pub fn from_index(index: i32) -> Option<Fish> {
        usize::try_from(index).ok().and_then(|i| FISH_KINDS.get(i).copied())
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum Segment {
    /// Pays this many total bets.
    Coins(i64),
    /// Starts the fishing bonus with this pool.
    Fishing(Fish),
}

/// Bonus wheel, clockwise from the pointer. Every segment is the same size
/// and therefore equally likely.
pub const WHEEL: [Segment; 24] = [
    Segment::Coins(2),
    Segment::Coins(5),
    Segment::Coins(2),
    Segment::Fishing(Fish::Blue),
    Segment::Coins(2),
    Segment::Coins(10),
    Segment::Coins(5),
    Segment::Coins(2),
    Segment::Fishing(Fish::Orange),
    Segment::Coins(5),
    Segment::Coins(2),
    Segment::Coins(20),
    Segment::Coins(2),
    Segment::Coins(5),
    Segment::Fishing(Fish::Blue),
    Segment::Coins(2),
    Segment::Coins(10),
    Segment::Coins(5),
    Segment::Coins(2),
    Segment::Fishing(Fish::Red),
    Segment::Coins(20),
    Segment::Coins(5),
    Segment::Coins(10),
    Segment::Coins(2),
];

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum Catch {
    /// Pays this many total bets.
    Multiplier(i64),
    Jackpot(usize),
}

const BLUE_CATCH: [(Catch, u32); 7] = [
    (Catch::Multiplier(10), 30),
    (Catch::Multiplier(15), 26),
    (Catch::Multiplier(20), 20),
    (Catch::Multiplier(25), 12),
    (Catch::Multiplier(40), 7),
    (Catch::Multiplier(50), 4),
    (Catch::Jackpot(0), 1),
];

const ORANGE_CATCH: [(Catch, u32); 7] = [
    (Catch::Multiplier(25), 30),
    (Catch::Multiplier(35), 25),
    (Catch::Multiplier(50), 20),
    (Catch::Multiplier(75), 12),
    (Catch::Multiplier(100), 7),
    (Catch::Jackpot(0), 4),
    (Catch::Jackpot(1), 2),
];

const RED_CATCH: [(Catch, u32); 8] = [
    (Catch::Multiplier(50), 30),
    (Catch::Multiplier(75), 25),
    (Catch::Multiplier(100), 18),
    (Catch::Multiplier(150), 12),
    (Catch::Multiplier(250), 6),
    (Catch::Jackpot(1), 4),
    (Catch::Jackpot(2), 2),
    (Catch::Jackpot(3), 1),
];

pub fn catch_table(fish: Fish) -> &'static [(Catch, u32)] {
    match fish {
        Fish::Blue => &BLUE_CATCH,
        Fish::Orange => &ORANGE_CATCH,
        Fish::Red => &RED_CATCH,
    }
}

pub struct SlotMath {
    pub weights: Vec<u32>,
    pub pays: Vec<[i64; 3]>,
    pub wilds: Vec<(usize, WildPower)>,
    pub scatter: usize,
    pub collectors: Vec<usize>,
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
    pub total_win: i64,
    pub wheel_triggered: bool,
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

pub fn pick<T: Copy>(rng: &mut Rng, table: &[(T, u32)]) -> T {
    let weights: Vec<u32> = table.iter().map(|(_, w)| *w).collect();
    table[rng.weighted(&weights)].0
}

impl SlotMath {
    fn is_wild(&self, symbol: usize) -> bool {
        self.wilds.iter().any(|(s, _)| *s == symbol)
    }

    fn power_of(&self, symbol: usize) -> Option<WildPower> {
        self.wilds.iter().find(|(s, _)| *s == symbol).map(|(_, p)| *p)
    }

    fn draw_reel(&self, rng: &mut Rng, reel: usize) -> [usize; ROWS] {
        let mut weights = self.weights.clone();
        if reel == 0 {
            for (wild, _) in &self.wilds {
                weights[*wild] = 0;
            }
        }
        let mut column = [0usize; ROWS];
        for slot in column.iter_mut() {
            let symbol = rng.weighted(&weights);
            if self.is_wild(symbol) {
                for (wild, _) in &self.wilds {
                    weights[*wild] = 0;
                }
            }
            if symbol == self.scatter {
                weights[symbol] = 0;
            }
            *slot = symbol;
        }
        column
    }

    pub fn spin(&self, rng: &mut Rng, bet: i64) -> SpinResult {
        let mut grid = [0usize; CELLS];
        for reel in 0..REELS {
            let column = self.draw_reel(rng, reel);
            for (row, symbol) in column.iter().enumerate() {
                grid[cell(reel, row)] = *symbol;
            }
        }

        let mut expanded = Vec::new();
        for reel in 1..REELS - 1 {
            let joker = (0..ROWS)
                .map(|row| grid[cell(reel, row)])
                .find(|s| self.power_of(*s) == Some(WildPower::Expand));
            if let Some(joker) = joker {
                expanded.push(reel);
                for row in 0..ROWS {
                    grid[cell(reel, row)] = joker;
                }
            }
        }

        let mut cell_values = [0i64; CELLS];
        for (index, symbol) in grid.iter().enumerate() {
            if self.collectors.contains(symbol) {
                cell_values[index] = bet * pick(rng, &FISH_VALUES) / 100;
            }
        }

        let hits = self.evaluate_lines(&grid, bet);
        let line_total: i64 = hits.iter().map(|h| h.amount).sum();

        let scatter_cells: Vec<usize> = (0..CELLS).filter(|i| grid[*i] == self.scatter).collect();
        let scatter_count = scatter_cells.len().min(SCATTER_PAYS.len() - 1);
        let scatter_win = bet * SCATTER_PAYS[scatter_count];

        let fishermen = grid
            .iter()
            .filter(|s| self.power_of(**s) == Some(WildPower::Collect))
            .count() as i64;
        let collect_win = cell_values.iter().sum::<i64>() * fishermen.min(3);

        let zeus = grid.iter().any(|s| self.power_of(*s) == Some(WildPower::Lightning));
        let multiplier = if zeus && line_total + collect_win > 0 {
            pick(rng, &LIGHTNING)
        } else {
            1
        };

        let total_win = (line_total + collect_win) * i64::from(multiplier) + scatter_win;

        SpinResult {
            grid,
            cell_values,
            expanded,
            hits,
            wheel_triggered: scatter_cells.len() >= 3,
            scatter_cells,
            scatter_win,
            collect_win,
            multiplier,
            total_win,
        }
    }

    fn evaluate_lines(&self, grid: &[usize; CELLS], bet: i64) -> Vec<LineHit> {
        let mut hits = Vec::new();
        for (index, line) in PAYLINES.iter().enumerate() {
            let symbols: Vec<usize> = (0..REELS).map(|reel| grid[cell(reel, line[reel])]).collect();

            let wild_run = symbols.iter().take_while(|s| self.is_wild(**s)).count();
            let (mut symbol, mut count, mut pay) = (symbols[0], wild_run, 0);
            if wild_run >= 3 {
                pay = self.pays[symbols[0]][wild_run - 3];
            }

            let base = symbols.iter().copied().find(|s| !self.is_wild(*s));
            if let Some(base) = base.filter(|b| *b != self.scatter) {
                let run = symbols
                    .iter()
                    .take_while(|s| **s == base || self.is_wild(**s))
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

pub const REFILL_AMOUNT: i64 = 25_000;
pub const START_BALANCE: i64 = 50_000;

#[cfg(test)]
mod tests {
    use super::{BETS, Catch, JACKPOT_BASE, Segment, WHEEL, catch_table, max_bet_index, pick};
    use crate::catalog::slot_math;
    use crate::rng::Rng;

    #[test]
    fn return_to_player_is_in_social_range() {
        let math = slot_math();
        let bet = BETS[3];
        let mut rng = Rng::seeded(42);
        let spins = 1_000_000;
        let mut base_win = 0i64;
        let mut line_win = 0i64;
        let mut collect_win = 0i64;
        let mut scatter_win = 0i64;
        let mut wheel_coins = 0i64;
        let mut fishing = 0i64;
        let mut hits = 0u32;
        let mut triggers = 0u32;
        for _ in 0..spins {
            let r = math.spin(&mut rng, bet);
            base_win += r.total_win;
            line_win += r.hits.iter().map(|h| h.amount).sum::<i64>();
            collect_win += r.collect_win;
            scatter_win += r.scatter_win;
            if r.total_win > 0 {
                hits += 1;
            }
            if r.wheel_triggered {
                triggers += 1;
                match WHEEL[rng.below(WHEEL.len() as u64) as usize] {
                    Segment::Coins(m) => wheel_coins += m * bet,
                    Segment::Fishing(fish) => match pick(&mut rng, catch_table(fish)) {
                        Catch::Multiplier(m) => fishing += m * bet,
                        Catch::Jackpot(j) => fishing += JACKPOT_BASE[j] * bet,
                    },
                }
            }
        }
        let staked = bet * spins as i64;
        let pct = |v: i64| v as f64 * 100.0 / staked as f64;
        let total = pct(base_win + wheel_coins + fishing);
        println!(
            "rtp {total:.1}% (lines {:.1}% + collect {:.1}% + scatter {:.1}% = base {:.1}%, wheel {:.1}%, fishing {:.1}%), hit {:.1}%, trigger 1/{}",
            pct(line_win),
            pct(collect_win),
            pct(scatter_win),
            pct(base_win),
            pct(wheel_coins),
            pct(fishing),
            hits as f64 * 100.0 / spins as f64,
            spins / triggers.max(1)
        );
        assert!((90.0..=98.0).contains(&total), "rtp {total:.1}% out of range");
        assert_eq!(max_bet_index(1), 3);
    }
}
