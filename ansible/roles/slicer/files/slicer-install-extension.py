import argparse

import slicer


def installExtension(extensionName):
    em = slicer.app.extensionsManagerModel()
    em.interactive = False  # prevent display of popups
    restart = False

    if not em.installExtensionFromServer(extensionName, restart):
        raise ValueError(f"Failed to install {extensionName} extension")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('extension', help='Name of the extension (and its dependencies) to install')
    args = parser.parse_args()
    installExtension(args.extension)
    slicer.util.exit()

