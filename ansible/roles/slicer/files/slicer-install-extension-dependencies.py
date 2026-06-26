import slicer


def installModulePythonDependencies():
    for moduleName in [
        "ALPACA",
    ]:
        slicer.util.selectModule(moduleName)

    # MorphoSourceImport — Slicer 5.12 removed the `morphosourceVersion` symbol;
    # the module now self-installs its pinned deps (pandas + morphosource) from
    # Resources/requirements_MorphoSourceImport.txt via slicer.packaging.
    import MorphoSourceImport
    MorphoSourceImport._ensure_morphosource_dependencies()

    # ImageStacks
    slicer.util.pip_install("pynrrd")

    # Animator
    slicer.util.pip_install("easing-functions")

    # "GPA":
    slicer.util.pip_install("pandas")


if __name__ == "__main__":
    # Always exit the (GUI) Slicer process: on failure, surface a non-zero exit
    # immediately instead of leaving Slicer open and hanging setup until the
    # workflow's 20-minute timeout.
    try:
        installModulePythonDependencies()
    except Exception:
        import traceback

        traceback.print_exc()
        slicer.util.exit(1)
    slicer.util.exit(0)
