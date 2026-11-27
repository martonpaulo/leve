// Link destinations and the version live in the HTML, so the page works without
// scripts. This keeps the copyright year current (the HTML carries a fallback),
// keeps short last lines out of running text, and fades sections in as they
// scroll into view.
document.querySelectorAll("[data-site-year]").forEach((element) => {
  element.textContent = new Date().getFullYear();
});

// Appearance (#420): the header's System / Light / Dark control. The inline
// script in <head> already applied a stored choice before the first paint; this
// shows the control, checks the stored option, stores each new choice, and makes
// the media that names the system appearance follow the choice: theme-color
// metas and <picture> sources whose media is exactly (prefers-color-scheme:
// dark) or (prefers-color-scheme: light) become "all" or "not all" for Light or
// Dark, and get their own media back for System.
const THEME_KEY = "theme";
const SCHEME_MEDIA = /^\(prefers-color-scheme: (light|dark)\)$/;
const readTheme = () => {
  try {
    const stored = localStorage.getItem(THEME_KEY);
    return stored === "light" || stored === "dark" ? stored : "system";
  } catch {
    return "system";
  }
};
const applyTheme = (theme) => {
  const root = document.documentElement;
  if (theme === "system") root.removeAttribute("data-theme");
  else root.setAttribute("data-theme", theme);
  const scheme = document.querySelector('meta[name="color-scheme"]');
  if (scheme) scheme.setAttribute("content", theme === "system" ? "light dark" : theme);
  document.querySelectorAll('meta[name="theme-color"][media], picture source[media]').forEach((element) => {
    if (!element.dataset.media) {
      if (!SCHEME_MEDIA.test(element.getAttribute("media"))) return;
      element.dataset.media = element.getAttribute("media");
    }
    const own = element.dataset.media;
    const media = theme === "system" ? own : own.match(SCHEME_MEDIA)[1] === theme ? "all" : "not all";
    element.setAttribute("media", media);
  });
};
const themeSwitch = document.querySelector("[data-theme-switch]");
if (themeSwitch) {
  const current = readTheme();
  applyTheme(current);
  themeSwitch.querySelectorAll('input[type="radio"]').forEach((radio) => {
    radio.checked = radio.value === current;
    radio.addEventListener("change", () => {
      if (!radio.checked) return;
      try {
        if (radio.value === "system") localStorage.removeItem(THEME_KEY);
        else localStorage.setItem(THEME_KEY, radio.value);
      } catch {
        // Storage can be blocked; the choice still applies to this page.
      }
      applyTheme(radio.value);
    });
  });
  themeSwitch.hidden = false;
}

// No line of running text ends with only one or two words: the last three words
// of each block are joined with non-breaking spaces, so they wrap together.
// CSS text-wrap: pretty only prevents a single word, and only in some browsers.
// Without JavaScript the text is unchanged. A block of fewer than six words, or
// whose last text is too short (it ends in a link, say), is left alone. The joined
// tail stays short enough for the narrowest column: three words when they fit in
// MAX_GLUED_CHARS, else two, else none.
const MIN_WORDS = 6;
const GLUED_WORDS = 3;
const MAX_GLUED_CHARS = 18;
document
  .querySelectorAll("main p:not(.command), main li, main td, main figcaption, main summary, footer p")
  .forEach((block) => {
    if (block.textContent.trim().split(/\s+/).length < MIN_WORDS) return;
    const walker = document.createTreeWalker(block, NodeFilter.SHOW_TEXT);
    let last = null;
    while (walker.nextNode()) {
      if (walker.currentNode.textContent.trim()) last = walker.currentNode;
    }
    if (!last) return;
    // the source's line breaks and indentation are ordinary spaces once rendered
    const lead = /^\s/.test(last.textContent) ? " " : "";
    const words = last.textContent.trim().split(/\s+/);
    let count = Math.min(GLUED_WORDS, words.length);
    while (count > 1 && words.slice(-count).join(" ").length > MAX_GLUED_CHARS) count -= 1;
    if (count < 2) return;
    const glued = words.splice(-count).join("\u00a0");
    const trail = /\s$/.test(last.textContent) ? " " : "";
    last.textContent = lead + [...words, glued].join(" ") + trail;
  });

// A command marked data-copy copies itself on click (or Return/Space): its copy
// icon turns into "Copied!" for a moment and the command stays in place. Without
// JavaScript it is plain text to select.
document.querySelectorAll("[data-copy]").forEach((command) => {
  const text = command.querySelector("code").textContent;
  const status = command.querySelector("[aria-live]");
  command.setAttribute("role", "button");
  command.setAttribute("tabindex", "0");
  command.setAttribute("aria-label", `Copy the command ${text}`);
  command.classList.add("is-copyable");
  let timer;
  const copy = async () => {
    try {
      await navigator.clipboard.writeText(text);
      command.classList.add("is-copied");
      status.textContent = "Copied";
    } catch {
      status.textContent = "Could not copy; select the command instead";
    }
    clearTimeout(timer);
    timer = setTimeout(() => {
      command.classList.remove("is-copied");
      status.textContent = "";
    }, 1800);
  };
  command.addEventListener("click", copy);
  command.addEventListener("keydown", (event) => {
    if (event.key === "Enter" || event.key === " ") { event.preventDefault(); copy(); }
  });
});

// On the home page, the header link of the section in view is marked as the
// current location (Features, Download), like the current page on other pages.
const sectionLinks = [...document.querySelectorAll('.site-header nav a[href^="#"]')]
  .map((link) => [link, document.querySelector(link.getAttribute("href"))])
  .filter(([, section]) => section);
if ("IntersectionObserver" in window && sectionLinks.length) {
  const spy = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      const link = sectionLinks.find(([, section]) => section === entry.target)[0];
      if (entry.isIntersecting) link.setAttribute("aria-current", "location");
      else link.removeAttribute("aria-current");
    });
  }, { rootMargin: "-40% 0px -55% 0px" });
  sectionLinks.forEach(([, section]) => spy.observe(section));
}

// The hidden starting state exists only under html.js with motion allowed (see
// styles/main.css), so without JavaScript or with Reduce Motion every section is
// simply visible.
const reveals = document.querySelectorAll(".reveal");
if ("IntersectionObserver" in window && reveals.length) {
  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add("is-visible");
      observer.unobserve(entry.target);
    });
  }, { rootMargin: "0px 0px -8% 0px", threshold: 0.08 });
  reveals.forEach((element) => observer.observe(element));
} else {
  reveals.forEach((element) => element.classList.add("is-visible"));
}
