import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import * as harness from "harness";
import { tls as tlsCerts } from "harness";
import type { HttpsProxyAgent as HttpsProxyAgentType } from "https-proxy-agent";
import {
  type ClientEvent,
  clientEvents,
  connectRequest,
  createConnectProxy,
  echoSession,
  echoed,
  failed,
  failingSession,
  startEchoServer,
  startProxy,
  startRecordingProxy,
} from "./proxy-test-utils";
// Use dynamic require to avoid linter removing the import
const { HttpsProxyAgent } = require("https-proxy-agent") as {
  HttpsProxyAgent: typeof HttpsProxyAgentType;
};

// Use docker-compose infrastructure for squid proxy

const gc = harness.gc;
const bunExe = harness.bunExe;
const bunEnv = harness.bunEnv;
const isDockerEnabled = harness.isDockerEnabled;

// The in-process WebSocket tests below pass an explicit `proxy:` option targeting
// 127.0.0.1 and expect the proxy to be hit. NO_PROXY applies to explicit proxies
// too, so an ambient NO_PROXY=localhost,127.0.0.1,... would bypass the proxy and
// break those assertions. The NO_PROXY test block further down spawns subprocesses
// with an explicit env, so clearing the runner's value here doesn't affect it.
const prevNoProxy = process.env.NO_PROXY;
const prevNoProxyLower = process.env.no_proxy;
process.env.NO_PROXY = "";
process.env.no_proxy = "";

// Echo servers. Every proxy is started by the test that uses it, so each test
// can read what reached its proxy.
let wsServer: ReturnType<typeof Bun.serve>;
let wssServer: ReturnType<typeof Bun.serve>;
let wsPort: number;
let wssPort: number;

beforeAll(() => {
  wsServer = startEchoServer();
  wsPort = wsServer.port;
  wssServer = startEchoServer({ tls: true });
  wssPort = wssServer.port;
});

afterAll(() => {
  wsServer?.stop(true);
  wssServer?.stop(true);
  if (prevNoProxy !== undefined) process.env.NO_PROXY = prevNoProxy;
  if (prevNoProxyLower !== undefined) process.env.no_proxy = prevNoProxyLower;
});

function closeCodeOf(events: ClientEvent[]): number | undefined {
  const last = events[events.length - 1];
  return typeof last === "object" && "code" in last ? last.code : undefined;
}

describe("WebSocket proxy API", () => {
  // These checks only exercise the constructor. close() follows at once, so
  // nothing needs to listen on the proxy port.
  const proxyPort = 1;
  const authProxyPort = 1;

  test("accepts proxy option as string (HTTP proxy)", () => {
    const ws = new WebSocket("ws://example.com", {
      proxy: `http://127.0.0.1:${proxyPort}`,
    });
    expect(ws.readyState).toBe(WebSocket.CONNECTING);
    ws.close();
  });

  test("accepts proxy option as string (HTTPS proxy)", () => {
    // Note: This test just checks the constructor accepts the option.
    // The actual connection would fail without proper TLS setup for the proxy.
    const ws = new WebSocket("ws://example.com", {
      proxy: `https://127.0.0.1:${proxyPort}`,
      tls: { rejectUnauthorized: false },
    });
    expect(ws.readyState).toBe(WebSocket.CONNECTING);
    ws.close();
  });

  test("accepts HTTPS proxy with wss:// target", () => {
    // Note: This test just checks the constructor accepts the option.
    const ws = new WebSocket("wss://example.com", {
      proxy: `https://127.0.0.1:${proxyPort}`,
      tls: { rejectUnauthorized: false },
    });
    expect(ws.readyState).toBe(WebSocket.CONNECTING);
    ws.close();
  });

  test("accepts proxy option as object with url", () => {
    const ws = new WebSocket("ws://example.com", {
      proxy: { url: `http://127.0.0.1:${proxyPort}` },
    });
    expect(ws.readyState).toBe(WebSocket.CONNECTING);
    ws.close();
  });

  test("accepts proxy option with headers", () => {
    const ws = new WebSocket("ws://example.com", {
      proxy: {
        url: `http://127.0.0.1:${proxyPort}`,
        headers: { "X-Custom-Header": "test-value" },
      },
    });
    expect(ws.readyState).toBe(WebSocket.CONNECTING);
    ws.close();
  });

  test("accepts proxy option with Headers class instance", () => {
    const headers = new Headers({ "X-Custom-Header": "test-value" });
    const ws = new WebSocket("ws://example.com", {
      proxy: {
        url: `http://127.0.0.1:${proxyPort}`,
        headers: headers,
      },
    });
    expect(ws.readyState).toBe(WebSocket.CONNECTING);
    ws.close();
  });

  test("accepts proxy URL with credentials", () => {
    const ws = new WebSocket("ws://example.com", {
      proxy: `http://user:pass@127.0.0.1:${authProxyPort}`,
    });
    expect(ws.readyState).toBe(WebSocket.CONNECTING);
    ws.close();
  });

  test("can combine proxy with other options", () => {
    const ws = new WebSocket("ws://example.com", {
      proxy: `http://127.0.0.1:${proxyPort}`,
      headers: { Authorization: "Bearer token" },
      protocols: ["graphql-ws"],
    });
    expect(ws.readyState).toBe(WebSocket.CONNECTING);
    ws.close();
  });

  test("rejects invalid proxy URL", () => {
    expect(() => {
      new WebSocket("ws://example.com", {
        proxy: "not-a-valid-url",
      });
    }).toThrow(expect.objectContaining({ name: "SyntaxError", message: "Invalid proxy URL: not-a-valid-url" }));
  });

  test.each(["socks5", "socks4", "socks5h", "ftp", "ws", "gopher"])(
    "rejects unsupported proxy protocol %s://",
    scheme => {
      // Matching fetch()'s UnsupportedProxyProtocol rejection: only http:// and
      // https:// proxies are supported, and any other scheme must fail up front
      // instead of silently sending an HTTP CONNECT request.
      expect(() => {
        new WebSocket("ws://example.com", {
          proxy: `${scheme}://127.0.0.1:1`,
        });
      }).toThrow(
        expect.objectContaining({
          name: "SyntaxError",
          message: expect.stringContaining("Unsupported proxy protocol"),
        }),
      );
      // Same rejection via the { url } form.
      expect(() => {
        new WebSocket("ws://example.com", {
          proxy: { url: `${scheme}://127.0.0.1:1` },
        });
      }).toThrow(/Unsupported proxy protocol/);
    },
  );
});

describe("WebSocket through HTTP CONNECT proxy", () => {
  test("ws:// through HTTP proxy", async () => {
    using recorded = await startRecordingProxy();
    const ws = new WebSocket(`ws://127.0.0.1:${wsPort}`, {
      proxy: `http://127.0.0.1:${recorded.port}`,
    });
    expect({ events: await echoSession(ws, "hello from client"), requests: recorded.requests }).toEqual({
      events: echoed("hello from client"),
      requests: [connectRequest(wsPort)],
    });
    gc();
  });

  test("ws:// through HTTP proxy with auth", async () => {
    using recorded = await startRecordingProxy({ requireAuth: true });
    const ws = new WebSocket(`ws://127.0.0.1:${wsPort}`, {
      proxy: `http://proxy_user:proxy_pass@127.0.0.1:${recorded.port}`,
    });
    expect({ events: await echoSession(ws, "hello with auth"), requests: recorded.requests }).toEqual({
      events: echoed("hello with auth"),
      requests: [connectRequest(wsPort, { "proxy-authorization": `Basic ${btoa("proxy_user:proxy_pass")}` })],
    });
    gc();
  });

  test("ws:// through proxy with custom headers", async () => {
    using recorded = await startRecordingProxy();
    const ws = new WebSocket(`ws://127.0.0.1:${wsPort}`, {
      proxy: {
        url: `http://127.0.0.1:${recorded.port}`,
        headers: { "X-Custom-Proxy-Header": "test-value" },
      },
    });
    expect({ events: await echoSession(ws, "hello with a proxy header"), requests: recorded.requests }).toEqual({
      events: echoed("hello with a proxy header"),
      requests: [connectRequest(wsPort, { "x-custom-proxy-header": "test-value" })],
    });
    gc();
  });

  test("ws:// through proxy with Headers class instance", async () => {
    using recorded = await startRecordingProxy();
    const headers = new Headers({ "X-Custom-Proxy-Header": "test-value-from-headers-class" });
    const ws = new WebSocket(`ws://127.0.0.1:${wsPort}`, {
      proxy: {
        url: `http://127.0.0.1:${recorded.port}`,
        headers: headers,
      },
    });
    expect({ events: await echoSession(ws, "hello with a Headers instance"), requests: recorded.requests }).toEqual({
      events: echoed("hello with a Headers instance"),
      requests: [connectRequest(wsPort, { "x-custom-proxy-header": "test-value-from-headers-class" })],
    });
    gc();
  });

  test("proxy auth failure returns error", async () => {
    using recorded = await startRecordingProxy({ requireAuth: true });
    const url = `ws://127.0.0.1:${wsPort}`;
    const ws = new WebSocket(url, {
      proxy: `http://127.0.0.1:${recorded.port}`, // No auth provided
    });
    // The proxy answered 407 to a CONNECT without credentials.
    expect({ events: await failingSession(ws), requests: recorded.requests }).toEqual({
      events: failed(url, "Proxy connection failed", 1006),
      requests: [connectRequest(wsPort)],
    });
    gc();
  });

  test("proxy wrong credentials returns error", async () => {
    using recorded = await startRecordingProxy({ requireAuth: true });
    const url = `ws://127.0.0.1:${wsPort}`;
    const ws = new WebSocket(url, {
      proxy: `http://wrong_user:wrong_pass@127.0.0.1:${recorded.port}`,
    });
    // The credentials were sent, and the proxy answered 403.
    expect({ events: await failingSession(ws), requests: recorded.requests }).toEqual({
      events: failed(url, "Proxy connection failed", 1006),
      requests: [connectRequest(wsPort, { "proxy-authorization": `Basic ${btoa("wrong_user:wrong_pass")}` })],
    });
    gc();
  });
});

describe("WebSocket wss:// through HTTP proxy (TLS tunnel)", () => {
  // This tests the TLS tunnel: wss:// target through HTTP proxy
  // The outer connection is plain TCP to the HTTP proxy, then TLS is
  // negotiated inside the tunnel to the wss:// target server.

  test("wss:// through HTTP proxy", async () => {
    using recorded = await startRecordingProxy();
    const ws = new WebSocket(`wss://127.0.0.1:${wssPort}`, {
      proxy: `http://127.0.0.1:${recorded.port}`,
      // The wss:// server uses a self-signed certificate.
      tls: { rejectUnauthorized: false },
    });
    expect({ events: await echoSession(ws, "hello via tls tunnel"), requests: recorded.requests }).toEqual({
      events: echoed("hello via tls tunnel"),
      requests: [connectRequest(wssPort)],
    });
    gc();
  });

  test("server-initiated ping survives through TLS tunnel proxy", async () => {
    // Regression test: sendPong checked socket.isClosed() on the detached tcp
    // field instead of using hasTCP(). For wss:// through HTTP proxy, the
    // WebSocket uses initWithTunnel which sets tcp = detached (all I/O goes
    // through proxy_tunnel). Detached sockets return true for isClosed(), so
    // sendPong would immediately dispatch a 1006 close instead of sending the
    // pong through the tunnel.
    let pongs = 0;
    const serverClosed = Promise.withResolvers<number>();
    using pingServer = Bun.serve({
      port: 0,
      tls: {
        key: tlsCerts.key,
        cert: tlsCerts.cert,
      },
      fetch(req, server) {
        if (server.upgrade(req)) return;
        return new Response("Expected WebSocket", { status: 400 });
      },
      websocket: {
        message(ws, message) {
          if (String(message) === "ready") {
            // Send a ping after the client confirms it's connected.
            // On the buggy code path, this triggers sendPong on the detached
            // socket → dispatchAbruptClose → 1006.
            ws.ping();
            // Follow up with a text message. If the client receives this,
            // the connection survived the ping/pong exchange.
            ws.send("after-ping");
          }
        },
        pong() {
          pongs++;
        },
        close(_ws, code) {
          serverClosed.resolve(code);
        },
      },
    });

    using recorded = await startRecordingProxy();
    const ws = new WebSocket(`wss://127.0.0.1:${pingServer.port}`, {
      proxy: `http://127.0.0.1:${recorded.port}`,
      tls: { rejectUnauthorized: false },
    });
    ws.addEventListener("open", () => ws.send("ready"));
    ws.addEventListener("message", event => {
      if (String(event.data) === "after-ping") ws.close(1000);
    });

    const events = await clientEvents(ws);
    // A client that failed the connection itself never tells the server
    // anything, so the server's close is only awaited after a clean close.
    const serverCloseCode = closeCodeOf(events) === 1000 ? await serverClosed.promise : "client did not close cleanly";
    // The pong reached the server before the close frame did.
    expect({ events, pongs, serverCloseCode, requests: recorded.requests }).toEqual({
      events: ["after-ping", { code: 1000, reason: "", wasClean: true }],
      pongs: 1,
      serverCloseCode: 1000,
      requests: [connectRequest(pingServer.port)],
    });
    gc();
  });
});

describe("WebSocket through HTTPS proxy (TLS proxy)", () => {
  // These tests verify WebSocket connections through HTTPS (TLS) proxy servers

  test("ws:// through HTTPS proxy with CA certificate", async () => {
    using recorded = await startRecordingProxy({ tls: true });
    const ws = new WebSocket(`ws://127.0.0.1:${wsPort}`, {
      proxy: `https://127.0.0.1:${recorded.port}`,
      // Trust the self-signed certificate used by the proxy
      tls: { ca: tlsCerts.cert },
    });
    expect({ events: await echoSession(ws, "hello via https proxy"), requests: recorded.requests }).toEqual({
      events: echoed("hello via https proxy"),
      requests: [connectRequest(wsPort)],
    });
    gc();
  });

  test("ws:// through HTTPS proxy fails without CA certificate", async () => {
    using recorded = await startRecordingProxy({ tls: true });
    const url = `ws://127.0.0.1:${wsPort}`;
    const ws = new WebSocket(url, {
      proxy: `https://127.0.0.1:${recorded.port}`,
      // No CA certificate: the proxy's self-signed certificate is not trusted.
    });
    // The client reached the proxy and gave up inside the TLS handshake, before any CONNECT.
    expect({
      events: await failingSession(ws),
      connections: recorded.connections,
      requests: recorded.requests,
    }).toEqual({
      events: failed(url, "TLS handshake failed", 1015),
      connections: 1,
      requests: [],
    });
    gc();
  });

  test("ws:// through HTTPS proxy with rejectUnauthorized: false", async () => {
    using recorded = await startRecordingProxy({ tls: true });
    const ws = new WebSocket(`ws://127.0.0.1:${wsPort}`, {
      proxy: `https://127.0.0.1:${recorded.port}`,
      tls: { rejectUnauthorized: false }, // Skip TLS verification for the proxy
    });
    expect({ events: await echoSession(ws, "hello via https proxy no verify"), requests: recorded.requests }).toEqual({
      events: echoed("hello via https proxy no verify"),
      requests: [connectRequest(wsPort)],
    });
    gc();
  });
});

// Squid proxy tests - run when Docker is enabled
// Uses docker-compose infrastructure to run squid proxy
// Import docker-compose dynamically to avoid issues when not using docker
const dockerCompose = require("../../../docker/index.ts");

describe.skipIf(!isDockerEnabled())("WebSocket through Squid proxy (Docker)", () => {
  let squidInfo: { host: string; ports: Record<number, number>; proxyUrl?: string };

  beforeAll(async () => {
    console.log("Starting squid proxy container...");
    squidInfo = await dockerCompose.ensure("squid");
    console.log(`Squid proxy ready at: ${squidInfo.host}:${squidInfo.ports[3128]}`);
  }, 240_000);

  afterAll(async () => {
    if (!process.env.BUN_KEEP_DOCKER) {
      await dockerCompose.down();
    }
  }, 30_000);

  test("ws:// through squid proxy to local server", async () => {
    const { promise, resolve, reject } = Promise.withResolvers<string[]>();
    const proxyUrl = `http://${squidInfo.host}:${squidInfo.ports[3128]}`;

    // Connect to our local WebSocket server through squid
    const ws = new WebSocket(`ws://host.docker.internal:${wsPort}`, {
      proxy: proxyUrl,
    });

    const receivedMessages: string[] = [];

    ws.onopen = () => {
      ws.send("hello from bun via squid");
    };

    ws.onmessage = event => {
      receivedMessages.push(String(event.data));
      if (receivedMessages.length === 2) {
        ws.close();
      }
    };

    ws.onclose = () => {
      resolve(receivedMessages);
    };

    ws.onerror = event => {
      reject(event);
    };

    const messages = await promise;
    expect(messages).toContain("connected");
    expect(messages).toContain("hello from bun via squid");
    gc();
  }, 30_000);

  test("wss:// through squid proxy to local server", async () => {
    const { promise, resolve, reject } = Promise.withResolvers<string[]>();
    const proxyUrl = `http://${squidInfo.host}:${squidInfo.ports[3128]}`;

    // Connect to our local secure WebSocket server through squid
    const ws = new WebSocket(`wss://host.docker.internal:${wssPort}`, {
      proxy: proxyUrl,
      tls: {
        rejectUnauthorized: false, // Accept self-signed cert
      },
    });

    const receivedMessages: string[] = [];

    ws.onopen = () => {
      ws.send("hello wss from bun via squid");
    };

    ws.onmessage = event => {
      receivedMessages.push(String(event.data));
      if (receivedMessages.length === 2) {
        ws.close();
      }
    };

    ws.onclose = () => {
      resolve(receivedMessages);
    };

    ws.onerror = event => {
      reject(event);
    };

    const messages = await promise;
    expect(messages).toContain("connected");
    expect(messages).toContain("hello wss from bun via squid");
    gc();
  }, 30_000);
});

describe("ws module with HttpsProxyAgent", () => {
  // These tests verify that the ws module (src/js/thirdparty/ws.js) correctly
  // passes the agent property to the native WebSocket

  const WS = require("ws");

  test("ws module passes agent to native WebSocket", async () => {
    using recorded = await startRecordingProxy();
    const agent = new HttpsProxyAgent(`http://127.0.0.1:${recorded.port}`);
    const ws = new WS(`ws://127.0.0.1:${wsPort}`, { agent });

    const events: unknown[] = [];
    const { promise, resolve } = Promise.withResolvers<void>();
    ws.on("open", () => ws.send("hello from ws module via agent"));
    ws.on("message", (data: Buffer) => {
      events.push(data.toString());
      if (events.length === 2) ws.close(1000);
    });
    ws.on("error", (err: Error) => events.push({ error: err.message }));
    ws.on("close", (code: number, reason: Buffer) => {
      events.push({ code, reason: String(reason) });
      resolve();
    });
    await promise;

    // The CONNECT request proves the connection went through the agent's proxy.
    expect({ events, requests: recorded.requests }).toEqual({
      events: ["connected", "hello from ws module via agent", { code: 1000, reason: "" }],
      requests: [connectRequest(wsPort)],
    });
    gc();
  });
});

describe.concurrent("WebSocket NO_PROXY bypass", () => {
  // Each child connects to the echo server through an auth proxy it has no
  // credentials for. When NO_PROXY applies, the proxy never sees a connection
  // and the echo server greets the child. When it does not apply, the proxy
  // answers the CONNECT with 407 and the child reports the failure.
  const childScript = (proxyPort: number) => `
    const ws = new WebSocket("ws://127.0.0.1:${wsPort}", { proxy: "http://127.0.0.1:${proxyPort}" });
    ws.onmessage = event => { console.log("message:", event.data); ws.close(1000); };
    ws.onerror = event => console.log("error:", event.message);
    ws.onclose = event => console.log("close:", event.code, JSON.stringify(event.reason));
  `;

  test.each([
    ["NO_PROXY matching hostname bypasses explicit proxy for ws://", () => "127.0.0.1", "direct"],
    ["NO_PROXY matching host:port bypasses proxy for ws://", () => `127.0.0.1:${wsPort}`, "direct"],
    ["NO_PROXY not matching still uses proxy (auth fails)", () => "other.host.com", "proxied"],
    ["NO_PROXY=* bypasses all proxies", () => "*", "direct"],
  ] as const)("%s", async (_, noProxy, outcome) => {
    using recorded = await startRecordingProxy({ requireAuth: true });
    await using proc = Bun.spawn({
      cmd: [bunExe(), "-e", childScript(recorded.port)],
      // The lowercase variable takes precedence over NO_PROXY, so an ambient
      // no_proxy=127.0.0.1 must not reach the child.
      env: { ...bunEnv, NO_PROXY: noProxy(), no_proxy: undefined },
      stdout: "pipe",
      stderr: "pipe",
    });
    const [stdout, stderr, exitCode] = await Promise.all([proc.stdout.text(), proc.stderr.text(), proc.exited]);

    expect({ stdout, stderr, exitCode, proxyConnections: recorded.connections }).toEqual(
      outcome === "direct"
        ? { stdout: `message: connected\nclose: 1000 ""\n`, stderr: "", exitCode: 0, proxyConnections: 0 }
        : {
            stdout:
              `error: WebSocket connection to 'ws://127.0.0.1:${wsPort}/' failed: Proxy connection failed\n` +
              `close: 1006 "Proxy connection failed"\n`,
            stderr: "",
            exitCode: 0,
            proxyConnections: 1,
          },
    );
  });
});
