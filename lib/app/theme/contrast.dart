import 'dart:ui';

/// WCAG contrast ratio between two colours, from 1 (identical) to 21 (black
/// on white). Normal text needs at least 4.5 to meet level AA.
double contrastRatio(Color a, Color b) {
  // Relative luminance: how bright each colour looks, from 0 to 1.
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}
