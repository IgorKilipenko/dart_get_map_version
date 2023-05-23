import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
//import 'dart:js_interop';
import 'package:ffi/ffi.dart' as ffi_package;
import 'package:ffi/ffi.dart';

import 'dart_get_map_version_bindings_generated.dart';

/// A very short-lived native function.
///
/// For very short-lived functions, it is fine to call them on the main isolate.
/// They will block the Dart execution while running the native function, so
/// only do this for native functions which are guaranteed to be short-lived.
int sum(int a, int b) => _bindings.sum(a, b);

/// A longer lived native function, which occupies the thread calling it.
///
/// Do not call these kind of native functions in the main isolate. They will
/// block Dart execution. This will cause dropped frames in Flutter applications.
/// Instead, call these native functions on a separate isolate.
///
/// Modify this to suit your own use case. Example use cases:
///
/// 1. Reuse a single isolate for various different kinds of requests.
/// 2. Use multiple helper isolates for parallel execution.
Future<int> sumAsync(int a, int b) async {
  final SendPort helperIsolateSendPort = await _helperIsolateSendPort;
  final int requestId = _nextSumRequestId++;
  final _SumRequest request = _SumRequest(requestId, a, b);
  final Completer<int> completer = Completer<int>();
  _sumRequests[requestId] = completer;
  helperIsolateSendPort.send(request);
  return completer.future;
}

const String _libName = 'dart_get_map_version';

/// The dynamic library in which the symbols for [DartGetMapVersionBindings] can be found.
final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// The bindings to the native functions in [_dylib].
final DartGetMapVersionBindings _bindings = DartGetMapVersionBindings(_dylib);

class _CppRequest {
  final int id;
  const _CppRequest(this.id);
}

/// A request to compute `sum`.
///
/// Typically sent from one isolate to another.
class _SumRequest extends _CppRequest {
  final int a;
  final int b;

  const _SumRequest(super.id, this.a, this.b);
}

class _CppResponse<T> {
  final int id;
  final T result;

  const _CppResponse(this.id, this.result);
}

/// A response with the result of `sum`.
///
/// Typically sent from one isolate to another.
class _SumResponse extends _CppResponse<int> {
  const _SumResponse(super.id, super.result);
}

/// Counter to identify [_SumRequest]s and [_SumResponse]s.
int _nextSumRequestId = 0;

/// Mapping from [_SumRequest] `id`s to the completers corresponding to the correct future of the pending request.
final Map<int, Completer<int>> _sumRequests = <int, Completer<int>>{};

/// The SendPort belonging to the helper isolate.
Future<SendPort> _helperIsolateSendPort = () async {
  // The helper isolate is going to send us back a SendPort, which we want to
  // wait for.
  final Completer<SendPort> completer = Completer<SendPort>();

  // Receive port on the main isolate to receive messages from the helper.
  // We receive two types of messages:
  // 1. A port to send messages on.
  // 2. Responses to requests we sent.
  final ReceivePort receivePort = ReceivePort()
    ..listen((dynamic data) {
      if (data is SendPort) {
        // The helper isolate sent us the port on which we can sent it requests.
        completer.complete(data);
        return;
      }
      if (data is _SumResponse) {
        // The helper isolate sent us a response to a request we sent.
        final Completer<int> completer = _sumRequests[data.id]!;
        _sumRequests.remove(data.id);
        completer.complete(data.result);
        return;
      }
      throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
    });

  // Start the helper isolate.
  await Isolate.spawn((SendPort sendPort) async {
    final ReceivePort helperReceivePort = ReceivePort()
      ..listen((dynamic data) {
        // On the helper isolate listen to requests and respond to them.
        if (data is _SumRequest) {
          final int result = _bindings.sum_long_running(data.a, data.b);
          final _SumResponse response = _SumResponse(data.id, result);
          sendPort.send(response);
          return;
        }
        throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
      });

    // Send the port to the main isolate on which we can receive requests.
    sendPort.send(helperReceivePort.sendPort);
  }, receivePort.sendPort);

  // Wait until the helper isolate has sent us back the SendPort on which we
  // can start sending requests.
  return completer.future;
}();

class _IsolateMessage<T, TRequest> {
  final SendPort sendPort;
  final T Function(TRequest) action;
  const _IsolateMessage(this.sendPort, this.action);
}

class _IsolateSender<T extends String> {
  final Map<int, Completer<T>> _requests = <int, Completer<T>>{};

  void set(int id, Completer<T> completer) {
    _requests[id] = completer;
  }

  static void _runIsolate<T, TRequest extends _CppRequest>(_IsolateMessage<T, TRequest> msg) {
    final helperReceivePort = ReceivePort()
      ..listen((dynamic data) {
        if (data is TRequest) {
          final result = msg.action(data);
          final response = _CppResponse<T>(data.id, result);
          msg.sendPort.send(response);
          return;
        }
        throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
      });

    msg.sendPort.send(helperReceivePort.sendPort);
  }

  Future<SendPort> sendPort<TRequest extends _CppRequest>(
      T Function(TRequest) action) async {
    final completer = Completer<SendPort>();

    final ReceivePort receivePort = ReceivePort()
      ..listen((dynamic data) {
        if (data is SendPort) {
          completer.complete(data);
          return;
        }
        if (data is _CppResponse<T>) {
          final Completer<T> completer = _requests[data.id]!;
          _sumRequests.remove(data.id);
          completer.complete(data.result);
          return;
        }
        throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
      });

    final msg = _IsolateMessage(receivePort.sendPort, action);
    await Isolate.spawn(_runIsolate<T,TRequest>, msg);

    return completer.future;
  }
}

class MapVersionGetter {
  static String? getGmapVersion() {
    final res = using((Arena arena) {
      final outVersion = arena<Pointer<Utf8>>();
      final success = _bindings.get_gmap_version(outVersion.cast());
      if (success != 0) {
        return outVersion.value.toDartString();
      }
      return null;
    });
    return res;
  }

  int _nextRequestId = 0;
  final sender = _IsolateSender<String>();

  Future<String> getGmapVersionAsync() async {
    String action(_CppRequest _) {
      return getGmapVersion() ?? "error";
    }

    final completer = Completer<String>();
    final request = _CppRequest(_nextRequestId++);
    sender.set(request.id, completer);
    final sendPort = await sender.sendPort<_CppRequest>(action);
    sendPort.send(request);
    return completer.future;
  }
}
