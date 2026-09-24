// Standalone CLI for the ohos_sign crate, which has no workspace
// dependencies — bun_core::output / bun_sys are unavailable here, so
// std I/O macros and std::fs are the only option.
#![allow(clippy::disallowed_methods, clippy::disallowed_macros)]

use std::path::Path;
use std::process::ExitCode;

fn usage(prog: &str) -> ! {
    eprintln!(
        "Usage:\n  {prog} sign   <input> [--output <out>] [--force]\n  {prog} check  <input>\n  {prog} verify <input>\n  {prog} strip  <input> [--output <out>]"
    );
    std::process::exit(1);
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().collect();
    let prog = args.first().map(|s| s.as_str()).unwrap_or("ohos-selfsign");
    if args.len() < 3 {
        usage(prog);
    }
    match args[1].as_str() {
        "sign" => cmd_sign(&args[2..], prog),
        "check" => cmd_check(&args[2..]),
        "verify" => cmd_verify(&args[2..]),
        "strip" => cmd_strip(&args[2..], prog),
        _ => usage(prog),
    }
}

fn cmd_sign(args: &[String], prog: &str) -> ExitCode {
    let mut input: Option<&Path> = None;
    let mut output: Option<&Path> = None;
    let mut force = false;
    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--output" | "-o" => {
                i += 1;
                output = args.get(i).map(Path::new);
            }
            "--force" | "-f" => force = true,
            s if s.starts_with('-') => usage(prog),
            s if input.is_none() => input = Some(Path::new(s)),
            _ => usage(prog),
        }
        i += 1;
    }
    let Some(input) = input else { usage(prog) };
    let out = output.unwrap_or(input);
    let bytes = match std::fs::read(input) {
        Ok(b) => b,
        Err(e) => {
            eprintln!("ohos-selfsign: read {}: {e}", input.display());
            return ExitCode::FAILURE;
        }
    };
    let signed = if force {
        ohos_sign::sign_selfsign_with_strip(&bytes)
    } else {
        ohos_sign::sign_selfsign(&bytes)
    };
    match signed {
        Ok(data) => {
            if let Err(e) = std::fs::write(out, &data) {
                eprintln!("ohos-selfsign: write {}: {e}", out.display());
                return ExitCode::FAILURE;
            }
            ExitCode::SUCCESS
        }
        Err(e) => {
            eprintln!("ohos-selfsign: sign {}: {e}", input.display());
            ExitCode::FAILURE
        }
    }
}

fn cmd_check(args: &[String]) -> ExitCode {
    let Some(input) = args.first() else {
        eprintln!("ohos-selfsign: check requires <input>");
        return ExitCode::FAILURE;
    };
    let bytes = match std::fs::read(input) {
        Ok(b) => b,
        Err(e) => {
            eprintln!("ohos-selfsign: read {input}: {e}");
            return ExitCode::FAILURE;
        }
    };
    if ohos_sign::has_codesign(&bytes) {
        ExitCode::SUCCESS
    } else {
        ExitCode::FAILURE
    }
}

// Unlike `check` (presence only), `verify` recomputes the two comparisons
// the OHOS kernel performs at exec — release gates must use this one.
fn cmd_verify(args: &[String]) -> ExitCode {
    let Some(input) = args.first() else {
        eprintln!("ohos-selfsign: verify requires <input>");
        return ExitCode::FAILURE;
    };
    let bytes = match std::fs::read(input) {
        Ok(b) => b,
        Err(e) => {
            eprintln!("ohos-selfsign: read {input}: {e}");
            return ExitCode::FAILURE;
        }
    };
    if ohos_sign::has_valid_codesign(&bytes) {
        ExitCode::SUCCESS
    } else {
        eprintln!("ohos-selfsign: {input} has no valid .codesign (missing, stale, or corrupt)");
        ExitCode::FAILURE
    }
}

fn cmd_strip(args: &[String], prog: &str) -> ExitCode {
    let mut input: Option<&str> = None;
    let mut output: Option<&str> = None;
    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--output" | "-o" => {
                i += 1;
                output = args.get(i).map(|s| s.as_str());
            }
            s if s.starts_with('-') => usage(prog),
            s if input.is_none() => input = Some(s),
            _ => usage(prog),
        }
        i += 1;
    }
    let Some(input) = input else { usage(prog) };
    let output = output.unwrap_or(input);
    let mut bytes = match std::fs::read(input) {
        Ok(b) => b,
        Err(e) => {
            eprintln!("ohos-selfsign: read {input}: {e}");
            return ExitCode::FAILURE;
        }
    };
    match ohos_sign::strip_codesign(&mut bytes) {
        Ok(_) => {
            if let Err(e) = std::fs::write(output, &bytes) {
                eprintln!("ohos-selfsign: write {output}: {e}");
                return ExitCode::FAILURE;
            }
            ExitCode::SUCCESS
        }
        Err(e) => {
            eprintln!("ohos-selfsign: strip {input}: {e}");
            ExitCode::FAILURE
        }
    }
}
