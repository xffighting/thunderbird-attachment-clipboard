/*
 * AttachClip for Thunderbird — menus.js
 * --------------------------------------
 * Registers the two context menu items and dispatches click events to
 * background.js. We intentionally keep the menus module thin; orchestration
 * lives in background.js so unit-test harnesses can swap implementations.
 */

(function () {
  "use strict";

  const MENU_IDS = Object.freeze({
    SINGLE: "attachclip-copy-single",
    ALL: "attachclip-copy-all",
  });

  const TITLES = Object.freeze({
    [MENU_IDS.SINGLE]: "Copy Attachment as File",
    [MENU_IDS.ALL]: "Copy All Attachments as Files",
  });

  const CONTEXTS = Object.freeze({
    [MENU_IDS.SINGLE]: ["message_attachments"],
    [MENU_IDS.ALL]: ["all_message_attachments"],
  });

  let registered = false;

  async function register() {
    if (registered) return;
    try {
      // Wipe any leftovers from a previous extension install
      await messenger.menus.removeAll();

      await messenger.menus.create({
        id: MENU_IDS.SINGLE,
        title: TITLES[MENU_IDS.SINGLE],
        contexts: CONTEXTS[MENU_IDS.SINGLE],
      });

      await messenger.menus.create({
        id: MENU_IDS.ALL,
        title: TITLES[MENU_IDS.ALL],
        contexts: CONTEXTS[MENU_IDS.ALL],
      });

      registered = true;
      console.debug("[AttachClip] context menus registered");
    } catch (err) {
      console.error("[AttachClip] menus.register failed:", err);
    }
  }

  function wireClickHandler() {
    messenger.menus.onClicked.addListener(async (info, tab) => {
      const mode = info.menuItemId === MENU_IDS.ALL ? "all" : "single";
      const singlePart = mode === "single" ? info.attachmentPartName : null;
      try {
        // Defer to background.js for orchestration.  Using a runtime message
        // keeps this file from importing nativeClient / attachmentReader
        // directly and makes the call site obvious in DevTools.
        await browser.runtime.sendMessage({
          kind: "attachclip-copy-request",
          mode,
          tabId: tab ? tab.id : null,
          info,
          singlePart,
        });
      } catch (err) {
        console.error("[AttachClip] menu dispatch failed:", err);
      }
    });
  }

  // Register and wire on every event-page wakeup (install/startup/update).
  register();
  wireClickHandler();
})();
