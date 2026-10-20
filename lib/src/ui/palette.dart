import 'package:flutter/material.dart';

const frostNight = Color(0xFF0A1A3A);
const frostDeep = Color(0xFF050C22);
const frostPanel = Color(0xCC0B1E46);
const iceBlue = Color(0xFF7FE3FF);
const iceWhite = Color(0xFFEFFBFF);
const iceEdge = Color(0xFFB9ECFF);
const gold = Color(0xFFFFD45A);
const goldLight = Color(0xFFFFF4B8);
const goldDeep = Color(0xFFD9850F);
const ember = Color(0xFFFF6B3D);
const ruby = Color(0xFFE5304A);
const rubyDeep = Color(0xFF8E0F24);
const emerald = Color(0xFF2FD67B);
const emeraldDeep = Color(0xFF0B7A3E);
const violet = Color(0xFF8E5BFF);
const violetDeep = Color(0xFF3B1A8A);
const ink = Color(0xFF1A0F05);

const goldGradient = [goldLight, gold, goldDeep];
const iceGradient = [Colors.white, iceEdge, Color(0xFF3FA9F5)];

TextStyle display(double size, {Color color = Colors.white, double height = 1.0}) {
  return TextStyle(
    fontSize: size,
    color: color,
    height: height,
    letterSpacing: size * 0.02,
    shadows: const [
      Shadow(color: Color(0xAA000000), blurRadius: 6, offset: Offset(0, 2)),
    ],
  );
}

TextStyle body(double size, {Color color = Colors.white, FontWeight weight = FontWeight.w600}) {
  return TextStyle(
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: 1.25,
    fontFamilyFallback: const [],
  );
}
