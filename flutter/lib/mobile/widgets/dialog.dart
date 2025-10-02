import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/widgets/setting_widgets.dart';
import 'package:flutter_hbb/common/widgets/toolbar.dart';
import 'package:get/get.dart';

import '../../common.dart';
import '../../models/platform_model.dart';

void _showSuccess() {
  showToast(translate("Successful"));
}

void _showError() {
  showToast(translate("Error"));
}

void setPermanentPasswordDialog(OverlayDialogManager dialogManager) async {
  final pw = await bind.mainGetPermanentPassword();
  final p0 = TextEditingController(text: pw);
  final p1 = TextEditingController(text: pw);
  var validateLength = false;
  var validateSame = false;
  dialogManager.show((setState, close, context) {
    submit() async {
      close();
      dialogManager.showLoading(translate("Waiting"));
      if (await gFFI.serverModel.setPermanentPassword(p0.text)) {
        dialogManager.dismissAll();
        _showSuccess();
      } else {
        dialogManager.dismissAll();
        _showError();
      }
    }

    return CustomAlertDialog(
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.password_rounded, color: MyTheme.accent),
          Text(translate('Set your own password')).paddingOnly(left: 10),
        ],
      ),
      content: Form(
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.visiblePassword,
              decoration: InputDecoration(
                labelText: translate('Password'),
              ),
              controller: p0,
              validator: (v) {
                if (v == null) return null;
                final val = v.trim().length > 5;
                if (validateLength != val) {
                  // use delay to make setState success
                  Future.delayed(Duration(microseconds: 1),
                      () => setState(() => validateLength = val));
                }
                return val
                    ? null
                    : translate('Too short, at least 6 characters.');
              },
            ).workaroundFreezeLinuxMint(),
            TextFormField(
              obscureText: true,
              keyboardType: TextInputType.visiblePassword,
              decoration: InputDecoration(
                labelText: translate('Confirmation'),
              ),
              controller: p1,
              validator: (v) {
                if (v == null) return null;
                final val = p0.text == v;
                if (validateSame != val) {
                  Future.delayed(Duration(microseconds: 1),
                      () => setState(() => validateSame = val));
                }
                return val
                    ? null
                    : translate('The confirmation is not identical.');
              },
            ).workaroundFreezeLinuxMint(),
          ])),
      onCancel: close,
      onSubmit: (validateLength && validateSame) ? submit : null,
      actions: [
        dialogButton(
          'Cancel',
          icon: Icon(Icons.close_rounded),
          onPressed: close,
          isOutline: true,
        ),
        dialogButton(
          'OK',
          icon: Icon(Icons.done_rounded),
          onPressed: (validateLength && validateSame) ? submit : null,
        ),
      ],
    );
  });
}

void setTemporaryPasswordLengthDialog(
    OverlayDialogManager dialogManager) async {
  List<String> lengths = ['6', '8', '10'];
  String length = await bind.mainGetOption(key: "temporary-password-length");
  var index = lengths.indexOf(length);
  if (index < 0) index = 0;
  length = lengths[index];
  dialogManager.show((setState, close, context) {
    setLength(newValue) {
      final oldValue = length;
      if (oldValue == newValue) return;
      setState(() {
        length = newValue;
      });
      bind.mainSetOption(key: "temporary-password-length", value: newValue);
      bind.mainUpdateTemporaryPassword();
      Future.delayed(Duration(milliseconds: 200), () {
        close();
        _showSuccess();
      });
    }

    return CustomAlertDialog(
      title: Text(translate("Set one-time password length")),
      content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: lengths
              .map(
                (value) => Row(
                  children: [
                    Text(value),
                    Radio(
                        value: value, groupValue: length, onChanged: setLength),
                  ],
                ),
              )
              .toList()),
    );
  }, backDismiss: true, clickMaskDismiss: true);
}

void showServerSettings(OverlayDialogManager dialogManager) async {
  Map<String, dynamic> options = {};
  try {
    options = jsonDecode(await bind.mainGetOptions());
  } catch (e) {
    print("Invalid server config: $e");
  }
  showServerSettingsWithValue(ServerConfig.fromOptions(options), dialogManager);
}

void showServerSettingsWithValue(
    ServerConfig serverConfig, OverlayDialogManager dialogManager) async {
  var isInProgress = false;
  final idCtrl = TextEditingController(text: serverConfig.idServer);
  final relayCtrl = TextEditingController(text: serverConfig.relayServer);
  final apiCtrl = TextEditingController(text: serverConfig.apiServer);
  final keyCtrl = TextEditingController(text: serverConfig.key);

  RxString idServerMsg = ''.obs;
  RxString relayServerMsg = ''.obs;
  RxString apiServerMsg = ''.obs;

  final controllers = [idCtrl, relayCtrl, apiCtrl, keyCtrl];
  final errMsgs = [
    idServerMsg,
    relayServerMsg,
    apiServerMsg,
  ];

  dialogManager.show((setState, close, context) {
    Future<bool> submit() async {
      setState(() {
        isInProgress = true;
      });
      bool ret = await setServerConfig(
          null,
          errMsgs,
          ServerConfig(
              idServer: idCtrl.text.trim(),
              relayServer: relayCtrl.text.trim(),
              apiServer: apiCtrl.text.trim(),
              key: keyCtrl.text.trim()));
      setState(() {
        isInProgress = false;
      });
      return ret;
    }

    Widget buildField(
        String label, TextEditingController controller, String errorMsg,
        {String? Function(String?)? validator, bool autofocus = false}) {
      if (isDesktop || isWeb) {
        return Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(label),
            ),
            SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  errorText: errorMsg.isEmpty ? null : errorMsg,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                ),
                validator: validator,
                autofocus: autofocus,
              ).workaroundFreezeLinuxMint(),
            ),
          ],
        );
      }

      return TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          errorText: errorMsg.isEmpty ? null : errorMsg,
        ),
        validator: validator,
      ).workaroundFreezeLinuxMint();
    }

    return CustomAlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(translate('ID/Relay Server'))),
          ...ServerConfigImportExportWidgets(controllers, errMsgs),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 500),
        child: Form(
          child: Obx(() => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildField(translate('ID Server'), idCtrl, idServerMsg.value,
                      autofocus: true),
                  SizedBox(height: 8),
                  if (!isIOS && !isWeb) ...[
                    buildField(translate('Relay Server'), relayCtrl,
                        relayServerMsg.value),
                    SizedBox(height: 8),
                  ],
                  buildField(
                    translate('API Server'),
                    apiCtrl,
                    apiServerMsg.value,
                    validator: (v) {
                      if (v != null && v.isNotEmpty) {
                        if (!(v.startsWith('http://') ||
                            v.startsWith("https://"))) {
                          return translate("invalid_http");
                        }
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 8),
                  buildField('Key', keyCtrl, ''),
                  if (isInProgress)
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(),
                    ),
                ],
              )),
        ),
      ),
      actions: [
        dialogButton('Cancel', onPressed: () {
          close();
        }, isOutline: true),
        dialogButton(
          'OK',
          onPressed: () async {
            if (await submit()) {
              close();
              showToast(translate('Successful'));
            } else {
              showToast(translate('Failed'));
            }
          },
        ),
      ],
    );
  });
}

void setPrivacyModeDialog(
  OverlayDialogManager dialogManager,
  List<TToggleMenu> privacyModeList,
  RxString privacyModeState,
) async {
  dialogManager.dismissAll();
  dialogManager.show((setState, close, context) {
    return CustomAlertDialog(
      title: Text(translate('Privacy mode')),
      content: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: privacyModeList
              .map((value) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    title: value.child,
                    value: value.value,
                    onChanged: value.onChanged,
                  ))
              .toList()),
    );
  }, backDismiss: true, clickMaskDismiss: true);
}

/// Show config code input dialog
/// Allows users to input server configuration code
void showConfigCodeDialog(OverlayDialogManager dialogManager) async {
  final codeCtrl = TextEditingController();
  var isVerifying = false;
  var errorMsg = '';

  final RxString idServerMsg = ''.obs;
  final RxString relayServerMsg = ''.obs;
  final RxString apiServerMsg = ''.obs;
  final errMsgs = [idServerMsg, relayServerMsg, apiServerMsg];

  dialogManager.show((setState, close, context) {
    Future<void> fetchConfig() async {
      final code = codeCtrl.text.trim();
      
      if (code.isEmpty) {
        setState(() {
          errorMsg = translate('Please enter config code');
        });
        return;
      }

      setState(() {
        isVerifying = true;
        errorMsg = '';
      });

      try {
        // Decode the config code
        final config = ServerConfig.decode(code);
        
        if (isWeb || isIOS) {
          config.relayServer = '';
        }

        // Apply the configuration
        bool success = await setServerConfig(null, errMsgs, config);
        
        setState(() {
          isVerifying = false;
        });

        if (success) {
          close();
          // Show success dialog
          showConfigSuccessDialog(dialogManager, config);
        } else {
          setState(() {
            errorMsg = translate('Failed to apply configuration');
          });
        }
      } catch (e) {
        setState(() {
          isVerifying = false;
          errorMsg = translate('Invalid config code');
        });
        debugPrint('Config code decode error: $e');
      }
    }

    return CustomAlertDialog(
      title: Row(
        children: [
          Icon(Icons.vpn_key, color: MyTheme.accent),
          SizedBox(width: 10),
          Expanded(child: Text(translate('Get Server Config'))),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              translate('Config Code'),
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
            SizedBox(height: 8),
            TextFormField(
              controller: codeCtrl,
              decoration: InputDecoration(
                hintText: 'KUST-1001-20250926-...',
                helperText: translate('Enter the config code provided by admin'),
                errorText: errorMsg.isEmpty ? null : errorMsg,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ).workaroundFreezeLinuxMint(),
            if (isVerifying) ...[
              SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text(
                    translate('Verifying config code...'),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      translate('Config code example: KUST-XXXX-YYYYMMDD-...'),
                      style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        dialogButton(
          'Cancel',
          icon: Icon(Icons.close_rounded),
          onPressed: close,
          isOutline: true,
        ),
        dialogButton(
          'Get Config',
          icon: Icon(Icons.cloud_download_rounded),
          onPressed: isVerifying ? null : fetchConfig,
        ),
      ],
    );
  });
}

/// Show configuration success dialog with server details
void showConfigSuccessDialog(
    OverlayDialogManager dialogManager, ServerConfig config) async {
  dialogManager.show((setState, close, context) {
    // Save config timestamp
    final configTime = DateTime.now().toString().substring(0, 19);
    bind.mainSetOption(key: 'config_timestamp', value: configTime);
    bind.mainSetOption(key: 'config_name', value: config.idServer);

    return CustomAlertDialog(
      title: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 28),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              translate('Configuration Successful'),
              style: TextStyle(color: Colors.green[700]),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Success message
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                children: [
                  Icon(Icons.celebration, size: 48, color: Colors.green[400]),
                  SizedBox(height: 12),
                  Text(
                    translate('Configuration Complete!'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    translate('Successfully connected to server'),
                    style: TextStyle(color: Colors.green[600]),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            
            // Server information
            Text(
              translate('Server Information'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            _buildInfoRow(Icons.dns, 'ID Server', config.idServer),
            if (config.relayServer.isNotEmpty)
              _buildInfoRow(Icons.router, 'Relay Server', config.relayServer),
            if (config.apiServer.isNotEmpty)
              _buildInfoRow(Icons.cloud, 'API Server', config.apiServer),
            _buildInfoRow(Icons.access_time, 'Config Time', configTime),
            SizedBox(height: 16),
            
            // Status indicators
            _buildStatusRow(Icons.check_circle, 'ID Server', true),
            if (config.relayServer.isNotEmpty)
              _buildStatusRow(Icons.check_circle, 'Relay Server', true),
            if (config.apiServer.isNotEmpty)
              _buildStatusRow(Icons.check_circle, 'API Server', true),
            SizedBox(height: 16),
            
            // Tip
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, size: 20, color: Colors.blue[700]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      translate('Tip: Configuration saved. You can now login and start using.'),
                      style: TextStyle(fontSize: 13, color: Colors.blue[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        dialogButton(
          'Continue',
          icon: Icon(Icons.arrow_forward_rounded),
          onPressed: close,
        ),
      ],
    );
  });
}

Widget _buildInfoRow(IconData icon, String label, String value) {
  return Padding(
    padding: EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

Widget _buildStatusRow(IconData icon, String label, bool isSuccess) {
  return Padding(
    padding: EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: isSuccess ? Colors.green : Colors.grey,
        ),
        SizedBox(width: 8),
        Text(
          '$label ${isSuccess ? translate("Connected") : translate("Disconnected")}',
          style: TextStyle(
            color: isSuccess ? Colors.green[700] : Colors.grey,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}

/// Show welcome dialog on first launch
/// Guide users to configure server with config code
void showWelcomeConfigDialog(OverlayDialogManager dialogManager) async {
  dialogManager.show((setState, close, context) {
    return CustomAlertDialog(
      title: Row(
        children: [
          Icon(Icons.celebration, color: MyTheme.accent, size: 28),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              translate('Welcome to RustDesk'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 500, maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome banner
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    MyTheme.accent.withOpacity(0.1),
                    MyTheme.accent.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MyTheme.accent.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.rocket_launch, size: 56, color: MyTheme.accent),
                  SizedBox(height: 12),
                  Text(
                    translate('Start Configuring Your Remote Connection'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: MyTheme.accent,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    translate('Quick and easy setup in just a few steps'),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            
            // Configuration options
            Text(
              translate('Choose Setup Method'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            
            // Option 1: Config code (recommended)
            Container(
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.vpn_key, color: Colors.blue[700], size: 24),
                ),
                title: Row(
                  children: [
                    Text(
                      translate('Use Config Code'),
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        translate('Recommended'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  translate('Enter the config code provided by your admin'),
                  style: TextStyle(fontSize: 13),
                ),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  close();
                  // Small delay to allow welcome dialog to close first
                  Future.delayed(Duration(milliseconds: 300), () {
                    showConfigCodeDialog(dialogManager);
                  });
                },
              ),
            ),
            SizedBox(height: 12),
            
            // Option 2: Manual configuration
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.settings, color: Colors.grey[700], size: 24),
                ),
                title: Text(
                  translate('Manual Configuration'),
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  translate('For advanced users'),
                  style: TextStyle(fontSize: 13),
                ),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  close();
                  Future.delayed(Duration(milliseconds: 300), () {
                    showServerSettings(dialogManager);
                  });
                },
              ),
            ),
            SizedBox(height: 20),
            
            // Info tip
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.amber[800]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      translate('Tip: Contact your administrator to get a config code for quick setup'),
                      style: TextStyle(fontSize: 12, color: Colors.amber[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        dialogButton(
          'Skip for Now',
          icon: Icon(Icons.skip_next),
          onPressed: close,
          isOutline: true,
        ),
        dialogButton(
          'Get Config Code',
          icon: Icon(Icons.vpn_key),
          onPressed: () {
            close();
            Future.delayed(Duration(milliseconds: 300), () {
              showConfigCodeDialog(dialogManager);
            });
          },
        ),
      ],
    );
  });
}
