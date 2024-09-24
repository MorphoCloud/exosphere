import slicer


def updateSettings():
    slicer.app.defaultScenePath = "/media/volume/MyData"


if __name__ == "__main__":
    updateSettings()
    slicer.util.exit()
