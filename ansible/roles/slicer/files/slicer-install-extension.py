import argparse

import slicer


def installExtension(extensionName):
    em = slicer.app.extensionsManagerModel()
    em.interactive = False  # prevent display of popups
    restart = False

    if not em.installExtensionFromServer(extensionName, restart):
        raise ValueError(f"Failed to install {extensionName} extension")


def bookmarkExtension(extensionName):
    em = slicer.app.extensionsManagerModel()
    em.setExtensionBookmarked(extensionName, True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('extension', help='Name of the extension (and its dependencies) to install')
    args = parser.parse_args()
    # Slicer's process exit code is unreliable from --python-script (slicer.util.exit
    # does not stop immediately, and a later call overwrites the code), so a failed
    # run can still exit 0. The caller detects success by grepping for the marker
    # printed below; a failure prints a traceback and NO marker. exit() is best-effort.
    try:
        installExtension(args.extension)
        bookmarkExtension(args.extension)
    except Exception:
        import traceback

        traceback.print_exc()
        slicer.util.exit(1)
    else:
        print("SLICER_EXTENSION_INSTALL_OK", flush=True)
        slicer.util.exit(0)
