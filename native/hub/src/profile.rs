use crate::math::START_BALANCE;

const MAGIC: u32 = 0x464C_0003;
/// Multi-room layout; only balance, bet and level progress carry over.
const MAGIC_ROOMS: u32 = 0x464C_0002;

#[derive(Clone)]
pub struct Profile {
    pub balance: i64,
    pub bet_index: u32,
    pub level: u32,
    pub xp: i64,
    pub pools: [i64; 4],
    pub wheel_pending: bool,
    /// Fish pool waiting to be reeled in, or -1.
    pub fish_pending: i32,
    /// Bet that triggered the pending bonus, so prizes match the trigger.
    pub bonus_bet: i64,
    pub spins: i64,
    pub biggest_win: i64,
}

impl Default for Profile {
    fn default() -> Self {
        Profile {
            balance: START_BALANCE,
            bet_index: 2,
            level: 1,
            xp: 0,
            pools: [0; 4],
            wheel_pending: false,
            fish_pending: -1,
            bonus_bet: 0,
            spins: 0,
            biggest_win: 0,
        }
    }
}

struct Reader<'a> {
    bytes: &'a [u8],
    at: usize,
}

impl Reader<'_> {
    fn take<const N: usize>(&mut self) -> Option<[u8; N]> {
        let slice = self.bytes.get(self.at..self.at + N)?;
        self.at += N;
        slice.try_into().ok()
    }
    fn i64(&mut self) -> Option<i64> {
        self.take::<8>().map(i64::from_le_bytes)
    }
    fn u32(&mut self) -> Option<u32> {
        self.take::<4>().map(u32::from_le_bytes)
    }
    fn i32(&mut self) -> Option<i32> {
        self.take::<4>().map(i32::from_le_bytes)
    }
}

impl Profile {
    pub fn encode(&self) -> Vec<u8> {
        let mut out = Vec::with_capacity(128);
        out.extend_from_slice(&MAGIC.to_le_bytes());
        out.extend_from_slice(&self.balance.to_le_bytes());
        out.extend_from_slice(&self.bet_index.to_le_bytes());
        out.extend_from_slice(&self.level.to_le_bytes());
        out.extend_from_slice(&self.xp.to_le_bytes());
        for pool in &self.pools {
            out.extend_from_slice(&pool.to_le_bytes());
        }
        out.extend_from_slice(&u32::from(self.wheel_pending).to_le_bytes());
        out.extend_from_slice(&self.fish_pending.to_le_bytes());
        out.extend_from_slice(&self.bonus_bet.to_le_bytes());
        out.extend_from_slice(&self.spins.to_le_bytes());
        out.extend_from_slice(&self.biggest_win.to_le_bytes());
        out
    }

    pub fn decode(bytes: &[u8]) -> Option<Profile> {
        let mut r = Reader { bytes, at: 0 };
        let magic = r.u32()?;
        if magic != MAGIC && magic != MAGIC_ROOMS {
            return None;
        }
        let balance = r.i64()?;
        let bet_index = r.u32()?;
        let level = r.u32()?.max(1);
        let xp = r.i64()?;
        if magic == MAGIC_ROOMS {
            return Some(Profile {
                balance,
                bet_index,
                level,
                xp,
                ..Profile::default()
            });
        }
        let mut pools = [0i64; 4];
        for pool in pools.iter_mut() {
            *pool = r.i64()?;
        }
        Some(Profile {
            balance,
            bet_index,
            level,
            xp,
            pools,
            wheel_pending: r.u32()? != 0,
            fish_pending: r.i32()?,
            bonus_bet: r.i64()?,
            spins: r.i64()?,
            biggest_win: r.i64()?,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::Profile;
    use crate::rng::Rng;
    use crate::vault::Vault;

    #[test]
    fn profile_survives_encrypted_round_trip() {
        let dir = std::env::temp_dir().join("frost_vault_test");
        let _ = std::fs::create_dir_all(&dir);
        let dir = dir.to_string_lossy().to_string();
        let mut profile = Profile::default();
        profile.balance = 123_456;
        profile.pools[3] = 77;
        profile.fish_pending = 2;
        let vault = Vault::open(&dir);
        let mut rng = Rng::seeded(7);
        assert!(vault.store(&profile.encode(), &mut rng));
        let raw = std::fs::read(std::path::Path::new(&dir).join("frost.vault")).unwrap_or_default();
        assert!(!raw.windows(8).any(|w| w == 123_456i64.to_le_bytes()));
        let loaded = vault.load().and_then(|b| Profile::decode(&b));
        assert!(loaded.as_ref().is_some_and(|p| p.balance == 123_456 && p.pools[3] == 77 && p.fish_pending == 2));
        assert!(Vault::open("elsewhere").load().is_none());
    }
}
