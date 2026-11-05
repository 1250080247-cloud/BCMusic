import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'app_theme.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.controller,
    required this.register,
  });

  final MusicController controller;
  final bool register;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  static const _loginUsername = String.fromEnvironment(
    'BCMUSIC_LOGIN_USERNAME',
  );
  final _form = GlobalKey<FormState>();
  late final _username = TextEditingController(
    text: widget.register ? '' : _loginUsername,
  );
  final _password = TextEditingController();
  final _displayName = TextEditingController();
  late bool _register = widget.register;
  bool _busy = false, _visible = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.pop(context);
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() {
          if (error.code == 'REGISTERED') _register = false;
          _error = error.message ?? 'Chưa đăng nhập được. Hãy thử lại.';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Chưa thực hiện được. Hãy thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    _run(() async {
      await widget.controller.authenticate(
        _username.text,
        _password.text,
        displayName: _register ? _displayName.text : null,
      );
      if (mounted) TextInput.finishAutofillContext();
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        22,
        10,
        22,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: AutofillGroup(
        onDisposeAction: AutofillContextAction.cancel,
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _register ? 'Đăng ký BCMusic' : 'Đăng nhập BCMusic',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(
                'Dùng cùng tài khoản với BCMusic trên web.',
                style: TextStyle(color: context.palette.muted),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(widget.controller.startGoogle),
                icon: const Icon(Icons.account_circle_outlined),
                label: Text(
                  _register ? 'Đăng ký bằng Google' : 'Đăng nhập bằng Google',
                ),
              ),
              const SizedBox(height: 12),
              if (_register) ...[
                TextFormField(
                  controller: _displayName,
                  enabled: !_busy,
                  maxLength: 50,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(
                    labelText: 'Tên hiển thị',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 10),
              ],
              TextFormField(
                controller: _username,
                enabled: !_busy,
                maxLength: 30,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                validator: (value) =>
                    (value?.trim().length ?? 0) < (_register ? 3 : 1)
                    ? 'Nhập tên đăng nhập hợp lệ.'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Tên đăng nhập',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _password,
                enabled: !_busy,
                obscureText: !_visible,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: [
                  _register
                      ? AutofillHints.newPassword
                      : AutofillHints.password,
                ],
                validator: (value) => (value?.length ?? 0) < (_register ? 6 : 1)
                    ? (_register
                          ? 'Mật khẩu cần ít nhất 6 ký tự.'
                          : 'Nhập mật khẩu.')
                    : null,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!_busy) _submit();
                },
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  suffixIcon: IconButton(
                    tooltip: _visible ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                    onPressed: () => setState(() => _visible = !_visible),
                    icon: Icon(
                      _visible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              if (_error case final error?) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(
                  _busy
                      ? 'Đang xử lý…'
                      : (_register ? 'Tạo tài khoản' : 'Đăng nhập'),
                ),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _register = !_register;
                        _error = null;
                        _password.clear();
                        if (_register && _username.text == _loginUsername) {
                          _username.clear();
                        } else if (!_register && _username.text.isEmpty) {
                          _username.text = _loginUsername;
                        }
                      }),
                child: Text(
                  _register
                      ? 'Đã có tài khoản? Đăng nhập'
                      : 'Chưa có tài khoản? Đăng ký',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
