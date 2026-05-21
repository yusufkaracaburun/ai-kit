import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { resolve } from "node:path";
import { z } from "zod";
import { resolveAiKitRoot } from "./resolve-root.js";

const execFileAsync = promisify(execFile);

const aiKitRoot = resolveAiKitRoot();
const SCRIPT_TIMEOUT_MS = 10_000;

async function runScript(scriptRelativePath: string, args: string[]): Promise<string> {
  const scriptPath = resolve(aiKitRoot, scriptRelativePath);
  if (!existsSync(scriptPath)) {
    throw new Error(`ai-kit script missing: ${scriptRelativePath}`);
  }
  const { stdout } = await execFileAsync("bash", [scriptPath, ...args], {
    timeout: SCRIPT_TIMEOUT_MS,
    maxBuffer: 1024 * 1024,
    env: { ...process.env, AI_KIT_ROOT: aiKitRoot },
  });
  return stdout;
}

export const tools = [
  {
    name: "ai_kit_which",
    description:
      "Pick the right ai-kit skill for a stated intent. Returns top-3 matches ranked by deterministic keyword overlap (no LLM). Use when the caller has a goal but doesn't know which skill fits.",
    inputSchema: {
      type: "object" as const,
      properties: {
        intent: {
          type: "string",
          minLength: 3,
          description: "What the user is trying to do, in natural language.",
        },
      },
      required: ["intent"],
    },
    zodSchema: z.object({ intent: z.string().min(3).max(500) }),
    handler: async (input: { intent: string }) => {
      const out = await runScript("bin/ai-kit-which.sh", [input.intent]);
      return out.trim();
    },
  },
  {
    name: "ai_kit_skill",
    description:
      "Return the full SKILL.md body for a named ai-kit skill. Use after ai_kit_which to load the chosen skill's instructions.",
    inputSchema: {
      type: "object" as const,
      properties: {
        name: {
          type: "string",
          pattern: "^[a-z0-9][a-z0-9-]*$",
          description: "Skill name (e.g. 'ship', 'tdd', 'to-prd').",
        },
      },
      required: ["name"],
    },
    zodSchema: z.object({
      name: z.string().regex(/^[a-z0-9][a-z0-9-]*$/, "Invalid skill name"),
    }),
    handler: async (input: { name: string }) => {
      const out = await runScript("bin/ai-kit-which.sh", ["--explain", input.name]);
      return out.trim();
    },
  },
  {
    name: "ai_kit_rule",
    description:
      "Return the markdown for a named ai-kit canonical rule (e.g. 'git-hygiene', 'context-discipline', 'aposd').",
    inputSchema: {
      type: "object" as const,
      properties: {
        name: {
          type: "string",
          pattern: "^[a-z0-9][a-z0-9-]*$",
          description: "Rule name (matches files under standards/rules/).",
        },
      },
      required: ["name"],
    },
    zodSchema: z.object({
      name: z.string().regex(/^[a-z0-9][a-z0-9-]*$/, "Invalid rule name"),
    }),
    handler: async (input: { name: string }) => {
      const candidates = [
        resolve(aiKitRoot, "standards", "rules", `${input.name}.mini.md`),
        resolve(aiKitRoot, "standards", "rules", `${input.name}.nano.md`),
      ];
      for (const path of candidates) {
        if (existsSync(path)) {
          return readFileSync(path, "utf8");
        }
      }
      throw new Error(`Rule not found: ${input.name}. Try ai_kit_list with kind="rules".`);
    },
  },
  {
    name: "ai_kit_doctor",
    description:
      "Run the ai-kit doctor (install health check, project-scoped). Returns blockers + warnings + summary.",
    inputSchema: {
      type: "object" as const,
      properties: {},
    },
    zodSchema: z.object({}),
    handler: async () => {
      try {
        const out = await runScript("bin/ai-kit-doctor.sh", ["--project-only"]);
        return out.trim();
      } catch (e: unknown) {
        // doctor returns exit 1 (warnings) or 2 (errors); both surface stdout via stderr.
        const err = e as { stdout?: string; stderr?: string; code?: number };
        const body = err.stdout?.trim() || err.stderr?.trim() || String(e);
        return `${body}\n\n(doctor exit code ${err.code ?? "?"})`;
      }
    },
  },
  {
    name: "ai_kit_list",
    description:
      "Enumerate ai-kit assets. kind='skills' returns names + one-line descriptions; kind='rules' returns names of all canonical rules.",
    inputSchema: {
      type: "object" as const,
      properties: {
        kind: {
          type: "string",
          enum: ["skills", "rules"],
          description: "Which asset kind to enumerate.",
        },
      },
      required: ["kind"],
    },
    zodSchema: z.object({ kind: z.enum(["skills", "rules"]) }),
    handler: async (input: { kind: "skills" | "rules" }) => {
      if (input.kind === "skills") {
        const out = await runScript("bin/ai-kit-which.sh", ["--list"]);
        return out.trim();
      }
      const dir = resolve(aiKitRoot, "standards", "rules");
      if (!existsSync(dir)) return "(no rules directory)";
      const rules = readdirSync(dir)
        .filter((f) => f.endsWith(".mini.md") || f.endsWith(".nano.md"))
        .map((f) => f.replace(/\.(mini|nano)\.md$/, ""))
        .sort();
      return rules.map((name) => `- ${name}`).join("\n");
    },
  },
] as const;

export type AiKitTool = (typeof tools)[number];
