always use design tokens and not regular hex or values unless niche color or explicitly asked

icon folder is at apps/ios/Nook/Resources/Icons

New SVG icons must have an imageset created at apps/ios/Nook/Assets.xcassets/Icons/<name>.imageset/ with a Contents.json and the SVG copied in, otherwise they won't render at runtime.
