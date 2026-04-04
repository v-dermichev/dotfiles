// Intercept ALL clicks and check if they navigate externally
// Handles SPA apps that use JS navigation instead of <a href>

// Block custom protocol handlers (the "wants to open this application" popup)
if (navigator.registerProtocolHandler) {
  navigator.registerProtocolHandler = () => {};
}

// Monitor window.open calls
const originalOpen = window.open;
window.open = function(url, ...args) {
  if (url && !url.startsWith(window.location.origin) && !url.startsWith('/')) {
    console.log('[open-external] Intercepted window.open:', url);
    chrome.runtime.sendMessage({ type: 'open-external', url });
    return null;
  }
  return originalOpen.call(this, url, ...args);
};

// Block custom protocol navigations (yaremessenger://, etc.)
const originalAssign = window.location.assign;
if (originalAssign) {
  window.location.assign = function(url) {
    if (url && !url.startsWith('http') && !url.startsWith('/')) {
      console.log('[open-external] Blocked protocol navigation:', url);
      return;
    }
    return originalAssign.call(this, url);
  };
}

// Monitor clicks on any element with href or data attributes
document.addEventListener('click', (e) => {
  // Walk up the DOM tree to find a link
  let el = e.target;
  for (let i = 0; i < 10 && el; i++) {
    const href = el.getAttribute && (el.getAttribute('href') || el.dataset?.href || el.dataset?.url);
    if (href) {
      try {
        // Block custom protocol links
        if (href.match(/^[a-z]+:/) && !href.startsWith('http') && !href.startsWith('mailto:')) {
          console.log('[open-external] Blocked protocol link:', href);
          e.preventDefault();
          e.stopPropagation();
          return;
        }
        const url = new URL(href, window.location.origin);
        if (url.origin !== window.location.origin) {
          console.log('[open-external] Intercepted click:', url.href);
          e.preventDefault();
          e.stopPropagation();
          chrome.runtime.sendMessage({ type: 'open-external', url: url.href });
          return;
        }
      } catch {}
    }
    el = el.parentElement;
  }
}, true);

// Block PWA install prompts and external app launch dialogs
window.addEventListener('beforeinstallprompt', (e) => {
  e.preventDefault();
  console.log('[open-external] Blocked install prompt');
});

// Block external protocol launches via iframe trick
const observer = new MutationObserver((mutations) => {
  for (const mutation of mutations) {
    for (const node of mutation.addedNodes) {
      if (node.tagName === 'IFRAME' && node.src && !node.src.startsWith('http') && !node.src.startsWith('about:')) {
        console.log('[open-external] Blocked iframe protocol:', node.src);
        node.remove();
      }
    }
  }
});
observer.observe(document.documentElement, { childList: true, subtree: true });

console.log('[open-external] Content script loaded for:', window.location.href);
