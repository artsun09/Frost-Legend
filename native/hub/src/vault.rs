use crate::rng::Rng;
use chacha20poly1305::aead::Aead;
use chacha20poly1305::{ChaCha20Poly1305, Key, KeyInit, Nonce};
use obfstr::{obfbytes, obfstr};
use sha2::{Digest, Sha256};
use std::path::PathBuf;

const NONCE_LEN: usize = 12;

pub struct Vault {
    path: PathBuf,
    staging: PathBuf,
    key: [u8; 32],
}

impl Vault {
    pub fn open(dir: &str) -> Self {
        let mut hasher = Sha256::new();
        hasher.update(obfbytes!(b"fr0st-l3gend::vault::v1::c7a2e94b"));
        hasher.update(dir.as_bytes());
        hasher.update(obfbytes!(b"::stonepath"));
        let key: [u8; 32] = hasher.finalize().into();

        let base = PathBuf::from(dir);
        Vault {
            path: base.join(obfstr!("frost.vault")),
            staging: base.join(obfstr!("frost.vault.tmp")),
            key,
        }
    }

    fn cipher(&self) -> ChaCha20Poly1305 {
        ChaCha20Poly1305::new(Key::from_slice(&self.key))
    }

    pub fn load(&self) -> Option<Vec<u8>> {
        let sealed = std::fs::read(&self.path).ok()?;
        if sealed.len() <= NONCE_LEN {
            return None;
        }
        let (nonce, body) = sealed.split_at(NONCE_LEN);
        self.cipher().decrypt(Nonce::from_slice(nonce), body).ok()
    }

    pub fn store(&self, plain: &[u8], rng: &mut Rng) -> bool {
        let mut nonce = [0u8; NONCE_LEN];
        rng.fill(&mut nonce);
        let Ok(body) = self.cipher().encrypt(Nonce::from_slice(&nonce), plain) else {
            return false;
        };
        let mut sealed = Vec::with_capacity(NONCE_LEN + body.len());
        sealed.extend_from_slice(&nonce);
        sealed.extend_from_slice(&body);
        std::fs::write(&self.staging, &sealed).is_ok()
            && std::fs::rename(&self.staging, &self.path).is_ok()
    }
}
