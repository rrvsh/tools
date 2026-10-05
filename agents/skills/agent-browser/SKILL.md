---
name: agent-browser
description: Use this for agent browser.
---

# Agent browser

## Stateful flows and form controls

### Keep one interface and session for a stateful flow

- Once a flow starts with raw `args` calls, continue with raw calls.
- Pass the same `--session <name>` on every call.
- Do not switch between raw calls, `job`, and unnamed sessions midway.
- Before entering data or clicking a consequential control, run `get url`.
- If it returns `about:blank`, reopen the known page instead of continuing.

### Check navigation before retrying a failed click

- When `click` reports a dispatch or timeout failure, immediately run `get url`.
- If the URL changed to the expected destination, do not click again.
- Take a new snapshot and continue from the new page.
- Retry only when the URL and page state confirm that nothing happened.

### Verify every controlled field after filling it

- Run `fill`.
- Wait briefly.
- Run `get value <selector>`.
- If the value reverted or differs, focus the field and use keyboard `type`.
- Read the value again before continuing.

### Close custom comboboxes with the keyboard

- After opening a custom combobox, take a fresh snapshot.
- Focus its input and use `ArrowDown` and `Enter` to select the option.
- Take another snapshot and confirm the popup closed.
- Do not click controls behind an open popup.

### Read actual form values before submission

- Do not use visible text or `assertText` as proof that a form value persisted.
- Run `get value` for each important input immediately before submission.
- For checkboxes, selects, and buttons, inspect their checked, selected, or disabled state directly.

## Long-running actions

### Poll instead of using one long text wait

- Do not rely on one `wait --text` call for operations that may take more than 20 seconds.
- Set a total deadline for the operation.
- Poll every 10–20 seconds with `snapshot`, `get text`, or `get count`.
- Stop polling when the expected final state appears or the total deadline expires.

### Do not repeat an action after a wrapper timeout

- If the browser call times out after starting an import, analysis, checkout, upload, or other long operation, do not click the action again.
- First inspect the current URL and page state.
- Check the application's status API, logs, or durable record when available.
- Retry only after confirming that the original operation was not accepted.

### Refresh once before declaring an operation stuck

- When polling expires, navigate to a safe GET page or refresh the status page once.
- Recheck the expected final state.
- Do not refresh a page that may resubmit form data.
- If the state is still incomplete, report the timeout rather than starting a duplicate operation.

## Evidence and file handling

### Verify where a download actually landed

- After `waitForDownload`, check the requested destination.
- If it is missing, inspect the browser result's artifact details and `~/Downloads`.
- Verify the file's type and contents before moving or reporting it.
- Do not treat a successful download event as proof of the requested path.

### Preserve redirected browser output

- When browser output says it was truncated or provides `fullOutputPath`, use that file for extraction or evidence.
- Do not derive conclusions from the shortened inline output.
- Copy the full output to the requested artifact location when it must persist.

### Filter network inspection

- Do not request the complete network history on a busy application.
- Filter by URL, method, resource type, or failed status first.
- Inspect individual request IDs for headers, initiators, or response details.
- Broaden the filter only when the targeted query finds nothing.

### Check screenshots for missing composited elements

- Open every evidence screenshot after capture.
- Compare important text and controls against the current snapshot.
- If an element visible in the snapshot is absent from the screenshot, wait for rendering and capture again.
- Do not submit a screenshot as evidence while required elements are missing.

## Page evaluation

### Write eval code for the browser context

- Code passed to `eval --stdin` runs inside the page.
- Use `document`, `window`, and browser APIs directly.
- Do not reference a Playwright `page` object.

### Invoke eval functions explicitly

- Do not pass an uncalled function expression such as `() => document.title`.
- Use an invoked expression such as `(() => document.title)()`.
- For asynchronous work, use an async IIFE: `(async () => { ... })()`.

## Gmail and FileAI test accounts

### Use the authenticated FileAI mailbox

- On Kikir, the shared browser is authenticated to Gmail as `rafiq@file.ai`.
- Do not assume that Alpha or Nemesis is authenticated.
- Create a unique plus alias for each FileAI test account: `rafiq+<ticket>-<timestamp>@file.ai`.
- Do not reuse an alias when old account or email state could affect the test.
- Find its messages with the exact Gmail query `to:<full-alias>`.

### Use accessibility rows when Gmail DOM queries return nothing

- Search Gmail with an exact query first.
- If the message is visible in the snapshot but DOM selectors return zero rows, locate it by accessible row and sender or subject.
- Click that row instead of inventing CSS selectors.

### Avoid Gmail's sticky header intercepting message links

- If a link click is intercepted by Gmail's header, do not repeat the same coordinate click.
- Open the message's exact thread URL.
- Take a new snapshot inside the thread.
- Activate the intended link using its new ref or accessible name.

## Inaccessible embedded fields

### Interact visually with inaccessible embedded fields

- First try normal snapshot refs, semantic locators, and frame access.
- Use this fallback only when a field is visible in the screenshot but absent from the snapshot and inaccessible through frame commands.
- Do not use page `eval` to cross the embedded origin boundary.
- Keep a fixed viewport.
- Click the first field using screenshot coordinates, then use keyboard typing and `Tab` to move through related fields.
- Capture another screenshot and verify every populated field.
- If the layout moves, focus is uncertain, or a field remains empty, stop before submission.

Stripe Elements is the confirmed example, but the same failure can occur in other payment, identity, or secure-input widgets.

## Virtualized content

### Do not treat rendered body text as complete

- Check whether scrolling replaces older DOM nodes instead of retaining them.
- Scroll through the content and collect each newly rendered section.
- When the page embeds complete serialized data, extract that data instead of relying only on `get text body`.
- If neither method covers the full content, report the extraction as partial.

## FileAI Stripe testing

### Allow confirmed test-mode checkout

- Proceed without separate approval only when both the FileAI origin is non-production and Stripe is visibly confirmed as test mode.
- Stop if the origin, Stripe account, or mode is ambiguous.
- Use Stripe's test card `4242 4242 4242 4242`, a future expiry, and a test CVC.
- Never apply this permission to live purchases, refunds, credits, or customer-affecting subscription changes.
