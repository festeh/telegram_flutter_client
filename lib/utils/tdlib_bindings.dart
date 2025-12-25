import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

typedef TdJsonClientCreateC = Pointer Function();
typedef TdJsonClientCreateDart = Pointer Function();

typedef TdJsonClientSendC = Void Function(
    Pointer client, Pointer<Utf8> request);
typedef TdJsonClientSendDart = void Function(
    Pointer client, Pointer<Utf8> request);

typedef TdJsonClientReceiveC = Pointer<Utf8> Function(
    Pointer client, Double timeout);
typedef TdJsonClientReceiveDart = Pointer<Utf8> Function(
    Pointer client, double timeout);

typedef TdJsonClientExecuteC = Pointer<Utf8> Function(
    Pointer client, Pointer<Utf8> request);
typedef TdJsonClientExecuteDart = Pointer<Utf8> Function(
    Pointer client, Pointer<Utf8> request);

typedef TdJsonClientDestroyC = Void Function(Pointer client);
typedef TdJsonClientDestroyDart = void Function(Pointer client);

class TdLibBindings {
  static final DynamicLibrary _dylib = _loadLibrary();

  static DynamicLibrary _loadLibrary() {
    if (Platform.isLinux) {
      final libraryPath =
          path.join(Directory.current.path, 'linux', 'lib', 'libtdjson.so');
      if (File(libraryPath).existsSync()) {
        return DynamicLibrary.open(libraryPath);
      }
      return DynamicLibrary.open('libtdjson.so');
    } else if (Platform.isAndroid) {
      return DynamicLibrary.open('libtdjson.so');
    } else if (Platform.isWindows) {
      return DynamicLibrary.open('tdjson.dll');
    } else if (Platform.isMacOS) {
      return DynamicLibrary.open('libtdjson.dylib');
    }
    throw UnsupportedError('Platform not supported');
  }

  static final TdJsonClientCreateDart tdJsonClientCreate = _dylib
      .lookup<NativeFunction<TdJsonClientCreateC>>('td_json_client_create')
      .asFunction<TdJsonClientCreateDart>();

  static final TdJsonClientSendDart tdJsonClientSend = _dylib
      .lookup<NativeFunction<TdJsonClientSendC>>('td_json_client_send')
      .asFunction<TdJsonClientSendDart>();

  static final TdJsonClientReceiveDart tdJsonClientReceive = _dylib
      .lookup<NativeFunction<TdJsonClientReceiveC>>('td_json_client_receive')
      .asFunction<TdJsonClientReceiveDart>();

  static final TdJsonClientExecuteDart tdJsonClientExecute = _dylib
      .lookup<NativeFunction<TdJsonClientExecuteC>>('td_json_client_execute')
      .asFunction<TdJsonClientExecuteDart>();

  static final TdJsonClientDestroyDart tdJsonClientDestroy = _dylib
      .lookup<NativeFunction<TdJsonClientDestroyC>>('td_json_client_destroy')
      .asFunction<TdJsonClientDestroyDart>();
}

class TdJsonClient {
  late Pointer _client;

  TdJsonClient() {
    _client = TdLibBindings.tdJsonClientCreate();
  }

  void send(String request) {
    final requestPtr = request.toNativeUtf8();
    TdLibBindings.tdJsonClientSend(_client, requestPtr);
    calloc.free(requestPtr);
  }

  String? receive([double timeout = 1.0]) {
    final responsePtr = TdLibBindings.tdJsonClientReceive(_client, timeout);
    if (responsePtr == nullptr) return null;

    final response = responsePtr.toDartString();
    return response;
  }

  String? execute(String request) {
    final requestPtr = request.toNativeUtf8();
    final responsePtr = TdLibBindings.tdJsonClientExecute(_client, requestPtr);
    calloc.free(requestPtr);

    if (responsePtr == nullptr) return null;

    final response = responsePtr.toDartString();
    return response;
  }

  void destroy() {
    TdLibBindings.tdJsonClientDestroy(_client);
  }
}
