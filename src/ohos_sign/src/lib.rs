mod descriptor;
mod elf;
mod merkle;
mod sha256;

pub use elf::{SignError, has_valid_codesign};

// Exported under `__` names so integration tests can reach internal primitives
// without exposing them as first-class public API.
#[doc(hidden)]
pub fn __sha256_hash(data: &[u8]) -> [u8; 32] {
    sha256::hash(data)
}

#[doc(hidden)]
pub fn __merkle_root_hash(data: &[u8], cs_off: u64, cs_len: u64) -> [u8; 32] {
    merkle::root_hash(data, cs_off, cs_len)
}

#[doc(hidden)]
pub fn __descriptor_build(sign_size: u32, file_size: u64, root_hash: &[u8; 32]) -> [u8; 256] {
    descriptor::build(sign_size, file_size, root_hash)
}

/// Returns true if the ELF bytes already contain a `.codesign` section.
pub fn has_codesign(elf: &[u8]) -> bool {
    elf::has_codesign_section(elf)
}

/// Sign `elf` bytes with self-sign (flags=0x10). Fails if already signed.
/// Use `sign_selfsign_with_strip` to strip-then-sign.
pub fn sign_selfsign(elf: &[u8]) -> Result<Vec<u8>, SignError> {
    elf::sign(elf, false)
}

/// Strip existing `.codesign` section then sign.
pub fn sign_selfsign_with_strip(elf: &[u8]) -> Result<Vec<u8>, SignError> {
    elf::sign(elf, true)
}

/// Strip `.codesign` section in-place in the buffer.
/// Returns true if a section was removed, false if none present.
pub fn strip_codesign(elf: &mut Vec<u8>) -> Result<bool, SignError> {
    elf::strip(elf)
}

/// Sign a file in-place. Creates a `.unsigned` sibling during the operation.
// ohos_sign is a standalone crate (no bun_sys dependency); std::fs is the
// only available file I/O. The clippy.toml disallowed-methods exemption
// applies only to this crate.
#[allow(clippy::disallowed_methods)]
pub fn sign_selfsign_inplace(path: &std::path::Path) -> Result<(), SignError> {
    let bytes = std::fs::read(path)?;
    let signed = sign_selfsign(&bytes)?;
    std::fs::write(path, &signed)?;
    Ok(())
}

/// Sign a file in-place, stripping any existing `.codesign` section first.
#[allow(clippy::disallowed_methods)]
pub fn sign_selfsign_inplace_with_strip(path: &std::path::Path) -> Result<(), SignError> {
    let bytes = std::fs::read(path)?;
    let signed = sign_selfsign_with_strip(&bytes)?;
    std::fs::write(path, &signed)?;
    Ok(())
}

/// Inspect the ELF at `path`; when its `.codesign` section is missing or
/// fails validation, strip the stale section (if any) and re-sign in place.
/// Returns true when the file was modified, so the caller knows a spawn retry
/// is worthwhile.
///
/// Call this after the kernel refused an exec, not eagerly: the validation
/// recompute is a full-file merkle hash (~100 MB for the bun binary), and the
/// kernel re-validates anyway.
#[allow(clippy::disallowed_methods)]
pub fn repair_codesign_if_needed(path: &std::path::Path) -> bool {
    // Regular files only: fs::read on a char device (e.g. argv0=/dev/zero,
    // which exec rejects with EACCES and lands here) never reaches EOF.
    if !matches!(std::fs::metadata(path), Ok(m) if m.is_file()) {
        return false;
    }
    let bytes = match std::fs::read(path) {
        Ok(bytes) => bytes,
        Err(_) => return false,
    };
    if bytes.len() <= 4 || bytes[..4] != [0x7f, 0x45, 0x4c, 0x46] {
        return false;
    }
    if has_valid_codesign(&bytes) {
        return false;
    }
    sign_selfsign_inplace_with_strip(path).is_ok()
}
