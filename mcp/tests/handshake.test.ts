import { test } from "node:test";
import { strict as assert } from "node:assert";
import { spawn } from "node:child_process";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const SERVER = resolve(__dirname, "..", "src", "server.ts");
const AIKIT_ROOT = resolve(__dirname, "..", "..");

interface JsonRpcResponse {
  jsonrpc: "2.0";
  id: number | string;
  result?: unknown;
  error?: { code: number; message: string };
}

async function rpcRoundTrip(messages: Array<Record<string, unknown>>): Promise<JsonRpcResponse[]> {
  return new Promise((resolveFn, reject) => {
    const child = spawn("npx", ["tsx", SERVER], {
      cwd: resolve(__dirname, ".."),
      env: { ...process.env, AI_KIT_ROOT: AIKIT_ROOT },
      stdio: ["pipe", "pipe", "pipe"],
    });

    let stdout = "";
    const responses: JsonRpcResponse[] = [];
    const expected = messages.length;

    const timer = setTimeout(() => {
      child.kill();
      reject(new Error(`Timeout waiting for ${expected} responses. Got ${responses.length}. stdout=${stdout.slice(-500)}`));
    }, 15_000);

    child.stdout.on("data", (chunk: Buffer) => {
      stdout += chunk.toString();
      const lines = stdout.split("\n");
      stdout = lines.pop() ?? "";
      for (const line of lines) {
        if (!line.trim()) continue;
        try {
          responses.push(JSON.parse(line) as JsonRpcResponse);
        } catch {
          // ignore non-JSON lines (shouldn't happen on stdout but just in case)
        }
        if (responses.length >= expected) {
          clearTimeout(timer);
          child.kill();
          resolveFn(responses);
          return;
        }
      }
    });

    child.on("error", (err) => {
      clearTimeout(timer);
      reject(err);
    });

    for (const msg of messages) {
      child.stdin.write(JSON.stringify(msg) + "\n");
    }
  });
}

test("server responds to initialize + tools/list with 5 tools", async () => {
  const responses = await rpcRoundTrip([
    {
      jsonrpc: "2.0",
      id: 1,
      method: "initialize",
      params: {
        protocolVersion: "2024-11-05",
        capabilities: {},
        clientInfo: { name: "test-client", version: "0.0.0" },
      },
    },
    {
      jsonrpc: "2.0",
      id: 2,
      method: "tools/list",
      params: {},
    },
  ]);

  assert.equal(responses.length, 2);
  const initResp = responses.find((r) => r.id === 1);
  const listResp = responses.find((r) => r.id === 2);
  assert.ok(initResp, "initialize response present");
  assert.ok(listResp, "tools/list response present");

  const tools = (listResp!.result as { tools: Array<{ name: string }> }).tools;
  assert.equal(tools.length, 5, `expected 5 tools, got ${tools.length}`);
  const names = tools.map((t) => t.name).sort();
  assert.deepEqual(names, [
    "ai_kit_doctor",
    "ai_kit_list",
    "ai_kit_rule",
    "ai_kit_skill",
    "ai_kit_which",
  ]);
});

test("ai_kit_list with kind=skills returns >0 skills", async () => {
  const responses = await rpcRoundTrip([
    {
      jsonrpc: "2.0",
      id: 1,
      method: "initialize",
      params: {
        protocolVersion: "2024-11-05",
        capabilities: {},
        clientInfo: { name: "test-client", version: "0.0.0" },
      },
    },
    {
      jsonrpc: "2.0",
      id: 2,
      method: "tools/call",
      params: {
        name: "ai_kit_list",
        arguments: { kind: "skills" },
      },
    },
  ]);

  const callResp = responses.find((r) => r.id === 2);
  assert.ok(callResp, "tools/call response present");
  const content = (callResp!.result as { content: Array<{ type: string; text: string }> }).content;
  assert.equal(content[0].type, "text");
  assert.ok(content[0].text.length > 0, "expected non-empty skill listing");
});

test("ai_kit_rule rejects invalid name pattern", async () => {
  const responses = await rpcRoundTrip([
    {
      jsonrpc: "2.0",
      id: 1,
      method: "initialize",
      params: {
        protocolVersion: "2024-11-05",
        capabilities: {},
        clientInfo: { name: "test-client", version: "0.0.0" },
      },
    },
    {
      jsonrpc: "2.0",
      id: 2,
      method: "tools/call",
      params: {
        name: "ai_kit_rule",
        arguments: { name: "../etc/passwd" },
      },
    },
  ]);

  const callResp = responses.find((r) => r.id === 2);
  const result = callResp!.result as { isError?: boolean; content: Array<{ text: string }> };
  assert.equal(result.isError, true, "expected zod validation to reject path traversal");
  assert.match(result.content[0].text, /Invalid arguments|Invalid rule name/);
});
