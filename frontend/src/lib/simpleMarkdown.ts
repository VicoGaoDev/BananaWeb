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
