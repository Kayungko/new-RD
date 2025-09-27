import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/dialog.dart';
import 'package:flutter_hbb/mobile/widgets/dialog.dart' as mobile_dialog;
import 'package:flutter_hbb/utils/server_config_manager.dart';

/// 自动配置对话框
/// 在首次启动或用户主动触发时显示
class AutoConfigDialog extends StatefulWidget {
  final OverlayDialogManager dialogManager;
  final VoidCallback? onSuccess;
  final VoidCallback? onSkip;

  const AutoConfigDialog({
    Key? key,
    required this.dialogManager,
    this.onSuccess,
    this.onSkip,
  }) : super(key: key);

  @override
  State<AutoConfigDialog> createState() => _AutoConfigDialogState();
}

class _AutoConfigDialogState extends State<AutoConfigDialog> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();
  bool _isLoading = false;
  String _statusMessage = '';
  ConfigCodeResult? _lastResult;

  @override
  void initState() {
    super.initState();
    // 自动聚焦输入框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _codeFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomAlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.cloud_download_outlined,
            color: MyTheme.accent,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              translate('获取服务器配置'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 400,
          maxWidth: 500,
          minHeight: 200,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIntroSection(),
            const SizedBox(height: 20),
            _buildCodeInputSection(),
            const SizedBox(height: 16),
            _buildStatusSection(),
            if (_lastResult?.isSuccess == true) ...[
              const SizedBox(height: 16),
              _buildSuccessSection(),
            ],
          ],
        ),
      ),
      actions: [
        dialogButton(
          '稍后设置',
          onPressed: _isLoading ? null : () {
            widget.dialogManager.dismissAll();
            widget.onSkip?.call();
          },
          isOutline: true,
        ),
        if (_lastResult?.isSuccess == true)
          dialogButton(
            '应用配置',
            onPressed: _isLoading ? null : _applyConfig,
          )
        else
          dialogButton(
            '获取配置',
            onPressed: _isLoading || !_isCodeValid ? null : _fetchConfig,
          ),
        if (!isDesktop)
          dialogButton(
            '手动配置',
            onPressed: _isLoading ? null : _showManualConfig,
            isOutline: true,
          ),
      ],
    );
  }

  Widget _buildIntroSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MyTheme.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MyTheme.accent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: MyTheme.accent,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '请输入管理员提供的配置码，系统将自动配置服务器连接信息',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '配置码',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _codeController,
          focusNode: _codeFocusNode,
          decoration: InputDecoration(
            hintText: '请输入配置码 (如: KUST-1001-20250926-...)',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: MyTheme.accent, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            suffixIcon: _codeController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _codeController.clear();
                      setState(() {
                        _lastResult = null;
                        _statusMessage = '';
                      });
                    },
                  )
                : null,
          ),
          style: const TextStyle(fontSize: 14),
          onChanged: (value) {
            setState(() {
              _lastResult = null;
              _statusMessage = '';
            });
          },
          onSubmitted: _isCodeValid ? (_) => _fetchConfig() : null,
          inputFormatters: [
            LengthLimitingTextInputFormatter(200),
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-_]')),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '示例: KUST-1001-20250926-A1B2C3D4E5F6...',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '正在获取配置...',
              style: TextStyle(color: Colors.blue[700], fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_statusMessage.isNotEmpty) {
      final isError = _lastResult?.isSuccess != true;
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isError ? Colors.red[50] : Colors.green[50],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isError ? Colors.red[200]! : Colors.green[200]!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.red[600] : Colors.green[600],
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _statusMessage,
                style: TextStyle(
                  color: isError ? Colors.red[700] : Colors.green[700],
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSuccessSection() {
    final result = _lastResult!;
    final config = result.config!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[600], size: 20),
              const SizedBox(width: 8),
              Text(
                '配置获取成功',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.green[700],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildConfigInfo('配置名称', result.configName ?? ''),
          if (result.region?.isNotEmpty == true)
            _buildConfigInfo('地域', result.region!),
          _buildConfigInfo('ID服务器', config.idServer),
          if (config.relayServer.isNotEmpty)
            _buildConfigInfo('中继服务器', config.relayServer),
          if (config.apiServer.isNotEmpty)
            _buildConfigInfo('API服务器', config.apiServer),
        ],
      ),
    );
  }

  Widget _buildConfigInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '-',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _isCodeValid {
    return ServerConfigManager.isValidConfigCode(_codeController.text);
  }

  Future<void> _fetchConfig() async {
    if (!_isCodeValid) return;

    setState(() {
      _isLoading = true;
      _statusMessage = '';
      _lastResult = null;
    });

    try {
      final result = await ServerConfigManager.fetchConfigByCode(_codeController.text);
      
      setState(() {
        _isLoading = false;
        _lastResult = result;
        if (result.isSuccess) {
          _statusMessage = '配置获取成功！';
        } else {
          _statusMessage = result.error ?? '获取配置失败';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '获取配置失败: $e';
      });
    }
  }

  Future<void> _applyConfig() async {
    if (_lastResult?.isSuccess != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = '正在应用配置...';
    });

    try {
      final success = await ServerConfigManager.applyServerConfig(
        _lastResult!.config!,
        _lastResult!.configName ?? '自动配置',
        _codeController.text,
      );

      if (success) {
        widget.dialogManager.dismissAll();
        showToast(translate('配置应用成功'));
        widget.onSuccess?.call();
      } else {
        setState(() {
          _isLoading = false;
          _statusMessage = '应用配置失败';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '应用配置失败: $e';
      });
    }
  }

  void _showManualConfig() {
    widget.dialogManager.dismissAll();
    // 显示手动配置对话框
    if (isMobile) {
      mobile_dialog.showServerSettings(widget.dialogManager);
    } else {
      showServerSettings(widget.dialogManager);
    }
  }
}

/// 显示自动配置对话框的便捷方法
void showAutoConfigDialog(
  OverlayDialogManager dialogManager, {
  VoidCallback? onSuccess,
  VoidCallback? onSkip,
}) {
  dialogManager.show(
    (setState, close, context) => AutoConfigDialog(
      dialogManager: dialogManager,
      onSuccess: onSuccess,
      onSkip: onSkip,
    ),
    backDismiss: false,
    clickMaskDismiss: false,
  );
}

/// 检查并显示首次启动配置对话框
Future<void> checkAndShowFirstTimeConfig(OverlayDialogManager dialogManager) async {
  // 检查是否是首次启动且未配置服务器
  final hasAutoConfig = ServerConfigManager.hasAutoConfigApplied;
  final hasManualConfig = bind.mainGetLocalOption(key: 'custom-rendezvous-server').isNotEmpty;
  
  // 如果既没有自动配置也没有手动配置，且不是在特定页面，则显示配置对话框
  if (!hasAutoConfig && !hasManualConfig) {
    // 延迟一点时间显示，确保界面完全加载
    await Future.delayed(const Duration(milliseconds: 500));
    showAutoConfigDialog(dialogManager);
  }
}
