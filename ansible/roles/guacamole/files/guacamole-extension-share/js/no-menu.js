/*
 * MorphoCloud share mode: no Guacamole side panel, no file drops.
 *
 * Files move through the MorphoCloud portal's file browser, so the panel
 * (Ctrl+Alt+Shift, or a swipe from the left on touch screens) is kept closed.
 * Guacamole stops all keyboard input while the panel is open, so hiding it
 * with CSS would leave an invisible panel and a dead keyboard; instead the
 * client page's menu state is reset to closed as soon as anything opens it.
 * Installed only when storage_mode=share (ansible/roles/guacamole).
 */
(function () {
  try {
    angular.module("client").config(["$provide", function ($provide) {
      $provide.decorator("$controller", ["$delegate", function ($delegate) {
        function keepClosed(locals) {
          var scope = locals && locals.$scope;
          if (!scope) return;
          scope.$watch("menu.shown", function (shown) {
            if (shown) scope.menu.shown = false;
          });
        }
        return function (expression, locals, later) {
          var result = $delegate.apply(this, arguments);
          if (expression !== "clientController") return result;
          if (later && typeof result === "function") {
            // Instantiated later (e.g. by ng-controller): keep the returned
            // function's properties, such as .instance.
            var instantiate = result;
            var wrapped = function () {
              var instance = instantiate.apply(this, arguments);
              keepClosed(locals);
              return instance;
            };
            Object.keys(instantiate).forEach(function (k) { wrapped[k] = instantiate[k]; });
            return wrapped;
          }
          keepClosed(locals);
          return result;
        };
      }]);
    }]);
  } catch (e) {
    // Leave Guacamole's default behaviour in place.
  }

  // Files dropped on the desktop would start an upload that cannot finish
  // (file transfer is off in share mode): ignore them.
  ["dragover", "drop"].forEach(function (type) {
    window.addEventListener(type, function (e) {
      if (e.dataTransfer && Array.prototype.indexOf.call(e.dataTransfer.types || [], "Files") >= 0) {
        e.preventDefault();
        e.stopImmediatePropagation();
      }
    }, true);
  });
})();
