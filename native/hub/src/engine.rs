use crate::catalog::{catalog, catch_label, fish_name, jackpot_name, short_amount, slot_math};
use crate::lexicon::{Txt, assets, group, join, links, text, texts};
use crate::math::{
    BETS, Catch, Fish, JACKPOT_FEED, REFILL_AMOUNT, Segment, SlotMath, WHEEL, catch_table,
    jackpot_value, level_reward, max_bet_index, pick, win_tier, xp_for_spin, xp_to_next,
};
use crate::profile::Profile;
use crate::rng::Rng;
use crate::signals::{
    BootRequest, ChangeBet, FishOutcome, Lexicon, LineWin, PlayerState, RefillRequest,
    SpinOutcome, StateUpdate, Toast, WheelOutcome,
};
use crate::vault::Vault;
use rinf::RustSignal;
use tokio::sync::mpsc::UnboundedReceiver;

pub enum Command {
    Boot(BootRequest),
    Bet(ChangeBet),
    Spin,
    Wheel,
    Fish,
    Refill(RefillRequest),
}

pub async fn run(mut inbox: UnboundedReceiver<Command>) {
    let mut engine = Engine::new();
    while let Some(command) = inbox.recv().await {
        engine.handle(command);
    }
}

struct Engine {
    profile: Profile,
    vault: Option<Vault>,
    rng: Rng,
    math: SlotMath,
    booted: bool,
}

impl Engine {
    fn new() -> Self {
        Engine {
            profile: Profile::default(),
            vault: None,
            rng: Rng::from_entropy(),
            math: slot_math(),
            booted: false,
        }
    }

    fn handle(&mut self, command: Command) {
        match command {
            Command::Boot(req) => self.boot(req),
            _ if !self.booted => {}
            Command::Bet(req) => self.change_bet(req.step),
            Command::Spin => self.spin(),
            Command::Wheel => self.spin_wheel(),
            Command::Fish => self.reel_in(),
            Command::Refill(req) => self.refill(req.accepted),
        }
    }

    fn boot(&mut self, req: BootRequest) {
        Lexicon {
            texts: texts(),
            assets: assets(),
            links: links(),
        }
        .send_signal_to_dart();
        catalog().send_signal_to_dart();

        if !req.storage_dir.is_empty() {
            let vault = Vault::open(&req.storage_dir);
            if let Some(profile) = vault.load().and_then(|bytes| Profile::decode(&bytes)) {
                self.profile = profile;
            }
            self.vault = Some(vault);
        }
        self.sanitize();
        self.booted = true;
        self.persist();
        self.push_state();
    }

    fn sanitize(&mut self) {
        let p = &mut self.profile;
        p.bet_index = p.bet_index.min(max_bet_index(p.level) as u32);
        if Fish::from_index(p.fish_pending).is_none() {
            p.fish_pending = -1;
        }
        if p.wheel_pending && p.fish_pending >= 0 {
            p.wheel_pending = false;
        }
        if !BETS.contains(&p.bonus_bet) {
            p.bonus_bet = BETS[p.bet_index as usize];
        }
        p.balance = p.balance.max(0);
    }

    fn persist(&mut self) {
        if let Some(vault) = &self.vault {
            vault.store(&self.profile.encode(), &mut self.rng);
        }
    }

    fn toast(&self, t: Txt) {
        Toast { text: text(t) }.send_signal_to_dart();
    }

    fn bet(&self) -> i64 {
        BETS[self.profile.bet_index as usize]
    }

    fn bonus_pending(&self) -> bool {
        self.profile.wheel_pending || self.profile.fish_pending >= 0
    }

    fn state(&self) -> PlayerState {
        let p = &self.profile;
        let bet = self.bet();
        let max_index = max_bet_index(p.level) as u32;
        let locked = self.bonus_pending();
        PlayerState {
            balance: p.balance,
            bet,
            bet_index: p.bet_index,
            can_bet_down: !locked && p.bet_index > 0,
            can_bet_up: !locked && p.bet_index < max_index,
            level: p.level,
            xp: p.xp,
            xp_next: xp_to_next(p.level),
            level_label: join(&[text(Txt::Lvl), p.level.to_string()]),
            wheel_pending: p.wheel_pending,
            fish_pending: p.fish_pending,
            refill_ready: p.balance < BETS[0] && !locked,
            refill_amount: REFILL_AMOUNT,
            jackpots: (0..4).map(|j| jackpot_value(j, bet, p.pools[j])).collect(),
            spins: p.spins,
            biggest_win: p.biggest_win,
        }
    }

    fn push_state(&self) {
        StateUpdate { state: self.state() }.send_signal_to_dart();
    }

    fn change_bet(&mut self, step: i32) {
        if self.bonus_pending() {
            self.toast(Txt::FinishBonus);
            return;
        }
        let max_index = max_bet_index(self.profile.level) as i64;
        let wanted = i64::from(self.profile.bet_index) + i64::from(step.signum());
        if wanted > max_index {
            self.toast(Txt::BetLocked);
        }
        self.profile.bet_index = wanted.clamp(0, max_index) as u32;
        self.persist();
        self.push_state();
    }

    fn reject_spin(&self) {
        SpinOutcome {
            accepted: false,
            grid: Vec::new(),
            cell_values: Vec::new(),
            expanded_reels: Vec::new(),
            wins: Vec::new(),
            scatter_cells: Vec::new(),
            scatter_win: 0,
            collect_win: 0,
            multiplier: 1,
            feature_label: String::new(),
            total_win: 0,
            tier: 0,
            tier_label: String::new(),
            wheel_triggered: false,
            level_up: false,
            level_reward: 0,
            state: self.state(),
        }
        .send_signal_to_dart();
    }

    fn spin(&mut self) {
        if self.bonus_pending() {
            self.toast(Txt::FinishBonus);
            return self.reject_spin();
        }
        let bet = self.bet();
        if self.profile.balance < bet {
            self.toast(Txt::NotEnough);
            return self.reject_spin();
        }
        self.profile.balance -= bet;
        for (pool, feed) in self.profile.pools.iter_mut().zip(JACKPOT_FEED) {
            *pool += bet * feed / 1_000;
        }

        let result = self.math.spin(&mut self.rng, bet);

        self.profile.balance += result.total_win;
        self.profile.spins += 1;
        self.profile.biggest_win = self.profile.biggest_win.max(result.total_win);
        if result.wheel_triggered {
            self.profile.wheel_pending = true;
            self.profile.bonus_bet = bet;
        }

        let (level_up, reward) = self.grant_xp(xp_for_spin(bet));

        let mut labels = Vec::new();
        if result.collect_win > 0 {
            labels.push(text(Txt::Catch));
        }
        if !result.expanded.is_empty() {
            labels.push(text(Txt::Expands));
        }
        if result.multiplier > 1 {
            labels.push(join(&[
                text(Txt::Lightning),
                format!("{}{}", text(Txt::Times), result.multiplier),
            ]));
        }
        let feature_label = labels.last().cloned().unwrap_or_default();

        let tier = win_tier(result.total_win, bet);
        let tier_label = match tier {
            3 => text(Txt::EpicWin),
            2 => text(Txt::MegaWin),
            1 => text(Txt::BigWin),
            _ => String::new(),
        };

        self.persist();

        SpinOutcome {
            accepted: true,
            grid: result.grid.iter().map(|s| *s as u32).collect(),
            cell_values: result.cell_values.to_vec(),
            expanded_reels: result.expanded.iter().map(|r| *r as u32).collect(),
            wins: result
                .hits
                .iter()
                .map(|h| LineWin {
                    line: h.line as u32,
                    symbol: h.symbol as u32,
                    count: h.count as u32,
                    amount: h.amount,
                    cells: h.cells.iter().map(|c| *c as u32).collect(),
                })
                .collect(),
            scatter_cells: result.scatter_cells.iter().map(|c| *c as u32).collect(),
            scatter_win: result.scatter_win,
            collect_win: result.collect_win,
            multiplier: result.multiplier,
            feature_label,
            total_win: result.total_win,
            tier,
            tier_label,
            wheel_triggered: result.wheel_triggered,
            level_up,
            level_reward: reward,
            state: self.state(),
        }
        .send_signal_to_dart();
    }

    fn grant_xp(&mut self, xp: i64) -> (bool, i64) {
        let p = &mut self.profile;
        p.xp += xp;
        let mut levelled = false;
        let mut reward = 0;
        while p.xp >= xp_to_next(p.level) {
            p.xp -= xp_to_next(p.level);
            p.level += 1;
            reward += level_reward(p.level);
            levelled = true;
        }
        p.balance += reward;
        (levelled, reward)
    }

    fn spin_wheel(&mut self) {
        if !self.profile.wheel_pending {
            return;
        }
        let segment = self.rng.below(WHEEL.len() as u64) as usize;
        let bet = self.profile.bonus_bet;
        let p = &mut self.profile;
        p.wheel_pending = false;
        let (coins, fish, headline) = match WHEEL[segment] {
            Segment::Coins(m) => {
                let coins = m * bet;
                p.balance += coins;
                p.biggest_win = p.biggest_win.max(coins);
                (coins, -1, join(&[group(coins), text(Txt::Coins)]))
            }
            Segment::Fishing(f) => {
                p.fish_pending = f.index() as i32;
                (0, f.index() as i32, join(&[fish_name(f), text(Txt::FishingBonus)]))
            }
        };
        self.persist();
        WheelOutcome {
            segment: segment as u32,
            coins,
            fish,
            headline,
            state: self.state(),
        }
        .send_signal_to_dart();
    }

    fn reel_in(&mut self) {
        let Some(fish) = Fish::from_index(self.profile.fish_pending) else {
            return;
        };
        let bet = self.profile.bonus_bet;
        let catch = pick(&mut self.rng, catch_table(fish));
        let p = &mut self.profile;
        let (coins, multiplier, jackpot, headline) = match catch {
            Catch::Multiplier(m) => (m * bet, m, -1, join(&[group(m * bet), text(Txt::Coins)])),
            Catch::Jackpot(j) => {
                let value = jackpot_value(j, bet, p.pools[j]);
                p.pools[j] = 0;
                (value, 0, j as i32, join(&[jackpot_name(j), text(Txt::Jackpot)]))
            }
        };
        p.fish_pending = -1;
        p.balance += coins;
        p.biggest_win = p.biggest_win.max(coins);
        self.persist();
        FishOutcome {
            fish: fish.index() as i32,
            multiplier,
            jackpot,
            coins,
            plate: catch_label(catch),
            headline,
            state: self.state(),
        }
        .send_signal_to_dart();
    }

    fn refill(&mut self, accepted: bool) {
        if !accepted || self.profile.balance >= BETS[0] || self.bonus_pending() {
            return;
        }
        self.profile.balance += REFILL_AMOUNT;
        self.persist();
        self.push_state();
        Toast {
            text: join(&[
                format!("{}{}", text(Txt::Plus), short_amount(REFILL_AMOUNT)),
                text(Txt::Coins),
            ]),
        }
        .send_signal_to_dart();
    }
}
