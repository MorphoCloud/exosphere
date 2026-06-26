import os

import slicer


def installModulePythonDependencies():
    # Slicer 5.12 SlicerMorph modules self-install their Python deps via an
    # INTERACTIVE prompt (slicer.packaging.pip_ensure). That dialog can't be
    # answered during headless setup, so it silently DEFERS -- nothing gets
    # installed and the user hits "Install Python Packages?" on first use.
    # Pre-install each module's pinned requirements NON-interactively here, by
    # reading its requirements_<Module>.txt and pip-installing the specs directly.
    scriptedModulesDir = os.path.dirname(slicer.util.modulePath("MorphoSourceImport"))
    for moduleName in ["ALPACA", "MorphoSourceImport", "ImageStacks", "GPA"]:
        requirementsFile = os.path.join(
            scriptedModulesDir, "Resources", f"requirements_{moduleName}.txt"
        )
        if not os.path.exists(requirementsFile):
            raise RuntimeError(f"Missing requirements file: {requirementsFile}")
        with open(requirementsFile) as f:
            specs = [
                line.strip()
                for line in f
                if line.strip() and not line.lstrip().startswith("#")
            ]
        if specs:
            slicer.util.pip_install(specs)

    # Animator (separate extension; no SlicerMorph requirements file)
    slicer.util.pip_install("easing-functions")

    # Verify the dependencies are actually importable, so setup FAILS loudly
    # instead of reporting success with packages missing (a silent pip_ensure
    # deferral leaves no exception for the failsafe to catch otherwise).
    for importName in ["pandas", "morphosource", "sklearn"]:
        __import__(importName)


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
