import 'dart:convert';

import 'mathx.dart';

class GrokShape {
  GrokShape({
    required this.label,
    required this.path,
    required this.face,
    required this.radius,
    required this.tiltScale,
    required this.top,
    required this.bottom,
  });

  final String label;
  final String path;
  final Face face;
  final double radius;
  final double tiltScale;
  final double top;
  final double bottom;
}

class GrokColor {
  GrokColor({required this.light, required this.dark});

  final String light;
  final String dark;
}

class ViewBox {
  ViewBox({
    required this.minX,
    required this.minY,
    required this.width,
    required this.height,
  });

  final double minX;
  final double minY;
  final double width;
  final double height;
}

class GrokGeometry {
  GrokGeometry({
    required this.re,
    required this.g9e,
    required this.vjt,
    required this.viewBox,
    required this.blobPath,
    required this.starPath,
    required this.starColor,
    required this.palette,
    required this.eyes,
    required this.shapes,
    required this.solids,
  });

  final double re;
  final double g9e;
  final double vjt;
  final ViewBox viewBox;
  final String blobPath;
  final String starPath;
  final String starColor;
  final Map<String, GrokColor> palette;

  /// 25 眼型，每型 2 个多边形（左/右），每多边形 48 个点。
  final List<List<List<Pt>>> eyes;
  final Map<String, GrokShape> shapes;
  final Map<String, List<List<double>>> solids;

  factory GrokGeometry.fromJsonString(String source) {
    final j = json.decode(source) as Map<String, dynamic>;

    final paletteRaw = j['palette'] as Map<String, dynamic>;
    final palette = <String, GrokColor>{
      for (final e in paletteRaw.entries)
        e.key: GrokColor(
          light: (e.value as Map<String, dynamic>)['light'] as String,
          dark: (e.value as Map<String, dynamic>)['dark'] as String,
        ),
    };

    final eyesRaw = j['eyes'] as List<dynamic>;
    final eyes = <List<List<Pt>>>[];
    for (final morph in eyesRaw) {
      final polys = <List<Pt>>[];
      for (final poly in (morph as List<dynamic>)) {
        polys.add([
          for (final pt in (poly as List<dynamic>))
            [(pt[0] as num).toDouble(), (pt[1] as num).toDouble()],
        ]);
      }
      eyes.add(polys);
    }

    final shapesRaw = j['shapes'] as Map<String, dynamic>;
    final shapes = <String, GrokShape>{};
    for (final e in shapesRaw.entries) {
      final v = e.value as Map<String, dynamic>;
      final f = (v['face'] as Map<String, dynamic>?) ?? const {};
      shapes[e.key] = GrokShape(
        label: v['label'] as String,
        path: v['path'] as String,
        face: Face(
          x: (f['x'] as num?)?.toDouble() ?? 0,
          y: (f['y'] as num?)?.toDouble() ?? 0,
          sx: (f['sx'] as num?)?.toDouble() ?? 1,
          sy: (f['sy'] as num?)?.toDouble() ?? 1,
          eye: (f['eye'] as num?)?.toDouble() ?? 1,
        ),
        radius: (v['radius'] as num?)?.toDouble() ?? 0,
        tiltScale: (v['tiltScale'] as num?)?.toDouble() ?? 1,
        top: (v['top'] as num?)?.toDouble() ?? 0,
        bottom: (v['bottom'] as num?)?.toDouble() ?? 0,
      );
    }

    final solidsRaw = (j['solids'] as Map<String, dynamic>?) ?? {};
    final solids = <String, List<List<double>>>{
      for (final e in solidsRaw.entries)
        e.key: [
          for (final row in (e.value as List<dynamic>))
            [for (final n in (row as List<dynamic>)) (n as num).toDouble()],
        ],
    };

    final vb = j['viewBox'] as Map<String, dynamic>;
    return GrokGeometry(
      re: (j['Re'] as num).toDouble(),
      g9e: (j['G9e'] as num).toDouble(),
      vjt: (j['VJt'] as num).toDouble(),
      viewBox: ViewBox(
        minX: (vb['minX'] as num).toDouble(),
        minY: (vb['minY'] as num).toDouble(),
        width: (vb['width'] as num).toDouble(),
        height: (vb['height'] as num).toDouble(),
      ),
      blobPath: j['blobPath'] as String,
      starPath: j['starPath'] as String,
      starColor: j['starColor'] as String,
      palette: palette,
      eyes: eyes,
      shapes: shapes,
      solids: solids,
    );
  }
}
