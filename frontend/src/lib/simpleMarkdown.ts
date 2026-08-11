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

  const lines = source.split("\n");
  const parts: string[] = [];
  let paragraph: string[] = [];
  let listItems: string[] = [];
  let orderedItems: string[] = [];
  let inCode = false;
  let codeLang = "";
  let codeLines: string[] = [];

  const flushParagraph = () => {
    if (!paragraph.length) return;
    parts.push(`<p>${formatInline(paragraph.join(" "))}</p>`);
    paragraph = [];
  };

  const flushList = () => {
    if (!listItems.length) return;
    parts.push(`<ul>${listItems.map((item) => `<li>${formatInline(item)}</li>`).join("")}</ul>`);
    listItems = [];
  };

  const flushOrdered = () => {
    if (!orderedItems.length) return;
    parts.push(`<ol>${orderedItems.map((item) => `<li>${formatInline(item)}</li>`).join("")}</ol>`);
    orderedItems = [];
  };

  const flushCode = () => {
    if (!inCode) return;
    parts.push(
      `<pre class="md-code"${codeLang ? ` data-lang="${escapeHtml(codeLang)}"` : ""}><code>${escapeHtml(codeLines.join("\n"))}</code></pre>`,
    );
    inCode = false;
    codeLang = "";
    codeLines = [];
  };

  for (const rawLine of lines) {
    const fence = /^```([\w-]*)\s*$/.exec(rawLine);
    if (fence) {
      flushParagraph();
      flushList();
      flushOrdered();
      if (inCode) {
        flushCode();
      } else {
        inCode = true;
        codeLang = fence[1] || "";
        codeLines = [];
      }
      continue;
    }

    if (inCode) {
      codeLines.push(rawLine);
      continue;
    }

    const line = rawLine.trimEnd();
    const trimmed = line.trim();
    if (!trimmed) {
      flushParagraph();
      flushList();
      flushOrdered();
      continue;
    }

    if (/^---+$/.test(trimmed)) {
      flushParagraph();
      flushList();
      flushOrdered();
      parts.push("<hr />");
      continue;
    }

    const heading = /^(#{1,3})\s+(.+)$/.exec(trimmed);
    if (heading) {
      flushParagraph();
      flushList();
      flushOrdered();
      const level = heading[1].length;
      parts.push(`<h${level}>${formatInline(heading[2])}</h${level}>`);
      continue;
    }

    if (/^>\s?/.test(trimmed)) {
      flushParagraph();
      flushList();
      flushOrdered();
      parts.push(`<blockquote>${formatInline(trimmed.replace(/^>\s?/, ""))}</blockquote>`);
      continue;
    }

    const unordered = /^[-*]\s+(.+)$/.exec(trimmed);
    if (unordered) {
      flushParagraph();
      flushOrdered();
      listItems.push(unordered[1]);
      continue;
    }

    const ordered = /^\d+\.\s+(.+)$/.exec(trimmed);
    if (ordered) {
      flushParagraph();
      flushList();
      orderedItems.push(ordered[1]);
      continue;
    }

    flushList();
    flushOrdered();
    paragraph.push(trimmed);
  }

  flushCode();
  flushParagraph();
  flushList();
  flushOrdered();
  return parts.join("");
}
