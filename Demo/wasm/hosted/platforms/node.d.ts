import type { InstantiateOptions } from "../instantiate.js"
import type { Worker } from "node:worker_threads"

export type DefaultNodeSetupOptions = {
    args?: string[],
    onExit?: (code: number) => void,
}

export function defaultNodeSetup(options?: DefaultNodeSetupOptions): Promise<InstantiateOptions>

export function createDefaultWorkerFactory(preludeScript?: string): (module: WebAssembly.Module, memory: WebAssembly.Memory, startArg: any) => Worker
