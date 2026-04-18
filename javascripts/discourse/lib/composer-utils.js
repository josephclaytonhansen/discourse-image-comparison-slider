export function updateWrapAttribute(type, wrapIndex, key, value) {
  const textarea = document.querySelector(".d-editor-input");
  if (!textarea) {
    return;
  }

  const text = textarea.value;
  const regex = new RegExp(`\\[wrap="?${type}"?([^\\]]*)\\]`, "g");
  let match;
  let count = 0;

  while ((match = regex.exec(text)) !== null) {
    if (count === wrapIndex) {
      const fullMatch = match[0];
      const attrsString = match[1];
      const newAttrs = replaceAttr(attrsString, key, value);
      const newTag = `[wrap=${type}${newAttrs}]`;

      textarea.focus();
      textarea.setSelectionRange(match.index, match.index + fullMatch.length);
      document.execCommand("insertText", false, newTag);
      return;
    }
    count++;
  }
}

export function replaceAttr(attrsString, key, value) {
  const attrRegex = new RegExp(`(\\s)${key}="[^"]*"`);

  if (value === null || value === undefined || String(value).trim() === "") {
    return attrsString.replace(attrRegex, "");
  }

  if (attrRegex.test(attrsString)) {
    return attrsString.replace(attrRegex, `$1${key}="${value}"`);
  }

  return `${attrsString} ${key}="${value}"`;
}
