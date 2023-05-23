import 'package:flutter/material.dart';
import 'dart:async';

import 'package:dart_get_map_version/dart_get_map_version.dart' as dart_get_map_version;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late int sumResult;
  late Future<int> sumAsyncResult;
  //late dart_get_map_version.MapVersionGetter mapVersionGetter;
  late Future<String> mapVersionAsyncResult;

  @override
  void initState() {
    super.initState();
    sumResult = dart_get_map_version.sum(1, 2);
    sumAsyncResult = dart_get_map_version.sumAsync(3, 4);
    mapVersionAsyncResult = dart_get_map_version.MapVersionGetter().getGmapVersionAsync();
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 25);
    const spacerSmall = SizedBox(height: 10);
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Native Packages'),
        ),
        body: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                /*Text(
                  'Map version: ${dart_get_map_version.MapVersionGetter.getGmapVersion()}',
                  style: textStyle,
                  textAlign: TextAlign.center,
                ),
                spacerSmall,*/
                const Text(
                  'This calls a native function through FFI that is shipped as source in the package. '
                  'The native code is built as part of the Flutter Runner build.',
                  style: textStyle,
                  textAlign: TextAlign.center,
                ),
                spacerSmall,
                Text(
                  'sum(1, 2) = $sumResult',
                  style: textStyle,
                  textAlign: TextAlign.center,
                ),
                spacerSmall,
                FutureBuilder<int>(
                  future: sumAsyncResult,
                  builder: (BuildContext context, AsyncSnapshot<int> value) {
                    final displayValue =
                        (value.hasData) ? value.data : 'loading';
                    return Text(
                      'await sumAsync(3, 4) = $displayValue',
                      style: textStyle,
                      textAlign: TextAlign.center,
                    );
                  },
                ),
                spacerSmall,
                FutureBuilder<String>(
                  future: mapVersionAsyncResult,
                  builder: (BuildContext context, AsyncSnapshot<String> value) {
                    final mapVersion =
                        (value.hasData) ? value.data : 'loading';
                    return Text(
                      'await Map version: $mapVersion',
                      style: textStyle,
                      textAlign: TextAlign.center,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
