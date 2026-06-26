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
    # Always exit the (GUI) Slicer process: on failure, surface a non-zero exit
    # immediately instead of leaving Slicer open and hanging setup until the
    # workflow's 20-minute timeout.
    try:
        installExtension(args.extension)
        bookmarkExtension(args.extension)
    except Exception:
        import traceback

        traceback.print_exc()
        slicer.util.exit(1)
    slicer.util.exit(0)
