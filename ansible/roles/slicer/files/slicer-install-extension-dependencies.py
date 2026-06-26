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
            # pip_install accepts a list of specs (Slicer 5.6+) and installs
            # them in a single call; the list form is intentional.
            slicer.util.pip_install(specs)

    # Animator (separate extension; no SlicerMorph requirements file)
    slicer.util.pip_install("easing-functions")

    # Verify the dependencies are actually importable, so setup FAILS loudly
    # instead of reporting success with packages missing (a silent pip_ensure
    # deferral leaves no exception for the failsafe to catch otherwise). These
    # are representative imports provided by the requirements files installed
    # above (pandas/sklearn via the SlicerMorph modules, morphosource via
    # MorphoSourceImport); keep this list in sync if those requirements change.
    for importName in ["pandas", "morphosource", "sklearn"]:
        __import__(importName)


if __name__ == "__main__":
    # Slicer's process exit code is unreliable from --python-script; the caller detects
    # success by grepping for the marker printed below. A failure prints a traceback
    # and NO marker. exit() is best-effort.
    try:
        installModulePythonDependencies()
    except Exception:
        import traceback

        traceback.print_exc()
        slicer.util.exit(1)
    else:
        print("SLICER_DEPENDENCIES_INSTALL_OK", flush=True)
        slicer.util.exit(0)
