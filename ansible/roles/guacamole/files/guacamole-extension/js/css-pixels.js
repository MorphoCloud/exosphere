/*
 * Size the remote desktop in CSS pixels, not physical screen pixels.
 *
 * Guacamole requests a remote resolution of (window size x devicePixelRatio).
 * On a scaled display (e.g. Windows at 150%) the desktop is then 1.5x larger
 * than the browser window and drawn at 96 DPI; VNC cannot pass the DPI on, so
 * all text shrinks by that factor. With devicePixelRatio pinned to 1 the
 * desktop matches the window's logical size and the browser scales it up, so
 * text appears at the same size as the local OS.
 */
(function () {
  try {
    Object.defineProperty(window, "devicePixelRatio", {
      configurable: true,
      get: function () {
        return 1;
      },
    });
  } catch (e) {
    // Leave Guacamole's default (physical-pixel) sizing in place.
  }
})();
