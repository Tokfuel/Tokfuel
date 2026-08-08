// @ts-check
import { instantiate } from './instantiate.js';
import { defaultBrowserSetup } from './platforms/browser.js';


/** @type {import('./index.d').init} */
async function initBrowser(_options) {
    /** @type {import('./index.d').Options} */
    const options = _options || {
    };
    let module = options.module;
    if (!module) {
        module = fetch(new URL("TokfuelDemo.wasm", import.meta.url))
    }
    const instantiateOptions = await defaultBrowserSetup({
        module,
    })
    return await instantiate(instantiateOptions);
}


/** @type {import('./index.d').init} */
export async function init(options) {
        return initBrowser(options);
    }