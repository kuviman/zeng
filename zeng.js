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

/**
 * @typedef { {
 *  index: number,
 *  info: WebGLActiveInfo,
 * } } Attribute
 * @typedef { {
 *  gl: WebGLProgram,
 *  uniforms: Map<string, WebGLActiveInfo>,
 *  attributes: Map<string, Attribute>,
 * } } Program 
 */

/** @type { Map<number, Program> } */
const programs = new Map();
let nextProgram = 0;

/** @type { Map<number, WebGLBuffer> } */
const buffers = new Map();
let nextBuffer = 0;

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
            canvas.width = canvas.clientWidth;
            canvas.height = canvas.clientHeight;
            webgl.viewport(0, 0, canvas.width, canvas.height);
            call_ptr(drawFn, ptr);
            requestAnimationFrame(frame);
        }
        requestAnimationFrame(frame);
        throw new Error("This is not an error");
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
        /** @type { Map<string, Attribute>} */
        const attributes = new Map();
        const attributeCount = webgl.getProgramParameter(program, webgl.ACTIVE_ATTRIBUTES);
        for (let i = 0; i < attributeCount; i++) {
            const attribute = webgl.getActiveAttrib(program, i);
            if (attribute == null) {
                continue;
            }
            attributes.set(attribute.name, { index: i, info: attribute });
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
        programs.set(handle, { gl: program, attributes, uniforms, });
        return handle;
    },
    zeng_use_program: function (handle) {
        const program = programs.get(handle);
        if (!program) {
            return;
        }
        webgl.useProgram(program.gl);
    },
    zeng_deinit_program: function (handle) {
        const program = programs.get(handle);
        if (!program) {
            return;
        }
        programs.delete(handle);
        webgl.deleteProgram(program.gl);
    },
    zeng_init_vertex_buffer: function (data_ptr, data_len) {
        const buffer = webgl.createBuffer();
        if (!buffer) {
            throw new Error("no buffer");
        }
        webgl.bindBuffer(webgl.ARRAY_BUFFER, buffer);
        const data = get_c_data(data_ptr, data_len);
        webgl.bufferData(webgl.ARRAY_BUFFER, data, webgl.STATIC_DRAW);
        const handle = nextBuffer++;
        buffers.set(handle, buffer);
        return handle;
    },
    zeng_bind_vertex_buffer: function (handle) {
        const buffer = buffers.get(handle) ?? null;
        webgl.bindBuffer(webgl.ARRAY_BUFFER, buffer);
    },
    zeng_deinit_vertex_buffer: function (handle) {
        const buffer = buffers.get(handle) ?? null;
        buffers.delete(handle);
        webgl.deleteBuffer(buffer);
    },
    zeng_vertex_attrib_pointer: function (
        program_handle,
        name_ptr,
        name_len,
        size,
        type,
        normalized,
        stride,
        offset,
    ) {
        const program = programs.get(program_handle);
        if (!program) {
            return;
        }
        const name = get_c_str(name_ptr, name_len);
        const attribute = program.attributes.get(name);
        if (!attribute) {
            return;
        }
        let gl_type;
        switch (type) {
            case 0:
                gl_type = webgl.FLOAT;
                break;
            default:
                throw new Error("Unknown type");
        }
        webgl.enableVertexAttribArray(attribute.index);
        webgl.vertexAttribPointer(
            attribute.index,
            size, // attribute.info.size,
            gl_type, // attribute.info.type,
            normalized,
            stride,
            offset,
        );
    },
    zeng_draw_arrays: function (mode, first, count) {
        let gl_mode;
        switch (mode) {
            case 0:
                gl_mode = webgl.TRIANGLES;
                break;
            default:
                throw new Error("Wot mode?");
        };
        webgl.drawArrays(gl_mode, first, count);
    },
};

/**
 * @param { number } ptr
 * @param { number } len
 * @returns { Uint8Array }
 */
function get_c_data(ptr, len) {
    return new Uint8Array(
        wasmMemory.buffer, // memory exported from Zig
        ptr,
        len,
    );
}

/**
 * @param { number } c_str
 * @param { number } len
 * @returns { string }
 */
function get_c_str(c_str, len) {
    return new TextDecoder().decode(get_c_data(c_str, len));
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