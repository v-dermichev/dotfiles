// Receive external link requests
// Try native messaging first (Linux — opens in system default browser)
// Fallback: open in a new browser window (cross-platform)
chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg.type === 'open-external') {
    console.log('[open-external] Background received:', msg.url);
    chrome.runtime.sendNativeMessage(
      'com.hyprland.open_external',
      { url: msg.url },
      (response) => {
        if (chrome.runtime.lastError) {
          console.log('[open-external] Native host unavailable, using fallback');
          chrome.windows.create({ url: msg.url, type: 'normal' });
        }
      }
    );
    return true;
  }
});
