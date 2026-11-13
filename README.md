# StartLine

StartLine is a quiet countdown app for iPhone. Pick a nearby start time and count down to it, or run a Pomodoro focus interval followed by an optional five-minute break. A visual ring is the main display and control. There are no alarms, sounds, notifications, or accounts, and no interval starts on its own.

[Download on the App Store](https://apps.apple.com/app/id6785157211)

## Requirements

- Xcode 26 or later
- iOS 17.6 or later (iPhone)
- No third-party dependencies

## Building

1. Clone the repository and open `StartLine.xcodeproj` in Xcode.
2. To build for the Simulator, choose the `StartLine` scheme and an iPhone Simulator, then build and run. No signing setup is needed.
3. To run on a device, set your Apple Developer Team ID:

   ```sh
   cp Config/Developer.xcconfig.example Config/Developer.xcconfig
   ```

   Then replace `YOUR_TEAM_ID` in `Config/Developer.xcconfig` with your Team ID. `Config/Base.xcconfig` includes this file when it exists, and Git ignores it.

The bundle identifier and the in-app purchase product ID belong to the published app. To sign and run your own build, change the bundle identifier to one you own. The tip purchase only loads products that exist in App Store Connect for that identifier, or the local StoreKit configuration described below.

## Automation scheme

The `StartLine-Automation` scheme builds the `Automation` configuration, which defines the `STARTLINE_AUTOMATION` compilation condition. Only in that configuration does the app read launch arguments that shorten countdowns and simulate tip-purchase outcomes, so UI tests do not have to wait for real time or reach the App Store. The Release configuration does not compile this code.

Run the UI tests with this scheme. It uses `StartLineUITests/StartLine.storekit` as a local StoreKit configuration. The supported launch arguments are:

```text
-startline-scheduled-seconds <1-3600>
-startline-pomodoro-seconds <1-3600>
-startline-break-seconds <1-3600>
-startline-tip-test-price <display price>
-startline-tip-test-result success | pending | failure | cancelled
-startline-tip-test-unavailable
-startline-tip-test-unavailable-once
```

Unit tests (`StartLineTests`) run with either scheme.

The product specification, in Japanese, is in [`docs/StartLine-specification.md`](docs/StartLine-specification.md).

## Privacy

StartLine collects no personal data and does no tracking. It has no server of its own. The only network use is Apple's StoreKit, which loads and purchases the optional tip. The only setting stored on the device is the Pomodoro duration. The full privacy policy is at <https://tkdmix.com/apps/startline/support/#privacy>.

## Support

For bug reports and feedback, email [support@tkdmix.com](mailto:support@tkdmix.com).

Issues and pull requests are not accepted.

## License

The source code is released under the [MIT License](LICENSE). The app name (StartLine) and the app icon are not covered by the MIT License. All rights reserved.
