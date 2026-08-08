// @ts-check
import { fileURLToPath } from "node:url";
import { Worker, parentPort } from "node:worker_threads";
import { MODULE_PATH } from "../instantiate.js"
import { WASI, File, OpenFile, ConsoleStdout, PreopenDirectory, Directory, Inode } from '@bjorn3/browser_wasi_shim';


/** @type {import('./node.d.ts').defaultNodeSetup} */
export async function defaultNodeSetup(options = {}) {
    const path = await import("node:path");
    const { fileURLToPath } = await import("node:url");
    const { readFile } = await import("node:fs/promises")

    const args = options.args ?? process.argv.slice(2)
    const rootFs = new Map();
    const wasi = new WASI(/* args */[MODULE_PATH, ...args], /* env */[], /* fd */[
        new OpenFile(new File([])), // stdin
        ConsoleStdout.lineBuffered((stdout) => {
            console.log(stdout);
        }),
        ConsoleStdout.lineBuffered((stderr) => {
            console.error(stderr);
        }),
        new PreopenDirectory("/", rootFs),
    ], { debug: false })
    const pkgDir = path.dirname(path.dirname(fileURLToPath(import.meta.url)))
    const module = await WebAssembly.compile(new Uint8Array(await readFile(path.join(pkgDir, MODULE_PATH))))

    return {
        module,
        wasi: Object.assign(wasi, {
            setInstance(instance) {
                wasi.inst = instance;
            },
            /**
             * @param {string} path
             * @returns {Uint8Array | undefined}
             */
            extractFile(path) {
                /**
                 * @param {Map<string, Inode>} parent
                 * @param {string[]} components
                 * @param {number} index
                 * @returns {Inode | undefined}
                 */
                const getFile = (parent, components, index) => {
                    const name = components[index];
                    const entry = parent.get(name);
                    if (entry === undefined) {
                        return undefined;
                    }
                    if (index === components.length - 1) {
                        return entry;
                    }
                    if (entry instanceof Directory) {
                        return getFile(entry.contents, components, index + 1);
                    }
                    throw new Error(`Expected directory at ${components.slice(0, index).join("/")}`);
                }

                const components = path.split("/");
                const file = getFile(rootFs, components, 0);
                if (file === undefined) {
                    return undefined;
                }
                if (file instanceof File) {
                    return file.data;
                }
                return undefined;
            }
        }),
        addToCoreImports(importObject) {
            importObject["wasi_snapshot_preview1"]["proc_exit"] = (code) => {
                if (options.onExit) {
                    options.onExit(code);
                }
                process.exit(code);
            }
        },
    }
}
