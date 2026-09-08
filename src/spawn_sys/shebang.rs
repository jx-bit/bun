// OHOS userspace shebang expansion — parsing half.
//
// A text script cannot be signed (it has nowhere to carry a .codesign
// section), so on OHOS the kernel refuses to exec it outright and the
// kernel's own binfmt_script hand-off never gets past that check. This
// module parses the `#!` line; spawn_process.rs rewrites the exec to target
// the already-signed interpreter and demotes the script to a plain argv
// entry that is only ever opened and read.
//
// Compiled on OHOS and in test builds; the tests here also run from the
// standalone mirror crate (see test notes in the PR) so they execute on any
// host without the C++ link artifacts.

use core::ffi::c_char;

/// Parsed `#!` line: interpreter path and its optional single argument.
/// Returns None for non-scripts and anything ambiguous — callers fall back
/// to the plain spawn, matching kernel behavior.
#[cfg(any(target_env = "ohos", test))]
pub(crate) fn parse_shebang(head: &[u8], at_eof: bool) -> Option<(&[u8], Option<&[u8]>)> {
    if head.len() < 2 || &head[..2] != b"#!" {
        return None;
    }
    let line_end = match bun_core::strings::index_of_char_usize(head, b'\n') {
        Some(pos) => pos,
        // No newline in what was read. When the read filled the buffer the
        // real shebang line may continue past it — treating the read length
        // as the line end would silently truncate the interpreter path (see
        // the buffer comment in ohos_expand_shebang). Only the EOF case is
        // safe to treat as the line end.
        None if !at_eof => return None,
        None => head.len(),
    };
    let line = &head[2..line_end];
    let mut i = 0usize;
    while i < line.len() && matches!(line[i], b' ' | b'\t') {
        i += 1;
    }
    let rest = &line[i..];
    let (interp, arg) = match bun_core::strings::index_of_any(rest, b" \t") {
        Some(sp) => {
            let mut j = sp;
            while j < rest.len() && matches!(rest[j], b' ' | b'\t') {
                j += 1;
            }
            let mut end = rest.len();
            while end > j && matches!(rest[end - 1], b' ' | b'\t' | b'\r') {
                end -= 1;
            }
            (
                &rest[..sp],
                if end > j { Some(&rest[j..end]) } else { None },
            )
        }
        None => {
            let mut end = rest.len();
            while end > 0 && matches!(rest[end - 1], b' ' | b'\t' | b'\r') {
                end -= 1;
            }
            (&rest[..end], None)
        }
    };
    if interp.is_empty() || interp[0] != b'/' {
        return None;
    }
    Some((interp, arg))
}

#[cfg(test)]
mod tests {
    use super::parse_shebang;

    #[test]
    fn basic() {
        assert_eq!(
            parse_shebang(b"#!/bin/sh\necho hi\n", true),
            Some((&b"/bin/sh"[..], None))
        );
    }

    #[test]
    fn single_optional_arg_is_the_whole_remainder() {
        // POSIX: everything after the interpreter is one argument.
        assert_eq!(
            parse_shebang(b"#!/usr/bin/env -S bun\n", true),
            Some((&b"/usr/bin/env"[..], Some(&b"-S bun"[..])))
        );
    }

    #[test]
    fn crlf_is_trimmed() {
        assert_eq!(
            parse_shebang(b"#!/bin/sh\r\n", true),
            Some((&b"/bin/sh"[..], None))
        );
    }

    #[test]
    fn whitespace_after_bang_is_skipped() {
        assert_eq!(
            parse_shebang(b"#!  /bin/sh\n", true),
            Some((&b"/bin/sh"[..], None))
        );
    }

    #[test]
    fn relative_interpreter_is_rejected() {
        assert_eq!(parse_shebang(b"#!bin/sh\n", true), None);
    }

    #[test]
    fn no_newline_at_eof_is_fine() {
        assert_eq!(
            parse_shebang(b"#!/bin/sh", true),
            Some((&b"/bin/sh"[..], None))
        );
    }

    #[test]
    fn no_newline_without_eof_bails() {
        // The shebang line may continue past the read window; rewriting with
        // a truncated interpreter path would repeat the kernel's 128-byte
        // truncation bug.
        assert_eq!(parse_shebang(b"#!/bin/sh", false), None);
    }

    #[test]
    fn not_a_script() {
        assert_eq!(parse_shebang(b"echo hi\n", true), None);
    }

    #[test]
    fn too_short() {
        assert_eq!(parse_shebang(b"#", true), None);
    }

    #[test]
    fn empty_interpreter_is_rejected() {
        assert_eq!(parse_shebang(b"#!  \n", true), None);
    }
}

#[cfg(test)]
mod rewrite_tests {
    use super::parse_shebang;
    use crate::shebang::{ShebangRewrite, build_rewrite};
    use std::ffi::{CStr, CString};

    fn s(p: *const std::ffi::c_char) -> String {
        unsafe { CStr::from_ptr(p).to_string_lossy().into_owned() }
    }

    /// 回归：argv 的每个条目都必须由 ShebangRewrite 持有 CString 保活。
    /// 此前可选参数的 CString 在函数退出时 drop，ptrs[1] 悬垂 ——
    /// env 收到堆垃圾字节（`env: '\310\021...': No such file or directory`），
    /// `#!/usr/bin/env bash` 类脚本全部得空输出。
    #[test]
    fn rewrite_owns_every_entry_it_points_to() {
        let head = parse_shebang(b"#!/usr/bin/env bash\necho hi\n", true).unwrap();
        let interp = CString::new(head.0).unwrap();
        let arg = head.1.map(CString::new).transpose().unwrap();
        let script = CString::new("x.sh").unwrap();
        let t1 = CString::new("arg1").unwrap();
        let t2 = CString::new("arg2").unwrap();
        let tail = [t1.as_ptr(), t2.as_ptr()];

        let rw: ShebangRewrite = build_rewrite(interp, arg, script, &tail);

        // argv 形状：[interp, arg, script, tail..., null]
        assert_eq!(rw.ptrs.len(), 6);
        assert_eq!(s(rw.ptrs[0]), "/usr/bin/env");
        assert_eq!(s(rw.ptrs[1]), "bash");
        assert_eq!(s(rw.ptrs[2]), "x.sh");
        assert_eq!(s(rw.ptrs[3]), "arg1");
        assert_eq!(s(rw.ptrs[4]), "arg2");
        assert!(rw.ptrs[5].is_null());

        // 所有权对应：每个 owned CString 恰好支撑一个指针
        assert_eq!(rw._owned.len(), 2);
        assert_eq!(rw._owned[0].as_ptr(), rw.ptrs[1]);
        assert_eq!(rw._owned[1].as_ptr(), rw.ptrs[2]);
    }

    #[test]
    fn rewrite_without_optional_arg() {
        let head = parse_shebang(b"#!/bin/sh\necho hi\n", true).unwrap();
        let interp = CString::new(head.0).unwrap();
        let script = CString::new("tool.sh").unwrap();

        let rw: ShebangRewrite = build_rewrite(interp, None, script, &[]);

        assert_eq!(rw.ptrs.len(), 3);
        assert_eq!(s(rw.ptrs[0]), "/bin/sh");
        assert_eq!(s(rw.ptrs[1]), "tool.sh");
        assert!(rw.ptrs[2].is_null());
        // 无可选参数：仅 script 需要 keepalive
        assert_eq!(rw._owned.len(), 1);
        assert_eq!(rw._owned[0].as_ptr(), rw.ptrs[1]);
    }
}

// ─── rewrite assembly（所有权先行，指针在后）─────────────────────────────

/// The rewritten exec target for a shebang script: argv is
/// `[interp, (arg), script, ...tail, null]` and every entry is backed by a
/// CString owned by this struct — alive past the posix_spawn call.
#[cfg(any(target_env = "ohos", test))]
pub(crate) struct ShebangRewrite {
    pub(crate) interp: std::ffi::CString,
    // Keepalive for the argv entries in `ptrs`. Never read — the leading
    // underscore marks it as intentionally unread.
    pub(crate) _owned: Vec<std::ffi::CString>,
    pub(crate) ptrs: Vec<*const c_char>,
}

/// Assemble the rewritten argv from the parsed shebang parts.
///
/// Ownership first, pointers second: every CString is moved into `_owned`
/// before its pointer is taken, so no entry can dangle. (A previous version
/// borrowed the optional argument for the pointer while dropping the CString
/// at return — `env` then received freed heap bytes as its argument.)
#[cfg(any(target_env = "ohos", test))]
pub(crate) fn build_rewrite(
    interp: std::ffi::CString,
    arg: Option<std::ffi::CString>,
    script: std::ffi::CString,
    tail: &[*const c_char],
) -> ShebangRewrite {
    let mut owned = Vec::with_capacity(2);
    if let Some(a) = &arg {
        owned.push(a.clone());
    }
    owned.push(script);

    let mut ptrs = Vec::with_capacity(owned.len() + tail.len() + 2);
    ptrs.push(interp.as_ptr());
    for s in &owned {
        ptrs.push(s.as_ptr());
    }
    ptrs.extend_from_slice(tail);
    ptrs.push(std::ptr::null());

    ShebangRewrite {
        interp,
        _owned: owned,
        ptrs,
    }
}
