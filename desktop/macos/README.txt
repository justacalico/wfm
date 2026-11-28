WFM for macOS

macOS may say wfm.app is "damaged" or refuse to open it because the
app is not signed with an Apple developer certificate.

To open it, either double-click remove-quarantine.command in this
folder, or open Terminal in this folder and run:

    xattr -cr wfm.app

Then open wfm.app normally.
