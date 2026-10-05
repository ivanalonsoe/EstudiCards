/// The three layouts of the app, chosen by window width (SPEC §3.3).
enum FormFactor {
  /// Below 600 dp: stack navigation, menu in a side drawer.
  mobile,

  /// 600–839 dp: like mobile, with larger margins.
  tablet,

  /// 840 dp and wider: fixed sidebar on the left.
  desktop;

  static const double tabletMinWidth = 600;
  static const double desktopMinWidth = 840;

  static FormFactor fromWidth(double width) {
    if (width >= desktopMinWidth) return desktop;
    if (width >= tabletMinWidth) return tablet;
    return mobile;
  }
}
