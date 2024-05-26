/** @type { HTMLCanvasElement } */
let canvas;
/** @type { WebGLRenderingContext } */
let webgl;

export function gl_clear(r, g, b, a) {
    webgl.clearColor(r, g, b, a);
    webgl.clear(webgl.COLOR_BUFFER_BIT);
}

export function zeng_init() {
    const body = document.getElementsByTagName("body").item(0);
    canvas = document.createElement("canvas");
    webgl = canvas.getContext("webgl");
    body.append(canvas);
}

export function zeng_say_hello() {
    console.log("hello");
}