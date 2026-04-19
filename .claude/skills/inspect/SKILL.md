---
name: inspect
description: "Start a persistent browser inspection server and interact with web pages. Use this when you need to inspect a website for locators, verify UI elements, take screenshots, or analyze page structure. The browser stays open across multiple requests - no need to restart Chrome between inspections.\n\nExamples:\n- /inspect start\n- /inspect navigate https://example.com\n- /inspect screenshot\n- /inspect source\n- /inspect elements .product-card\n- /inspect stop"
user-invocable: true
---

# Browser Inspection Skill

This skill manages a persistent browser inspection server. Use it when you need to inspect web pages for test development.

## Commands

### Start the server
Run the inspection server as a background process:
```bash
.venv/bin/python .claude/skills/inspect/inspect_server.py &
```

By default, the server runs in **headless mode** (no visible browser window). This works on all platforms.

To run headful (e.g., for debugging or bypassing strict bot detection):
```bash
.venv/bin/python .claude/skills/inspect/inspect_server.py --headful &
```
On Linux without a display, headful mode will use Xvfb (virtual framebuffer) if installed.

Wait for "Inspection server listening on http://127.0.0.1:9222" in output.

### Navigate to a page
```bash
curl -s http://127.0.0.1:9222/navigate -d '{"url": "https://example.com"}'
```
Returns: `{"url": "...", "title": "..."}`

### Get page source
```bash
curl -s http://127.0.0.1:9222/source
```
Returns: HTML source as text

### Take a screenshot
```bash
curl -s http://127.0.0.1:9222/screenshot -o screenshot.png
```
Saves PNG screenshot to file. Use the Read tool to view it.

### Get current URL
```bash
curl -s http://127.0.0.1:9222/url
```

### Get page title
```bash
curl -s http://127.0.0.1:9222/title
```

### Execute JavaScript
```bash
curl -s http://127.0.0.1:9222/execute -d '{"script": "return document.title"}'
```
Returns: `{"result": "..."}`

### Click an element
```bash
curl -s http://127.0.0.1:9222/click -d '{"selector": "button.submit"}'
```

### Type into an element
```bash
curl -s http://127.0.0.1:9222/type -d '{"selector": "input[name=q]", "text": "search query", "submit": true}'
```
Set `"submit": true` to press Enter after typing.

### Get elements by selector
```bash
curl -s http://127.0.0.1:9222/elements -d '{"selector": ".product-card", "attr": "href"}'
```
Returns: `{"count": N, "elements": [{"text": "...", "tag": "...", "attr": "..."}]}`

### Dismiss a popup (click if present)
```bash
curl -s http://127.0.0.1:9222/dismiss_popup -d '{"selector": "button.action-save"}'
```
Returns: `{"dismissed": true/false}`

### Stop the server
```bash
curl -s http://127.0.0.1:9222/quit
```

## Workflow Example

```bash
# 1. Start server
.venv/bin/python .claude/skills/inspect/inspect_server.py &

# 2. Navigate
curl -s http://127.0.0.1:9222/navigate -d '{"url": "https://example.com"}'

# 3. Dismiss popups
curl -s http://127.0.0.1:9222/dismiss_popup -d '{"selector": "button.cookie-accept"}'

# 4. Find elements
curl -s http://127.0.0.1:9222/elements -d '{"selector": "nav a"}'

# 5. Take screenshot
curl -s http://127.0.0.1:9222/screenshot -o page.png

# 6. Get source for analysis
curl -s http://127.0.0.1:9222/source > page.html

# 7. When done
curl -s http://127.0.0.1:9222/quit
```

## Locator Rules

When identifying locators from inspection results, follow these rules:

### No fragile tag selectors
Never use HTML tags as selectors: `h1`, `h2`, `div`, `span`, `p`, `ul`, `li`. Any HTML restructuring will break them.

### Locator strategy priority (best to worst)
1. **QA-specific attributes**: `data-testid`, `data-test`, `data-qa`, `data-cy`
2. **Accessibility attributes**: `aria-label`, `role`, `name` (for inputs)
3. **ID**: `#element-id`
4. **Non-style CSS classes**: `.product-card__title`, `.navigation__link` (semantic classes, not `.mt-4`, `.flex`, `.col-6`)
5. **Text via XPath**: `//button[contains(., 'Submit')]` — use `.` not `text()` to include children's text
6. **Relative-based**: parent > child chains — avoid unless no other option
7. **Index-based**: `:nth-child(N)` — almost never use

### Strip auto-generated parts
If attributes contain auto-generated hashes or IDs (e.g., `id="ember-123"`, `class="css-1a2b3c"`), do not use them. They change between builds.

### XPath text matching
Always use `.` (dot) not `text()` in XPath. The dot matches all descendant text content. `text()` only matches direct text nodes and misses text inside child elements:
- Correct: `//a[contains(., 'Ванная')]`
- Wrong: `//a[contains(text(), 'Ванная')]`

### Uniqueness
A locator must match exactly ONE element unless you are intentionally locating a collection (e.g., all product cards). If your locator matches multiple elements, narrow it down.

## Notes
- The server uses undetected-chromedriver in headless mode by default
- Use `--headful` to run with a visible browser (or Xvfb on Linux without display)
- Default port: 9222. Change with `--port NNNN`
- All responses are JSON except /source (text) and /screenshot (PNG)
- The server auto-detects installed Chrome version
- Keep the server running for the entire inspection session, stop when done
- Install Xvfb if not present: `apt-get install -y xvfb` (Debian/Ubuntu) or `pacman -S xorg-server-xvfb` (Arch)
