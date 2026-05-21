import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));

/**
 * Resolve the ai-kit root directory using the same precedence as bin/lib/ai-kit-root.sh:
 *   1. $AI_KIT_ROOT env var
 *   2. ~/.config/ai-kit/root (contents = absolute path)
 *   3. Script location — walk up from dist/ until a VERSION file is found
 *
 * Throws if none resolve to a directory containing a VERSION file.
 */
export function resolveAiKitRoot(): string {
  const fromEnv = process.env.AI_KIT_ROOT;
  if (fromEnv && isAiKitRoot(fromEnv)) {
    return fromEnv;
  }

  const configFile = resolve(homedir(), ".config", "ai-kit", "root");
  if (existsSync(configFile)) {
    const fromConfig = readFileSync(configFile, "utf8").trim();
    if (fromConfig && isAiKitRoot(fromConfig)) {
      return fromConfig;
    }
  }

  // Script-location fallback: when shipped from this repo's mcp/dist/server.js,
  // the ai-kit root is two levels up (mcp/.. == repo root).
  let dir = __dirname;
  for (let i = 0; i < 5; i++) {
    if (isAiKitRoot(dir)) return dir;
    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }

  throw new Error(
    "Could not resolve ai-kit root. Set AI_KIT_ROOT, run install-global.sh, or point AI_KIT_ROOT at a clone."
  );
}

function isAiKitRoot(dir: string): boolean {
  return existsSync(resolve(dir, "VERSION")) && existsSync(resolve(dir, "workflow", "skills"));
}
