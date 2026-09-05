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
