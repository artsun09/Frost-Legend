use crate::math::START_BALANCE;

const MAGIC: u32 = 0x464C_0002;
pub const ROOM_COUNT: usize = 3;

#[derive(Clone)]
pub struct Profile {
    pub balance: i64,
    pub bet_index: u32,
    pub level: u32,
    pub xp: i64,
    pub daily_last: i64,
    pub pools: [[i64; 4]; ROOM_COUNT],
    pub fs_room: i32,
    pub fs_left: u32,
    pub fs_total: u32,
    pub fs_win: i64,
    pub wheel_room: i32,
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
            daily_last: 0,
            pools: [[0; 4]; ROOM_COUNT],
            fs_room: -1,
            fs_left: 0,
            fs_total: 0,
            fs_win: 0,
            wheel_room: -1,
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
        let mut out = Vec::with_capacity(256);
        out.extend_from_slice(&MAGIC.to_le_bytes());
        out.extend_from_slice(&self.balance.to_le_bytes());
        out.extend_from_slice(&self.bet_index.to_le_bytes());
        out.extend_from_slice(&self.level.to_le_bytes());
        out.extend_from_slice(&self.xp.to_le_bytes());
        out.extend_from_slice(&self.daily_last.to_le_bytes());
        out.extend_from_slice(&0u32.to_le_bytes());
        for room in &self.pools {
            for pool in room {
                out.extend_from_slice(&pool.to_le_bytes());
            }
        }
        out.extend_from_slice(&self.fs_room.to_le_bytes());
        out.extend_from_slice(&self.fs_left.to_le_bytes());
        out.extend_from_slice(&self.fs_total.to_le_bytes());
        out.extend_from_slice(&self.fs_win.to_le_bytes());
        out.extend_from_slice(&self.wheel_room.to_le_bytes());
        out.extend_from_slice(&self.spins.to_le_bytes());
        out.extend_from_slice(&self.biggest_win.to_le_bytes());
        out
    }

    pub fn decode(bytes: &[u8]) -> Option<Profile> {
        let mut r = Reader { bytes, at: 0 };
        if r.u32()? != MAGIC {
            return None;
        }
        let balance = r.i64()?;
        let bet_index = r.u32()?;
        let level = r.u32()?.max(1);
        let xp = r.i64()?;
        let daily_last = r.i64()?;
        r.u32()?;
        let mut pools = [[0i64; 4]; ROOM_COUNT];
        for room in pools.iter_mut() {
            for pool in room.iter_mut() {
                *pool = r.i64()?;
            }
        }
        Some(Profile {
            balance,
            bet_index,
            level,
            xp,
            daily_last,
            pools,
            fs_room: r.i32()?,
            fs_left: r.u32()?,
            fs_total: r.u32()?,
            fs_win: r.i64()?,
            wheel_room: r.i32()?,
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
        profile.pools[2][3] = 77;
        profile.fs_room = 1;
        let vault = Vault::open(&dir);
        let mut rng = Rng::seeded(7);
        assert!(vault.store(&profile.encode(), &mut rng));
        let raw = std::fs::read(std::path::Path::new(&dir).join("frost.vault")).unwrap_or_default();
        assert!(!raw.windows(8).any(|w| w == 123_456i64.to_le_bytes()));
        let loaded = vault.load().and_then(|b| Profile::decode(&b));
        assert!(loaded.as_ref().is_some_and(|p| p.balance == 123_456 && p.pools[2][3] == 77 && p.fs_room == 1));
        assert!(Vault::open("elsewhere").load().is_none());
    }
}
