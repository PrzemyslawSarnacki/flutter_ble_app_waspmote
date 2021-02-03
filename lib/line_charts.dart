
import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;


class LineAnimationZoomChart extends StatelessWidget {
  final List<charts.Series> seriesList;
  final bool animate;

  LineAnimationZoomChart(this.seriesList, {this.animate = false});

  // EXCLUDE_FROM_GALLERY_DOCS_START
  // This section is excluded from being copied to the gallery.
  // It is used for creating random series data to demonstrate animation in
  // the example app only.
  factory LineAnimationZoomChart.withRandomData(List<double> countList) {
    return new LineAnimationZoomChart(_createRandomData(countList));
  }

  /// Create random data.
  static List<charts.Series<LinearSales, num>> _createRandomData(
      List<double> countList) {
    final data = <LinearSales>[];

    for (var i = 0; i < countList.length; i++) {
      data.add(new LinearSales(i, countList[i]));
    }

    return [
      new charts.Series<LinearSales, int>(
        id: 'Line',
        colorFn: (_, __) => charts.MaterialPalette.purple.shadeDefault,
        domainFn: (LinearSales sales, _) => sales.x,
        measureFn: (LinearSales sales, _) => sales.y,
        data: data,
      )
    ];
  }
  // EXCLUDE_FROM_GALLERY_DOCS_END

  @override
  Widget build(BuildContext context) {
    var axis = charts.NumericAxisSpec(
        renderSpec: charts.GridlineRendererSpec(
            labelStyle: charts.TextStyleSpec(
                fontSize: 10, color: charts.MaterialPalette.white),
            lineStyle: charts.LineStyleSpec(
                thickness: 0,
                color: charts.MaterialPalette.gray.shadeDefault)));

    return new charts.LineChart(
      seriesList,
      animate: animate,
      behaviors: [
        new charts.PanAndZoomBehavior(),
      ],
      primaryMeasureAxis: axis,
      domainAxis: axis,
    );
  }
}

/// Sample linear data type.
class LinearSales {
  final int x;
  final double y;

  LinearSales(this.x, this.y);
}