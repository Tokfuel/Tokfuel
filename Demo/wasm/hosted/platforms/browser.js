// @ts-check
import { MODULE_PATH } from "../instantiate.js"
// @ts-ignore
import { WASI, File, OpenFile, ConsoleStdout, PreopenDirectory } from '@bjorn3/browser_wasi_shim';


/** @type {import('./browser.d.ts').defaultBrowserSetup} */
export async function defaultBrowserSetup(options) {
    const args = options.args ?? []
    const onStdoutLine = options.onStdoutLine ?? ((line) => console.log(line))
    const onStderrLine = options.onStderrLine ?? ((line) => console.error(line))
    const wasi = new WASI(/* args */[MODULE_PATH, ...args], /* env */[], /* fd */[
        new OpenFile(new File([])), // stdin
        ConsoleStdout.lineBuffered((stdout) => {
            onStdoutLine(stdout);
        }),
        ConsoleStdout.lineBuffered((stderr) => {
            onStderrLine(stderr);
        }),
        new PreopenDirectory("/", new Map()),
    ], { debug: false })

    return {
        module: options.module,
        wasi: Object.assign(wasi, {
            setInstance(instance) {
                wasi.inst = instance;
            }
        }),
    }
}
