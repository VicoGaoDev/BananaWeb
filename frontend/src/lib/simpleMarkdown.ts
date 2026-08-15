import MarkdownIt from "markdown-it";

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function formatInline(text: string): string {
  let html = escapeHtml(text);
  html = html.replace(/`([^`\n]+)`/g, "<code>$1</code>");
  html = html.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
  html = html.replace(/(^|[^*])\*([^*\n]+)\*(?!\*)/g, "$1<em>$2</em>");
  return html;
}

function stripInlineMarkdown(text: string): string {
  return text
    .replace(/`([^`\n]+)`/g, "$1")
    .replace(/\*\*([^*]+)\*\*/g, "$1")
    .replace(/(^|[^*])\*([^*\n]+)\*(?!\*)/g, "$1$2")
    .trim();
}

export function stripMarkdownDecorations(text: string): string {
  return text
    .replace(/```[\w-]*\n?([\s\S]*?)```/g, "$1")
    .replace(/^#{1,6}\s+/gm, "")
    .replace(/^>\s?/gm, "")
    .replace(/^[-*]\s+/gm, "")
    .replace(/^\d+\.\s+/gm, "")
    .replace(/^---+$/gm, "")
    .split("\n")
    .map((line) => stripInlineMarkdown(line))
    .join("\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

const markdownRenderer = new MarkdownIt({
  html: false,
  breaks: true,
  linkify: true,
});

const defaultLinkOpen =
  markdownRenderer.renderer.rules.link_open
  || ((tokens, idx, options, _env, self) => self.renderToken(tokens, idx, options));

markdownRenderer.renderer.rules.link_open = (tokens, idx, options, env, self) => {
  const token = tokens[idx];
  token.attrSet("target", "_blank");
  token.attrSet("rel", "noopener noreferrer nofollow");
  return defaultLinkOpen(tokens, idx, options, env, self);
};

markdownRenderer.renderer.rules.table_open = () => '<div class="md-table-wrap"><table class="md-table">';
markdownRenderer.renderer.rules.table_close = () => "</table></div>";

const COPY_ICON = '<svg viewBox="0 0 24 24" width="14" height="14" aria-hidden="true"><rect x="9" y="9" width="11" height="11" rx="2" fill="none" stroke="currentColor" stroke-width="1.8"/><rect x="4" y="4" width="11" height="11" rx="2" fill="none" stroke="currentColor" stroke-width="1.8"/></svg>';
const CHECK_ICON = '<svg viewBox="0 0 24 24" width="14" height="14" aria-hidden="true"><path d="M5 12.5 10 17.5 19 7.5" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>';
const GENERATE_ICON = '<svg viewBox="0 0 24 24" width="14" height="14" aria-hidden="true"><rect x="3.5" y="5.5" width="17" height="13" rx="2.2" fill="none" stroke="currentColor" stroke-width="1.8"/><circle cx="8.6" cy="10" r="1.5" fill="currentColor"/><path d="M6.2 16.6 10 12.8l2.3 2.2 3.1-3.4 4.4 5" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>';

function normalizeLang(info: string): string {
  const raw = (info || "").trim().split(/\s+/)[0] || "";
  const lang = raw.toLowerCase().replace(/[^a-z0-9_+#-]/g, "");
  return lang || "plaintext";
}

function highlightJson(code: string): string {
  const parts: string[] = [];
  const re = /("(?:\\.|[^"\\])*")(\s*:)?|(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)|\b(true|false|null)\b/g;
  let last = 0;
  let match: RegExpExecArray | null;
  while ((match = re.exec(code))) {
    parts.push(escapeHtml(code.slice(last, match.index)));
    if (match[1]) {
      const cls = match[2] ? "md-tok-key" : "md-tok-str";
      parts.push(`<span class="${cls}">${escapeHtml(match[1])}</span>${escapeHtml(match[2] || "")}`);
    } else if (match[3]) {
      parts.push(`<span class="md-tok-num">${escapeHtml(match[3])}</span>`);
    } else {
      parts.push(`<span class="md-tok-kw">${escapeHtml(match[4])}</span>`);
    }
    last = match.index + match[0].length;
  }
  parts.push(escapeHtml(code.slice(last)));
  return parts.join("");
}

const HASH_COMMENT_LANGS = new Set([
  "bash", "ini", "perl", "py", "python", "r", "rb", "ruby", "sh", "shell", "toml", "yaml", "yml", "zsh",
]);

function highlightGeneric(code: string, lang: string): string {
  const hashComment = HASH_COMMENT_LANGS.has(lang) ? "|#[^\\n]*" : "";
  const re = new RegExp(
    `//[^\\n]*|/\\*[\\s\\S]*?\\*/${hashComment}|"(?:\\\\.|[^"\\\\])*"|'(?:\\\\.|[^'\\\\])*'|\`(?:\\\\.|[^\`\\\\])*\`|\\b-?\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?\\b|\\b(?:true|false|null|undefined|None|True|False)\\b`,
    "g",
  );
  const parts: string[] = [];
  let last = 0;
  let match: RegExpExecArray | null;
  while ((match = re.exec(code))) {
    parts.push(escapeHtml(code.slice(last, match.index)));
    const token = match[0];
    let cls = "md-tok-str";
    if (token.startsWith("//") || token.startsWith("/*") || token.startsWith("#")) {
      cls = "md-tok-comment";
    } else if (/^-?\d/.test(token)) {
      cls = "md-tok-num";
    } else if (/^(true|false|null|undefined|None|True|False)$/.test(token)) {
      cls = "md-tok-kw";
    }
    parts.push(`<span class="${cls}">${escapeHtml(token)}</span>`);
    last = match.index + match[0].length;
  }
  parts.push(escapeHtml(code.slice(last)));
  return parts.join("");
}

function highlightCode(code: string, lang: string): string {
  if (lang === "json") return highlightJson(code);
  if (lang === "plaintext" || lang === "text" || lang === "txt") return escapeHtml(code);
  return highlightGeneric(code, lang);
}

function renderCopyActions(): string {
  return [
    `<div class="md-code-actions">`,
    `<button type="button" class="md-code-copy" title="复制" aria-label="复制">`,
    `<span class="md-code-copy-icon">${COPY_ICON}</span>`,
    `<span class="md-code-copy-done">${CHECK_ICON}</span>`,
    `</button>`,
    `<button type="button" class="md-code-generate" title="复制并去生图" aria-label="复制并去生图">`,
    GENERATE_ICON,
    `</button>`,
    `</div>`,
  ].join("");
}

function renderCopyToolbar(label: string): string {
  return [
    `<div class="md-code-block md-copyable">`,
    `<div class="md-code-toolbar">`,
    `<span class="md-code-lang">${escapeHtml(label)}</span>`,
    renderCopyActions(),
    `</div>`,
  ].join("");
}

function renderCodeBlock(code: string, lang: string): string {
  const language = normalizeLang(lang);
  const body = highlightCode(code.replace(/\n$/, ""), language);
  return [
    renderCopyToolbar(language),
    `<pre data-md-copy-source><code class="language-${escapeHtml(language)}">${body}</code></pre>`,
    `</div>`,
  ].join("");
}

markdownRenderer.renderer.rules.fence = (tokens, idx) => {
  const token = tokens[idx];
  return renderCodeBlock(token.content, token.info || "");
};

markdownRenderer.renderer.rules.code_block = (tokens, idx) => (
  renderCodeBlock(tokens[idx].content, "plaintext")
);

markdownRenderer.renderer.rules.blockquote_open = () => (
  `${renderCopyToolbar("引用")}<blockquote data-md-copy-source>`
);

markdownRenderer.renderer.rules.blockquote_close = () => "</blockquote></div>";

const INLINE_STRONG_COPY_MIN = 40;

type MdInlineToken = {
  type: string;
  content: string;
  children: MdInlineToken[] | null;
};

function isIgnorableInline(token: MdInlineToken): boolean {
  if (token.type === "softbreak" || token.type === "hardbreak") return true;
  return token.type === "text" && !token.content.trim();
}

function collectInlineText(tokens: MdInlineToken[]): string {
  return tokens.map((token) => {
    if (token.type === "text" || token.type === "code_inline") return token.content;
    if (token.type === "softbreak" || token.type === "hardbreak") return "\n";
    return "";
  }).join("");
}

function findStrongSpan(tokens: MdInlineToken[], openIdx: number): { closeIdx: number; inner: MdInlineToken[] } | null {
  let depth = 1;
  for (let i = openIdx + 1; i < tokens.length; i += 1) {
    if (tokens[i].type === "strong_open") depth += 1;
    if (tokens[i].type !== "strong_close") continue;
    depth -= 1;
    if (depth === 0) return { closeIdx: i, inner: tokens.slice(openIdx + 1, i) };
  }
  return null;
}

function renderStrongCopyBlock(text: string): string {
  return [
    renderCopyToolbar("文本"),
    `<div class="md-strong-body" data-md-copy-source>${escapeHtml(text)}</div>`,
    `</div>`,
  ].join("");
}

function renderStrongCopyInline(text: string): string {
  return [
    `<span class="md-copyable md-strong-inline">`,
    `<strong data-md-copy-source>${escapeHtml(text)}</strong>`,
    renderCopyActions(),
    `</span>`,
  ].join("");
}

function isInsideListItem(tokens: Array<{ type: string }>, idx: number): boolean {
  let depth = 0;
  for (let i = idx - 1; i >= 0; i -= 1) {
    const type = tokens[i].type;
    if (type === "list_item_close") depth += 1;
    if (type !== "list_item_open") continue;
    if (depth === 0) return true;
    depth -= 1;
  }
  return false;
}

markdownRenderer.core.ruler.after("inline", "copyable_strong", (state) => {
  const tokens = state.tokens;
  for (let i = 0; i < tokens.length; i += 1) {
    if (tokens[i].type !== "paragraph_open") continue;
    if (isInsideListItem(tokens, i)) continue;
    const inline = tokens[i + 1];
    const close = tokens[i + 2];
    if (!inline || inline.type !== "inline" || !close || close.type !== "paragraph_close") continue;

    const children = (inline.children || []) as MdInlineToken[];
    let start = 0;
    let end = children.length;
    while (start < end && isIgnorableInline(children[start])) start += 1;
    while (end > start && isIgnorableInline(children[end - 1])) end -= 1;

    if (children[start]?.type === "strong_open") {
      const span = findStrongSpan(children, start);
      if (span && span.closeIdx === end - 1) {
        const text = collectInlineText(span.inner).trim();
        if (text) {
          const htmlToken = new state.Token("html_block", "", 0);
          htmlToken.content = renderStrongCopyBlock(text);
          tokens.splice(i, 3, htmlToken);
          continue;
        }
      }
    }

    const nextChildren: MdInlineToken[] = [];
    let changed = false;
    for (let j = 0; j < children.length; j += 1) {
      if (children[j].type !== "strong_open") {
        nextChildren.push(children[j]);
        continue;
      }
      const span = findStrongSpan(children, j);
      if (!span) {
        nextChildren.push(children[j]);
        continue;
      }
      const text = collectInlineText(span.inner).trim();
      if (text.length >= INLINE_STRONG_COPY_MIN) {
        const html = new state.Token("html_inline", "", 0);
        html.content = renderStrongCopyInline(text);
        nextChildren.push(html as MdInlineToken);
        changed = true;
      } else {
        nextChildren.push(...children.slice(j, span.closeIdx + 1));
      }
      j = span.closeIdx;
    }
    if (changed) inline.children = nextChildren as typeof inline.children;
  }
});

/** Prefer the pasteable prompt section from assistant replies; fallback to full text. */
export function extractGeneratePrompt(content: string): string {
  const text = (content || "").trim();
  if (!text) return "";

  const fenced = text.match(/```(?:[\w-]*)\n([\s\S]*?)```/);
  if (fenced?.[1]?.trim()) {
    return fenced[1].trim();
  }

  const section = text.match(
    /##[^\n]*(?:可直接粘贴|最终提示词|提示词)[^\n]*\n([\s\S]*?)(?=\n##\s|\n---\s*\n|$)/i,
  );
  if (section?.[1]) {
    let body = section[1].trim();
    body = body.replace(/^\*\*[^*\n]+\*\*\s*\n?/, "").trim();
    const chunk = body.split(/\n---\n|\n{2,}(?=\*\*|##)/)[0]?.trim() || body;
    const cleaned = stripMarkdownDecorations(chunk);
    if (cleaned) return cleaned;
  }

  return stripMarkdownDecorations(text);
}

export function renderSimpleMarkdown(markdown: string): string {
  const source = (markdown || "").replace(/\r\n/g, "\n");
  if (!source.trim()) return "";
  return markdownRenderer.render(source);
}
