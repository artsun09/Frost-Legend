use crate::catalog::{catalog, jackpot_name, room_maths, short_amount};
use crate::lexicon::{Txt, assets, group, join, links, text, texts};
use crate::math::{
    BETS, DAILY_COOLDOWN_SECS, DAILY_WHEEL, Feature, JACKPOT_FEED, Prize, REFILL_AMOUNT, RoomMath,
    jackpot_value, level_reward, max_bet_index, win_tier, xp_for_spin, xp_to_next,
};
use crate::profile::{Profile, ROOM_COUNT};
use crate::rng::Rng;
use crate::signals::{
    BootRequest, ChangeBet, EnterRoom, Lexicon, LineWin, NotificationsAnswered, PlayerState,
    RefillRequest, SpinOutcome, SpinRequest, StateUpdate, Toast, WheelOutcome, WheelSpinRequest,
};
use crate::vault::Vault;
use rinf::RustSignal;
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tokio::sync::mpsc::UnboundedReceiver;

pub enum Command {
    Boot(BootRequest),
    Enter(EnterRoom),
    Bet(ChangeBet),
    Spin(SpinRequest),
    Wheel(WheelSpinRequest),
    Refill(RefillRequest),
    Notifications(NotificationsAnswered),
}

pub async fn run(mut inbox: UnboundedReceiver<Command>) {
    let mut engine = Engine::new();
    let mut clock = tokio::time::interval(Duration::from_secs(1));
    loop {
        tokio::select! {
            command = inbox.recv() => match command {
                Some(command) => engine.handle(command),
                None => break,
            },
            _ = clock.tick() => engine.tick(),
        }
    }
}

fn now() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

fn clock_label(seconds: i64) -> String {
    let s = seconds.max(0);
    format!("{:02}:{:02}:{:02}", s / 3600, (s / 60) % 60, s % 60)
}

struct Engine {
    profile: Profile,
    vault: Option<Vault>,
    rng: Rng,
    maths: Vec<RoomMath>,
    room: i32,
    booted: bool,
    last_daily_ready: bool,
}

impl Engine {
    fn new() -> Self {
        Engine {
            profile: Profile::default(),
            vault: None,
            rng: Rng::from_entropy(),
            maths: room_maths(),
            room: -1,
            booted: false,
            last_daily_ready: false,
        }
    }

    fn handle(&mut self, command: Command) {
        match command {
            Command::Boot(req) => self.boot(req),
            _ if !self.booted => {}
            Command::Enter(req) => self.enter(req.room),
            Command::Bet(req) => self.change_bet(req.step),
            Command::Spin(_) => self.spin(),
            Command::Wheel(req) => self.spin_wheel(req.daily),
            Command::Refill(req) => self.refill(req.accepted),
            Command::Notifications(_) => {
                self.profile.notifications_asked = true;
                self.persist();
                self.push_state();
            }
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
        if p.fs_room >= ROOM_COUNT as i32 || p.fs_left == 0 {
            p.fs_room = -1;
            p.fs_left = 0;
            p.fs_total = 0;
            p.fs_win = 0;
        }
        if p.wheel_room >= ROOM_COUNT as i32 {
            p.wheel_room = -1;
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

    fn room_math(&self) -> Option<&RoomMath> {
        usize::try_from(self.room).ok().and_then(|r| self.maths.get(r))
    }

    fn in_free_spins(&self) -> bool {
        self.room >= 0 && self.profile.fs_room == self.room && self.profile.fs_left > 0
    }

    fn daily_wait(&self) -> i64 {
        (self.profile.daily_last + DAILY_COOLDOWN_SECS - now()).max(0)
    }

    fn state(&self) -> PlayerState {
        let p = &self.profile;
        let bet = self.bet();
        let max_index = max_bet_index(p.level) as u32;
        let in_fs = self.in_free_spins();
        let jackpot_room = usize::try_from(self.room).unwrap_or(0).min(ROOM_COUNT - 1);
        let wait = self.daily_wait();
        PlayerState {
            balance: p.balance,
            bet,
            bet_index: p.bet_index,
            can_bet_down: !in_fs && p.bet_index > 0,
            can_bet_up: !in_fs && p.bet_index < max_index,
            level: p.level,
            xp: p.xp,
            xp_next: xp_to_next(p.level),
            level_label: join(&[text(Txt::Lvl), p.level.to_string()]),
            room: self.room,
            free_spins_left: if in_fs { p.fs_left } else { 0 },
            free_spins_total: if in_fs { p.fs_total } else { 0 },
            free_spins_win: if in_fs { p.fs_win } else { 0 },
            free_spins_label: if in_fs {
                format!(
                    "{}{}{}",
                    p.fs_total - p.fs_left,
                    text(Txt::Of),
                    p.fs_total
                )
            } else {
                String::new()
            },
            fs_multiplier: self.room_math().map(|m| m.fs_multiplier).unwrap_or(1),
            wheel_pending: self.room >= 0 && p.wheel_room == self.room,
            daily_ready: wait == 0,
            daily_label: if wait == 0 { text(Txt::SpinNow) } else { clock_label(wait) },
            refill_ready: p.balance < BETS[0] && !in_fs,
            refill_amount: REFILL_AMOUNT,
            jackpots: (0..4)
                .map(|j| jackpot_value(j, bet, p.pools[jackpot_room][j]))
                .collect(),
            notifications_asked: p.notifications_asked,
            spins: p.spins,
            biggest_win: p.biggest_win,
        }
    }

    fn push_state(&self) {
        StateUpdate { state: self.state() }.send_signal_to_dart();
    }

    fn tick(&mut self) {
        if !self.booted {
            return;
        }
        let ready = self.daily_wait() == 0;
        if self.room < 0 || ready != self.last_daily_ready {
            self.last_daily_ready = ready;
            self.push_state();
        }
    }

    fn enter(&mut self, room: i32) {
        if room < 0 {
            self.room = -1;
            self.push_state();
            return;
        }
        let Some(math) = usize::try_from(room).ok().and_then(|r| self.maths.get(r)) else {
            return;
        };
        if self.profile.level < math.unlock_level {
            self.toast(Txt::LockedRoom);
            return;
        }
        self.room = room;
        self.push_state();
    }

    fn change_bet(&mut self, step: i32) {
        if self.in_free_spins() {
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
            free_spins_added: 0,
            free_spins_finished: false,
            level_up: false,
            level_reward: 0,
            state: self.state(),
        }
        .send_signal_to_dart();
    }

    fn spin(&mut self) {
        let Ok(room) = usize::try_from(self.room) else {
            return self.reject_spin();
        };
        if room >= self.maths.len() || self.profile.wheel_room == self.room {
            return self.reject_spin();
        }
        let free_spin = self.in_free_spins();
        let bet = self.bet();
        if !free_spin {
            if self.profile.balance < bet {
                self.toast(Txt::NotEnough);
                return self.reject_spin();
            }
            self.profile.balance -= bet;
            for (pool, feed) in self.profile.pools[room].iter_mut().zip(JACKPOT_FEED) {
                *pool += bet * feed / 1_000;
            }
        }

        let result = self.maths[room].spin(&mut self.rng, bet, free_spin);
        let feature = self.maths[room].feature;

        self.profile.balance += result.total_win;
        self.profile.spins += 1;
        self.profile.biggest_win = self.profile.biggest_win.max(result.total_win);

        let mut finished = false;
        if free_spin {
            let p = &mut self.profile;
            p.fs_win += result.total_win;
            p.fs_left = p.fs_left.saturating_sub(1) + result.free_spins_added;
            p.fs_total += result.free_spins_added;
            if p.fs_left == 0 {
                finished = true;
            }
        } else if result.wheel_triggered {
            self.profile.wheel_room = self.room;
        }

        let (level_up, reward) = self.grant_xp(xp_for_spin(bet));

        let feature_label = if result.lightning {
            join(&[
                text(Txt::Lightning),
                format!("{}{}", text(Txt::Times), result.multiplier),
            ])
        } else if result.collect_win > 0 {
            text(Txt::Catch)
        } else if feature == Feature::ExpandingWild && !result.expanded.is_empty() {
            text(Txt::Expands)
        } else {
            String::new()
        };

        let tier = win_tier(result.total_win, bet);
        let tier_label = match tier {
            3 => text(Txt::EpicWin),
            2 => text(Txt::MegaWin),
            1 => text(Txt::BigWin),
            _ => String::new(),
        };

        let outcome_state = self.state();
        let fs_total_win = self.profile.fs_win;
        if finished {
            let p = &mut self.profile;
            p.fs_room = -1;
            p.fs_total = 0;
            p.fs_win = 0;
        }
        self.persist();

        let mut state = if finished { self.state() } else { outcome_state };
        if finished {
            state.free_spins_win = fs_total_win;
        }

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
            free_spins_added: result.free_spins_added,
            free_spins_finished: finished,
            level_up,
            level_reward: reward,
            state,
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

    fn spin_wheel(&mut self, daily: bool) {
        if daily {
            if self.daily_wait() > 0 {
                self.toast(Txt::ComeBack);
                return;
            }
            let weights: Vec<u32> = DAILY_WHEEL.iter().map(|(_, w)| *w).collect();
            let segment = self.rng.weighted(&weights);
            let coins = DAILY_WHEEL[segment].0;
            self.profile.balance += coins;
            self.profile.daily_last = now();
            self.persist();
            WheelOutcome {
                daily: true,
                segment: segment as u32,
                coins,
                free_spins: 0,
                jackpot: -1,
                headline: join(&[group(coins), text(Txt::Coins)]),
                state: self.state(),
            }
            .send_signal_to_dart();
            return;
        }

        let Ok(room) = usize::try_from(self.room) else { return };
        if self.profile.wheel_room != self.room || room >= self.maths.len() {
            return;
        }
        let segment = self.maths[room].spin_wheel(&mut self.rng);
        let prize = self.maths[room].wheel[segment].prize;
        let bet = self.bet();
        let (coins, free_spins, jackpot, headline) = match prize {
            Prize::Coins(m) => (m * bet, 0, -1, join(&[group(m * bet), text(Txt::Coins)])),
            Prize::FreeSpins(n) => (0, n, -1, join(&[n.to_string(), text(Txt::FreeSpins)])),
            Prize::Jackpot(j) => {
                let value = jackpot_value(j, bet, self.profile.pools[room][j]);
                self.profile.pools[room][j] = 0;
                (value, 0, j as i32, join(&[jackpot_name(j), text(Txt::Jackpot)]))
            }
        };
        let p = &mut self.profile;
        p.wheel_room = -1;
        p.balance += coins;
        p.biggest_win = p.biggest_win.max(coins);
        if free_spins > 0 {
            if p.fs_room != self.room {
                p.fs_left = 0;
                p.fs_total = 0;
                p.fs_win = 0;
            }
            p.fs_room = self.room;
            p.fs_left += free_spins;
            p.fs_total += free_spins;
        }
        self.persist();
        WheelOutcome {
            daily: false,
            segment: segment as u32,
            coins,
            free_spins,
            jackpot,
            headline,
            state: self.state(),
        }
        .send_signal_to_dart();
    }

    fn refill(&mut self, accepted: bool) {
        if !accepted || self.profile.balance >= BETS[0] || self.in_free_spins() {
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
