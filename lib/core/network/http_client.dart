// 网络客户端，对应原项目 com.github.tvbox.osc.util.OkGoHelper / OkHttp
// 基于 dio，统一 UA、超时、自定义 DNS 暂留扩展点
import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import '../utils/log.dart';

class HttpClient {
  HttpClient._();

  static late Dio _dio;
  static late Dio _noRedirectDio; // 不跟随重定向，用于嗅探

  static Dio get dio => _dio;
  static Dio get noRedirectDio => _noRedirectDio;

  static void init({String? ua, int connectTimeout = 10000, int receiveTimeout = 15000}) {
    final baseUa = ua ?? AppConstants.defaultUa;
    _dio = Dio(BaseOptions(
      connectTimeout: Duration(milliseconds: connectTimeout),
      receiveTimeout: Duration(milliseconds: receiveTimeout),
      followRedirects: true,
      validateStatus: (_) => true, // 不抛 4xx/5xx，由调用方判断
      headers: {'User-Agent': baseUa},
    ));
    _noRedirectDio = Dio(BaseOptions(
      connectTimeout: Duration(milliseconds: connectTimeout),
      receiveTimeout: Duration(milliseconds: receiveTimeout),
      followRedirects: false,
      validateStatus: (_) => true,
      headers: {'User-Agent': baseUa},
    ));
    _dio.interceptors.add(_LogInterceptor());
  }

  /// GET，返回字符串
  static Future<String> get(String url,
      {Map<String, dynamic>? query, Map<String, dynamic>? headers}) async {
    try {
      final resp = await _dio.get<String>(url,
          queryParameters: query,
          options: Options(
            headers: headers,
            responseType: ResponseType.plain,
          ));
      return resp.data ?? '';
    } catch (e) {
      LOG.e('HttpClient', 'GET $url 失败', e);
      return '';
    }
  }

  /// POST
  static Future<String> post(String url,
      {dynamic data, Map<String, dynamic>? headers}) async {
    try {
      final resp = await _dio.post<String>(url,
          data: data,
          options: Options(
            headers: headers,
            responseType: ResponseType.plain,
          ));
      return resp.data ?? '';
    } catch (e) {
      LOG.e('HttpClient', 'POST $url 失败', e);
      return '';
    }
  }

  /// 获取字节流
  static Future<List<int>> getBytes(String url,
      {Map<String, dynamic>? headers}) async {
    try {
      final resp = await _dio.get<List<int>>(url,
          options: Options(headers: headers, responseType: ResponseType.bytes));
      return resp.data ?? [];
    } catch (e) {
      LOG.e('HttpClient', 'getBytes $url 失败', e);
      return [];
    }
  }
}

class _LogInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    LOG.e('Dio', err.requestOptions.uri.toString(), err);
    super.onError(err, handler);
  }
}
