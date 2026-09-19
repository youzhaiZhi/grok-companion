import 'package:flutter/material.dart';

Path parseSvgPath(String d) {
  final path = Path();
  final tokens = RegExp(r'[MLCQZmlcqz]|-?\d*\.?\d+(?:e[-+]?\d+)?')
      .allMatches(d)
      .map((m) => m.group(0)!)
      .toList();
  int i = 0;
  String cmd = '';
  double rd() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    if (RegExp(r'[a-zA-Z]').hasMatch(tokens[i])) {
      cmd = tokens[i++].toUpperCase();
    }
    switch (cmd) {
      case 'M':
        path.moveTo(rd(), rd());
        cmd = 'L';
        break;
      case 'L':
        path.lineTo(rd(), rd());
        break;
      case 'Q':
        final x1 = rd(), y1 = rd(), x = rd(), y = rd();
        path.quadraticBezierTo(x1, y1, x, y);
        break;
      case 'C':
        final x1 = rd(), y1 = rd();
        final x2 = rd(), y2 = rd();
        final x = rd(), y = rd();
        path.cubicTo(x1, y1, x2, y2, x, y);
        break;
      case 'Z':
        path.close();
        break;
      default:
        i++;
    }
  }
  return path;
}
