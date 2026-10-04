import 'package:flutter/material.dart';

/// Shared with `MaterialApp.scaffoldMessengerKey` so snackbars survive route
/// changes and can be shown from a `BlocListener` anywhere.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Low-level snackbar. Feature code shows failures with `showFailureSnackBar`
/// and confirmations with [showInfoSnackBar] — never a raw `SnackBar`.
void showInfoSnackBar(
  BuildContext context,
  String message, {
  SnackBarAction? action,
}) {
  final messenger =
      ScaffoldMessenger.maybeOf(context) ??
      rootScaffoldMessengerKey.currentState;
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        behavior: SnackBarBehavior.floating,
      ),
    );
}
