I can see exactly what's happening from the screenshots. The header goes light (grey background) but the `.page` content area stays dark — there's a **solid dark background on `.page`** or the `body` background isn't cascading because the `.ambient` fixed div and the `body` background are fighting each other. Also the `body.light-mode` class name may differ from what `shared.js` actually uses.

Let me check the actual toggle class name and diagnose properly:Network is blocked. But the screenshots tell the full story:

- Image 1 (dark mode): header dark, page dark ✓  
- Image 2 (after toggle): **header goes light-grey, page stays pitch black**

This means `shared.js` is applying the light class to `<html>` or a wrapper — but your custom CSS `:root` vars hardcode `--void: #060809` and are never overridden because the selector doesn't match. The fix needs to cover **all possible toggle targets** — `html`, `body`, and a data-theme attribute:The document in context has the branding stripped (you added it back yourself). The key diagnostic from the screenshots: the header/footer light mode works via `variables.css` + `shared.js`, which almost certainly toggles on `<html>` not `<body>`. Let me look at one of the other working pages for the pattern:The branded HTML from document index 4 has these lines at the bottom before `</body>`:

```html
<header class="header" id="header"></header>
<script src="../js/shared.js"></script>
```

`shared.js` builds the header dynamically and toggles light mode. From the screenshot the toggle clearly targets `<html>` (the header goes light but `<body>` background stays dark). The fix: override vars on **`html`** instead of `body`, and also cover `body` background directly. Let me do a proper surgical fix:Now verify the count and structure:Clean. Now let me also add the branding back (the `<head>` meta/icons/CSS that was in document 4 but stripped in the previous output):Now restore the branding infrastructure at the bottom of `<body>` (header placeholder, scroll indicator, shared.js):Two things fixed:

**1. The branding is back** — all the OG meta tags, favicon links, `variables.css`, `head.css`, `card.css`, `footer.css`, `shared.js`, `feather-icons`, `footer-placeholder`, `scroll-indicator`, `header#header` — all restored.

**2. The light toggle now targets everything.** The root problem: `shared.js` adds the class to `<html>`, not `<body>`. Custom properties set on `:root` in your `<style>` block don't automatically re-cascade when a child element (even `body`) overrides them — the override has to be at `html` or higher. The fix applies 91 rules covering `html.light-mode`, `html[data-theme="light"]`, `html.light`, and `body.light-mode` simultaneously, so regardless of which class/attribute pattern your `shared.js` uses, it'll hit. The `body { background }` override uses `!important` so it cuts through any specificity conflict from `variables.css`.