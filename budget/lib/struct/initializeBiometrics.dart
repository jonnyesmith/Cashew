import 'package:animations/animations.dart';
import 'package:budget/functions.dart';
import 'package:budget/main.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/breathingAnimation.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

Future<bool?> checkBiometrics({
  bool checkAlways = false,
}) async {
  try {
    final LocalAuthentication auth = LocalAuthentication();
    biometricsAvailable = kIsWeb == false && await auth.canCheckBiometrics ||
        await auth.isDeviceSupported();

    if (kIsWeb) return true;

    final bool requireAuth =
        checkAlways || appStateSettings["requireAuth"] == true;
    if (requireAuth == false) return true;

    await auth.stopAuthentication();

    if (biometricsAvailable == false) {
      return await auth.authenticate(
        localizedReason: "verify-identity".tr(),
        options: const AuthenticationOptions(biometricOnly: false),
      );
    } else if (biometricsAvailable == true) {
      return await auth.authenticate(
        localizedReason: "verify-identity".tr(),
        options: const AuthenticationOptions(biometricOnly: true),
      );
    }
    return null;
  } catch (e) {
    return null;
  }
}

class InitializeBiometrics extends StatefulWidget {
  final Widget child;
  const InitializeBiometrics({required this.child, super.key});

  @override
  State<InitializeBiometrics> createState() => _InitializeBiometricsState();
}

class _InitializeBiometricsState extends State<InitializeBiometrics> {
  bool? authenticated;
  bool hasErrored = false;
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      _biometricCheck();
    });
  }

  _biometricCheck() async {
    bool? result = await checkBiometrics();
    setState(() {
      authenticated = result;
    });
    if (result == null) {
      // Only allow bypass if importing database backup
      if (isDatabaseImportedOnThisSession) {
        _biometricErrorPopup();
        setState(() {
          authenticated = true;
        });
      } else {
        setState(() {
          hasErrored = true;
        });
      }
    }
  }

  _biometricErrorPopup() {
    // Wait so that we get a context on the navigatorKey
    // Since Initialize biometrics does not have access to Material navigator in the widget tree
    // because we want to keep the app fully locked
    Future.delayed(Duration(milliseconds: 500), () {
      if (navigatorKey.currentContext == null) return;
      openPopup(
        navigatorKey.currentContext!,
        barrierDismissible: false,
        icon: appStateSettings["outlinedIcons"]
            ? Icons.warning_outlined
            : Icons.warning_rounded,
        title: "biometrics-error".tr(),
        description: "biometrics-error-description".tr(),
        onSubmitLabel: "ok".tr(),
        onSubmit: () {
          updateSettings("requireAuth", false, updateGlobalState: false);
          Navigator.pop(navigatorKey.currentContext!);
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (appStateSettings["requireAuth"] == false) {
      return widget.child;
    }
    Widget child = Scaffold(
      resizeToAvoidBottomInset: false,
      body: Tappable(
        onTap: () async {
          setState(() {
            authenticated = null;
          });
          _biometricCheck();
        },
        child: Column(
          key: ValueKey(0),
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BreathingWidget(
              child: Center(
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: 500),
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return FadeScaleTransition(
                        animation: animation, child: child);
                  },
                  child: authenticated == false || hasErrored
                      ? Icon(
                          Icons.lock,
                          size: 50,
                          color: Theme.of(context).colorScheme.secondary,
                        )
                      : SizedBox.shrink(),
                ),
              ),
            ),
            if (hasErrored)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                child: TextFont(
                  text: "biometrics-error-description".tr() +
                      "\n" +
                      "please-check-your-system-settings".tr(),
                  textAlign: TextAlign.center,
                  maxLines: 5,
                  fontSize: 16,
                ),
              ),
          ],
        ),
      ),
    );
    if (authenticated == true) {
      child = SizedBox(key: ValueKey(1), child: widget.child);
    }
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 500),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeScaleTransition(animation: animation, child: child);
      },
      child: child,
    );
  }
}
