// Receive external link requests and forward to native messaging host
chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg.type === 'open-external') {
    console.log('[open-external] Background received:', msg.url);
    try {
      chrome.runtime.sendNativeMessage(
        'com.hyprland.open_external',
        { url: msg.url },
        (response) => {
          if (chrome.runtime.lastError) {
            console.error('[open-external] Native error:', chrome.runtime.lastError.message);
            // Fallback: open in new tab (will go to default profile via desktop file)
            chrome.tabs.create({ url: msg.url });
          } else {
            console.log('[open-external] Native response:', response);
          }
        }
      );
    } catch (e) {
      console.error('[open-external] Exception:', e);
      chrome.tabs.create({ url: msg.url });
    }
    return true;
  }
});
