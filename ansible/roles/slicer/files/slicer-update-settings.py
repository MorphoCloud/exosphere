import slicer


def updateSettings():
    slicer.app.defaultScenePath = "/media/volume/My-Data"


if __name__ == "__main__":
    updateSettings()
    slicer.util.exit()
