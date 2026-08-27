/* OHOS-only version script. Restricts .dynsym to Bun__dlopen only:
   `local: *;` hides the full v8/napi/uv set so device-side symbol
   resolution never sees the v8::Array::New mangling (__1 vs __n1)
   mismatch with libc++_shared.so. Also trims ~1.8MB/process (20K -> 459
   .dynsym entries), avoiding OOM on the 31GB no-swap device.
   See flags.ts "OHOS: restrict .dynsym to Bun__dlopen only".

   This MUST stay separate from src/symbols.dyn, which is consumed as
   --dynamic-list on linux/freebsd and does not support the `local:`
   scope (only --version-script does). */
{
    global:
        Bun__dlopen;
    local:
        *;
};
