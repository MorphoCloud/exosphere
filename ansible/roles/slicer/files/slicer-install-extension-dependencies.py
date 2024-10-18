import slicer


def installModulePythonDependencies():
    for moduleName in [
        "ALPACA",
        "MorphoSourceImport",
    ]:
        slicer.util.selectModule(moduleName)
        return

    # ImageStacks
    slicer.util.pip_install("pynrrd")

    # Animator
    slicer.util.pip_install("easing-functions")

    # "GPA":
    slicer.util.pip_install("pandas")


if __name__ == "__main__":
    installModulePythonDependencies()
    slicer.util.exit()
