# Settings design checkpoint

This checkpoint preserves the current native settings previews and isolated testing-addon builder before further redesign work.

`settings-concept.png` illustrates the proposed Unit Frames, Action Bars, and Quality of Life layouts. It is a visual proposal; its artwork and layout are not implemented in the addon. Future implementation should use FlareUI's actual assets.

The native minimap module was restored from the user's live FlareUI installation. Experimental replacement masks were removed. Other preview and settings improvements remain included.

Build an isolated installable addon with `node tools/build-testing.js <output-parent>`. The generated folder and TOC are named `FlareUI_Testing`. Personal saved variables and local installation backups are not part of this checkpoint.
