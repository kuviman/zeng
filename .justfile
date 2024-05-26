web:
    zig build dist -Dtarget=wasm32-freestanding
    caddy file-server --listen 127.0.0.1:8123 --root zig-out/dist