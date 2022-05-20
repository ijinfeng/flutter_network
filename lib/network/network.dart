
import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:network_proj/network/network_env_route.dart';
import 'package:network_proj/network/request_config.dart';
import 'package:network_proj/network/response_model.dart';
import 'package:network_proj/network/response_serializer.dart';
import 'package:network_proj/network/exception.dart';
import 'package:network_proj/network/network_interceptor.dart';

Network network = Network();

typedef NetworkJSONModelBuilder<T> = T Function(Map<String, dynamic> json);
typedef NetworkOnError = void Function(NetworkException e);

class Network {
  late Dio _dio;

  Network({String? baseUrl}) {
    _dio = Dio(BaseOptions(
        baseUrl: baseUrl ?? RequestConfig.baseUrl,
        connectTimeout: RequestConfig.connectTimeout));
    _dio.interceptors.add(NetworkInterceptor());
    setLocalProxyIfNeeded();
  }

  void resetBaseUrl({String? baseUrl}) {
    _dio.options.baseUrl = baseUrl ?? RequestConfig.baseUrl;
  }

  void setLocalProxyIfNeeded() {
    if (kReleaseMode) return;
    (_dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate =
        (client) {
      client.findProxy = (uri) {
        return NetworkEnv().openProxy
            ? "PROXY ${NetworkEnv().localIp}:8888"
            : 'DIRECT';
      };
      client.badCertificateCallback = (cert, host, port) => true;
      return null;
    };
  }

  Future<ResponseModel<T>> request<T>(
    String url, {
    String method = "GET",
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? data,
    Map<String, dynamic>? headers,
    NetworkJSONModelBuilder<T>? builder,
    ResponseSerializer? serializer,

    /// * 从目标健（如data）开始,向下搜索的下一个键值
    /// * [searchKeyPath] 可以使用[.]连接表示层级，如 ‘list.person’ ，表示解析[list]下的[person]字典json，
    /// 这个json将在[builder]中返回
    String? searchKeyPath,
    void Function(NetworkException)? onError,
  }) async {
    try {
      Options options = Options()
        ..method = method
        ..headers = headers;

      Response response = await _dio.request(url,
          queryParameters: queryParameters, data: data, options: options);
      return _handleResponse(response, builder, serializer, searchKeyPath);
    } catch (e) {
      var exception = NetworkException.from(url, e);
      if (kDebugMode) print(exception);
      if (onError != null) {
        onError.call(exception);
      }
    }

    return ResponseModel.empty();
  }

  Future<ResponseModel<T>> get<T>(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    NetworkJSONModelBuilder<T>? builder,
    ResponseSerializer? serializer,
    String? searchKeyPath,
    NetworkOnError? onError,
  }) {
    return request(url,
        queryParameters: queryParameters,
        headers: headers,
        builder: builder,
        serializer: serializer,
        searchKeyPath: searchKeyPath,
        onError: onError);
  }

  Future<ResponseModel<T>> post<T>(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? body,
    Map<String, dynamic>? headers,
    NetworkJSONModelBuilder<T>? builder,
    ResponseSerializer? serializer,
    String? searchKeyPath,
    NetworkOnError? onError,
  }) {
    return request(url,
        method: "POST",
        queryParameters: queryParameters,
        data: body,
        headers: headers,
        builder: builder,
        serializer: serializer,
        searchKeyPath: searchKeyPath,
        onError: onError);
  }

  Future<ResponseModel<T>> put<T>(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    NetworkJSONModelBuilder<T>? builder,
    ResponseSerializer? serializer,
    String? searchKeyPath,
    NetworkOnError? onError,
  }) {
    return request(url,
        method: "PUT",
        queryParameters: queryParameters,
        headers: headers,
        builder: builder,
        serializer: serializer,
        searchKeyPath: searchKeyPath,
        onError: onError);
  }

  ///请求响应内容处理
  ResponseModel<T> _handleResponse<T>(
      Response response,
      NetworkJSONModelBuilder<T>? builder,
      ResponseSerializer? serializer,
      String? searchKeyPath) {
    ResponseSerializer _serializer = serializer ?? DefaultResponserSerializer();
    if (response.statusCode == 200) {
      return _serializer.serialize(response, builder, searchKeyPath);
    } else {
      var exception = NetworkException(
          response.requestOptions.baseUrl + response.requestOptions.path,
          response.statusCode,
          NetworkException.unknownException);
      throw exception;
    }
  }

  void cancel({bool force = false}) {
    _dio.close(force: force);
  }

  String get currentBaseUrl => _dio.options.baseUrl;
}
