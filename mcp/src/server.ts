#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { tools } from "./tools.js";
import { resolveAiKitRoot } from "./resolve-root.js";

const aiKitRoot = resolveAiKitRoot();

const server = new Server(
  {
    name: "ai-kit",
    version: "1.2.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: tools.map((t) => ({
    name: t.name,
    description: t.description,
    inputSchema: t.inputSchema,
  })),
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const tool = tools.find((t) => t.name === request.params.name);
  if (!tool) {
    return {
      content: [{ type: "text", text: `Unknown tool: ${request.params.name}` }],
      isError: true,
    };
  }

  const parsed = tool.zodSchema.safeParse(request.params.arguments ?? {});
  if (!parsed.success) {
    return {
      content: [
        {
          type: "text",
          text: `Invalid arguments for ${tool.name}: ${parsed.error.message}`,
        },
      ],
      isError: true,
    };
  }

  try {
    const result = await (tool.handler as (input: unknown) => Promise<string>)(parsed.data);
    return {
      content: [{ type: "text", text: result }],
    };
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return {
      content: [{ type: "text", text: `Error: ${msg}` }],
      isError: true,
    };
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);

// Log to stderr so it doesn't pollute stdout (JSON-RPC channel).
process.stderr.write(`ai-kit-mcp server started — root=${aiKitRoot}\n`);
