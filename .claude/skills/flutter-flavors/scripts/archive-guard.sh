#!/bin/sh
# "Archive Only Production" — a Run Script build phase for a Flutter app's
# Runner target. It fails any ARCHIVE (Xcode Product > Archive, or
# `flutter build ipa`) that is not the production release, so a dev entry
# point, dev flavour or debug engine can never reach TestFlight / the App Store.
#
# Install it with the helper (preferred — it escapes, names and orders the phase):
#   python3 <skill>/scripts/pbxproj_flavors.py add-guard \
#       --configuration Release-production --entry main_prod.dart --flavor production
# or by hand in Xcode: Runner target > Build Phases > + > New Run Script Phase,
# name it "Archive Only Production", drag it to the TOP, untick "Based on
# dependency analysis", paste everything below the marker line.
#
# Runs on every build but acts only when ACTION=install (archives). Ordinary
# `flutter run` / Xcode Run builds are untouched. Note: it also blocks
# `flutter build ipa --flavor <dev>` — intended when TestFlight carries the
# production app only; loosen the condition if a dev app is distributed too.
# ----- phase script below -----
PROD_CONFIGURATION="Release-production"
PROD_ENTRY="main_prod.dart"
PROD_FLAVOR="production"

# ACTION is "install" only for Archive (Xcode or flutter build ipa).
if [ "$ACTION" = "install" ]; then
  if [ "$CONFIGURATION" != "$PROD_CONFIGURATION" ] || [ "${FLUTTER_TARGET##*/}" != "$PROD_ENTRY" ] || [ "$FLAVOR" != "$PROD_FLAVOR" ]; then
    echo "error: Only the production release can be archived (got $CONFIGURATION, $FLUTTER_TARGET, flavor $FLAVOR). Archive with the production scheme, or run: flutter build ipa --flavor $PROD_FLAVOR -t lib/$PROD_ENTRY"
    exit 1
  fi
fi
