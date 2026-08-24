fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android build_aab

```sh
[bundle exec] fastlane android build_aab
```

Build the signed release AAB (requires keystore.properties).

### android internal

```sh
[bundle exec] fastlane android internal
```

Build and upload the release AAB to the Internal testing track (as draft).

### android closed

```sh
[bundle exec] fastlane android closed
```

Build and upload the release AAB to the Closed testing (alpha) track as a draft.

### android promote_production

```sh
[bundle exec] fastlane android promote_production
```

Promote the current Internal testing release to Production.

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
