import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:flutter_hbb/common.dart';

/// 服务器配置管理器
/// 负责处理配置码的获取、解析、应用和状态管理
class ServerConfigManager {
  static const String _keyAutoConfigApplied = 'auto_config_applied';
  static const String _keyAutoConfigTimestamp = 'auto_config_timestamp';
  static const String _keyAutoConfigName = 'auto_config_name';
  static const String _keyAutoConfigCode = 'auto_config_code';

  /// 检查是否已应用自动配置
  static bool get hasAutoConfigApplied {
    return bind.mainGetLocalOption(key: _keyAutoConfigApplied) == 'true';
  }

  /// 获取自动配置信息
  static Map<String, String> getAutoConfigInfo() {
    return {
      'name': bind.mainGetLocalOption(key: _keyAutoConfigName),
      'timestamp': bind.mainGetLocalOption(key: _keyAutoConfigTimestamp),
      'code': bind.mainGetLocalOption(key: _keyAutoConfigCode),
    };
  }

  /// 清除自动配置
  static Future<void> clearAutoConfig() async {
    await bind.mainSetLocalOption(key: _keyAutoConfigApplied, value: '');
    await bind.mainSetLocalOption(key: _keyAutoConfigTimestamp, value: '');
    await bind.mainSetLocalOption(key: _keyAutoConfigName, value: '');
    await bind.mainSetLocalOption(key: _keyAutoConfigCode, value: '');
  }

  /// 根据配置码获取服务器配置
  /// 支持多种API服务器地址尝试
  static Future<ConfigCodeResult> fetchConfigByCode(String code) async {
    if (code.trim().isEmpty) {
      return ConfigCodeResult.error('配置码不能为空');
    }

    // 尝试的API服务器地址列表
    final List<String> apiServers = [
      // 首先尝试当前配置的API服务器
      bind.mainGetLocalOption(key: 'api-server'),
      // 然后尝试一些常见的默认地址
      'http://localhost:21114',
      'http://127.0.0.1:21114',
    ].where((url) => url.isNotEmpty).toList();

    // 如果没有配置API服务器，尝试从配置码推导
    if (apiServers.isEmpty) {
      final inferredServer = _inferApiServerFromCode(code);
      if (inferredServer.isNotEmpty) {
        apiServers.add(inferredServer);
      }
    }

    Exception? lastError;

    for (String apiServer in apiServers) {
      try {
        debugPrint('尝试从API服务器获取配置: $apiServer');
        
        final result = await _fetchFromApiServer(apiServer, code);
        if (result.isSuccess) {
          return result;
        }
        
        lastError = Exception(result.error);
      } catch (e) {
        debugPrint('从 $apiServer 获取配置失败: $e');
        lastError = e is Exception ? e : Exception(e.toString());
        continue;
      }
    }

    return ConfigCodeResult.error(
      lastError?.toString() ?? '无法连接到任何API服务器'
    );
  }

  /// 从指定API服务器获取配置
  static Future<ConfigCodeResult> _fetchFromApiServer(String apiServer, String code) async {
    try {
      // 确保API服务器地址格式正确
      if (!apiServer.startsWith('http://') && !apiServer.startsWith('https://')) {
        apiServer = 'http://$apiServer';
      }

      final url = '$apiServer/api/config/$code';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'RustDesk/${bind.mainGetVersion()}',
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint('API响应状态码: ${response.statusCode}');
      debugPrint('API响应内容: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        
        if (responseData['code'] == 200 && responseData['data'] != null) {
          final configData = responseData['data'];
          
          final serverConfig = ServerConfig(
            idServer: configData['id_server']?.toString() ?? '',
            relayServer: configData['relay_server']?.toString() ?? '',
            apiServer: configData['api_server']?.toString() ?? '',
            key: configData['key']?.toString() ?? '',
          );

          return ConfigCodeResult.success(
            serverConfig,
            configData['name']?.toString() ?? '自动配置',
            configData['region']?.toString() ?? '',
          );
        } else {
          return ConfigCodeResult.error(
            responseData['message']?.toString() ?? '服务器返回错误'
          );
        }
      } else if (response.statusCode == 404) {
        return ConfigCodeResult.error('配置码不存在或已过期');
      } else {
        return ConfigCodeResult.error('服务器错误 (${response.statusCode})');
      }
    } on SocketException {
      return ConfigCodeResult.error('网络连接失败');
    } on http.ClientException {
      return ConfigCodeResult.error('网络请求失败');
    } on FormatException {
      return ConfigCodeResult.error('服务器响应格式错误');
    } catch (e) {
      return ConfigCodeResult.error('获取配置失败: $e');
    }
  }

  /// 从配置码推导可能的API服务器地址
  static String _inferApiServerFromCode(String code) {
    // 如果配置码包含服务器信息，尝试推导
    // 这里可以根据配置码的格式来推导，例如：
    // KUST-{server_id}-{timestamp}-{encrypted_data}
    try {
      final parts = code.split('-');
      if (parts.length >= 4 && parts[0] == 'KUST') {
        // 这里可以添加更复杂的推导逻辑
        // 目前简单返回空，让其使用默认地址列表
      }
    } catch (e) {
      debugPrint('推导API服务器地址失败: $e');
    }
    return '';
  }

  /// 应用服务器配置
  static Future<bool> applyServerConfig(
    ServerConfig config, 
    String configName, 
    String configCode
  ) async {
    try {
      debugPrint('开始应用服务器配置: $configName');

      // 应用配置
      await bind.mainSetLocalOption(
        key: 'custom-rendezvous-server',
        value: config.idServer,
      );
      
      await bind.mainSetLocalOption(
        key: 'relay-server',
        value: config.relayServer,
      );
      
      await bind.mainSetLocalOption(
        key: 'api-server',
        value: config.apiServer,
      );
      
      await bind.mainSetLocalOption(
        key: 'key',
        value: config.key,
      );

      // 记录自动配置信息
      await bind.mainSetLocalOption(key: _keyAutoConfigApplied, value: 'true');
      await bind.mainSetLocalOption(
        key: _keyAutoConfigTimestamp,
        value: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      await bind.mainSetLocalOption(key: _keyAutoConfigName, value: configName);
      await bind.mainSetLocalOption(key: _keyAutoConfigCode, value: configCode);

      debugPrint('服务器配置应用成功');
      return true;
    } catch (e) {
      debugPrint('应用服务器配置失败: $e');
      return false;
    }
  }

  /// 验证配置码格式
  static bool isValidConfigCode(String code) {
    if (code.trim().isEmpty) return false;
    
    // 基本格式验证：KUST-开头的配置码
    if (code.startsWith('KUST-')) {
      final parts = code.split('-');
      return parts.length >= 4;
    }
    
    // 也支持其他格式的配置码
    return code.length >= 10;
  }

  /// 获取配置状态描述
  static String getConfigStatusDescription() {
    if (!hasAutoConfigApplied) {
      return '未应用自动配置';
    }

    final info = getAutoConfigInfo();
    final timestamp = int.tryParse(info['timestamp'] ?? '0') ?? 0;
    final configTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final configName = info['name'] ?? '未知配置';

    return '已应用配置: $configName\n配置时间: ${formatDateTime(configTime)}';
  }

  /// 格式化日期时间
  static String formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// 配置码获取结果
class ConfigCodeResult {
  final bool isSuccess;
  final ServerConfig? config;
  final String? configName;
  final String? region;
  final String? error;

  ConfigCodeResult._({
    required this.isSuccess,
    this.config,
    this.configName,
    this.region,
    this.error,
  });

  factory ConfigCodeResult.success(ServerConfig config, String configName, String region) {
    return ConfigCodeResult._(
      isSuccess: true,
      config: config,
      configName: configName,
      region: region,
    );
  }

  factory ConfigCodeResult.error(String error) {
    return ConfigCodeResult._(
      isSuccess: false,
      error: error,
    );
  }
}

/// 自动配置状态
enum AutoConfigStatus {
  notApplied,   // 未应用
  applied,      // 已应用
  expired,      // 已过期
}

/// 扩展ServerConfig类，添加自动配置相关方法
extension ServerConfigExtension on ServerConfig {
  /// 检查配置是否有效
  bool get isValid {
    return idServer.isNotEmpty;
  }

  /// 获取配置摘要信息
  String get summary {
    final List<String> parts = [];
    if (idServer.isNotEmpty) parts.add('ID: $idServer');
    if (relayServer.isNotEmpty) parts.add('Relay: $relayServer');
    if (apiServer.isNotEmpty) parts.add('API: $apiServer');
    return parts.join('\n');
  }
}
