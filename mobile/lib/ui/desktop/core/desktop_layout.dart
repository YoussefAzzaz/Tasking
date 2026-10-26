import 'package:flutter/material.dart';

/// Layout dimension constants for the Axis desktop command center.
abstract final class DesktopLayout {
  static const double sidebarWidth = 270.0;
  static const double titlebarHeight = 44.0;
  static const double panelPadding = 20.0;
  static const double cardRadius = 10.0;
  static const double cardPadding = 16.0;
  static const double sectionSpacing = 20.0;
  static const double columnGap = 1.0; // hairline divider
  static const double innerPadding = 12.0;
  static const double badgeRadius = 6.0;

  static const BorderRadius borderRadiusCard = BorderRadius.all(Radius.circular(cardRadius));
  static const BorderRadius borderRadiusBadge = BorderRadius.all(Radius.circular(badgeRadius));
}
