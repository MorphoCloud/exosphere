import slicer


def installModulePythonDependencies():
    for moduleName in [
        "ALPACA",
    ]:
        slicer.util.selectModule(moduleName)

    # MorphoSourceImport
    slicer.util.pip_install("pandas")
    from MorphoSourceImport import morphosourceVersion
    slicer.util.pip_install(f"morphosource=={morphosourceVersion}")

    # ImageStacks
    slicer.util.pip_install("pynrrd")

    # Animator
    slicer.util.pip_install("easing-functions")

    # "GPA":
    slicer.util.pip_install("pandas")


if __name__ == "__main__":
    installModulePythonDependencies()
    slicer.util.exit()
