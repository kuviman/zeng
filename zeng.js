/** @type { WebAssembly.Instance } */
// @ts-ignore
var wasm = undefined;
/** @type { WebAssembly.Memory }*/
// @ts-ignore
var wasmMemory = undefined;
/** @type { HTMLCanvasElement } */
// @ts-ignore
let canvas = undefined;
/** @type { WebGLRenderingContext } */
// @ts-ignore
let webgl = undefined;

function call_ptr(fnPtr, ptr) {
    // @ts-ignore
    wasm.exports.call_ptr(fnPtr, ptr);
}

/** @type { Map<number, WebGLShader> } */
const shaders = new Map();
let nextShader = 0;

/** @type { Map<number, WebGLProgram> } */
const programs = new Map();
let nextProgram = 0;

const env = {
    gl_clear: function (r, g, b, a) {
        webgl.clearColor(r, g, b, a);
        webgl.clear(webgl.COLOR_BUFFER_BIT);
    },
    zeng_init: function () {
        const body = document.getElementsByTagName("body").item(0);
        canvas = document.createElement("canvas");
        // @ts-ignore
        webgl = canvas.getContext("webgl");
        // @ts-ignore
        body.append(canvas);
    },
    zeng_run: function (ptr, drawFn) {
        function frame() {
            call_ptr(drawFn, ptr);
            requestAnimationFrame(frame);
        }
        requestAnimationFrame(frame);
    },
    zeng_time: function () {
        return performance.now() / 1000.0;
    },
    zeng_log: function (ptr, len) {
        const text = get_c_str(ptr, len);
        console.log(text);
    },
    zeng_init_shader: function (type, source_ptr, source_len) {
        let gl_type;
        switch (type) {
            case 0:
                console.log("Vertex");
                gl_type = webgl.VERTEX_SHADER;
                break;
            case 1:
                console.log("Fragment");
                gl_type = webgl.FRAGMENT_SHADER;
                break;
            default:
                throw new Error("unknown shader type");
        }
        const shader = webgl.createShader(gl_type);
        if (shader == null) {
            throw new Error("failed to make shader");
        }

        let source = get_c_str(source_ptr, source_len);
        source = `precision mediump float;\n${source}`;

        webgl.shaderSource(shader, source);
        webgl.compileShader(shader);
        const status = webgl.getShaderParameter(shader, webgl.COMPILE_STATUS);
        if (!status) {
            const log = webgl.getShaderInfoLog(shader);
            throw new Error(`Failed to compile shader: ${log}`);
        }
        const handle = nextShader++;
        shaders.set(handle, shader);
        return handle;
    },
    zeng_deinit_shader: function (handle) {
        const shader = shaders.get(handle) ?? null;
        shaders.delete(handle);
        webgl.deleteShader(shader);
    },
    zeng_init_program: function (shader1_handle, shader2_handle) {
        const program = webgl.createProgram();
        if (!program) {
            throw Error("program null");
        }
        const shader1 = shaders.get(shader1_handle);
        if (!shader1) {
            throw new Error("shader1 is not");
        }
        const shader2 = shaders.get(shader2_handle);
        if (!shader2) {
            throw new Error("shader2 is not");
        }
        webgl.attachShader(program, shader1);
        webgl.attachShader(program, shader2);
        webgl.linkProgram(program);
        const status = webgl.getProgramParameter(program, webgl.LINK_STATUS);
        if (!status) {
            const log = webgl.getProgramInfoLog(program);
            throw new Error(`Failed to link program: ${log}`);
        }
        /** @type { Map<string, WebGLActiveInfo>} */
        const attributes = new Map();
        const attributeCount = webgl.getProgramParameter(program, webgl.ACTIVE_ATTRIBUTES);
        for (let i = 0; i < attributeCount; i++) {
            const attribute = webgl.getActiveAttrib(program, i);
            if (attribute == null) {
                continue;
            }
            attributes.set(attribute.name, attribute);
        }

        /** @type { Map<string, WebGLActiveInfo>} */
        const uniforms = new Map();
        const uniformCount = webgl.getProgramParameter(program, webgl.ACTIVE_UNIFORMS);
        for (let i = 0; i < uniformCount; i++) {
            const uniform = webgl.getActiveUniform(program, i);
            if (uniform == null) {
                continue;
            }
            uniforms.set(uniform.name, uniform);
        }

        const handle = nextProgram++;
        programs.set(handle, program);
        return handle;
    },
    zeng_deinit_program: function (handle) {
        const program = programs.get(handle) ?? null;
        programs.delete(handle);
        webgl.deleteProgram(program);
    },
};

/**
 * @param { number } c_str
 * @param { number } len
 * @returns { string }
 */
function get_c_str(c_str, len) {
    const slice = new Uint8Array(
        wasmMemory.buffer, // memory exported from Zig
        c_str,
        len,
    );
    return new TextDecoder().decode(slice);
}

export async function init(wasmPath) {
    let wasmPromise = fetch(wasmPath);
    WebAssembly.instantiateStreaming(wasmPromise, {
        env: env,
    }).then(result => {
        wasm = result.instance;
        // @ts-ignore
        wasmMemory = wasm.exports.memory;
        // @ts-ignore 
        wasm.exports._start();
    });
}