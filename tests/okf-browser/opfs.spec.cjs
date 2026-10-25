const { test, expect } = require("@playwright/test");

// Each check passes, except that the createWritable() check is skipped in a
// browser that does not have createWritable(). The report names each skip.
//
// The page runs in a persistent context with a fresh profile: WebKit in
// Playwright gives the origin private file system only to a persistent
// context, and the same setup keeps the three engines alike.
test("the browser stores meet the store contract", async ({ playwright, browserName, baseURL }, testInfo) => {
  const context = await playwright[browserName].launchPersistentContext(testInfo.outputPath("profile"), {
    headless: true,
    baseURL,
  });
  try {
    const page = await context.newPage();
    const errors = [];
    page.on("pageerror", error => errors.push(String(error)));
    // The worker starts from code in the page script, so the page loads no
    // other file from the server.
    const served = [];
    page.on("request", request => {
      const url = new URL(request.url());
      if (url.protocol.startsWith("http")) served.push(url.pathname);
    });
    await page.goto("/");
    await page.waitForFunction(() => globalThis.okfBrowserResult !== undefined, null, { timeout: 50_000 });
    expect(errors).toEqual([]);
    expect([...new Set(served)].sort()).toEqual(["/", "/okf-browser.js"]);
    const text = await page.evaluate(() => globalThis.okfBrowserResult);
    const results = Object.fromEntries(text.split("\n").map(line => {
      const at = line.indexOf("=");
      return [line.slice(0, at), line.slice(at + 1)];
    }));
    for (const [name, result] of Object.entries(results)) {
      if (result.startsWith("skipped")) {
        testInfo.annotations.push({ type: "skip", description: `${name}: ${result}` });
        console.log(`${testInfo.project.name}: ${name} ${result}`);
      }
    }
    expect(Object.keys(results)).toEqual(["writable", "worker", "auto", "idb", "idb-separate"]);
    expect(results.writable, "the createWritable() check").toMatch(/^(ok|skipped: )/);
    const { writable, ...rest } = results;
    expect(rest).toEqual({ worker: "ok", auto: "ok", idb: "ok", "idb-separate": "ok" });
  } finally {
    await context.close();
  }
});
