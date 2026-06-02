always use design tokens and not regular hex or values unless niche color or explicitly asked

icon folder is at apps/ios/Nook/Resources/Icons

New SVG icons must have an imageset created at apps/ios/Nook/Assets.xcassets/Icons/`<name>`.imageset/ with a Contents.json and the SVG copied in, otherwise they won't render at runtime.

always ask for icons if u dont have them, dont just make ones in the icons folder

The Xcode project (apps/ios/Nook.xcodeproj) is hand-maintained — `project.yml` is kept in sync but `xcodegen generate` rewrites the pbxproj, so only run it intentionally and verify the GoogleSignIn package and Info.plist (GIDClientID + Google URL scheme) survive.
