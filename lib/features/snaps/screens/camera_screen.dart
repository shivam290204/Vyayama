import 'dart:async';

import 'package:camera/camera.dart';
import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/friends/widgets/async_body.dart';
import 'package:fitbuddy/features/snaps/data/snap.dart';
import 'package:fitbuddy/features/snaps/providers.dart';
import 'package:fitbuddy/features/snaps/send_snap_controller.dart';
import 'package:fitbuddy/features/snaps/widgets/camera_controls.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _CamState { loading, ready, denied, unavailable }

/// `/snaps/camera`: full-screen in-app camera. No gallery picker, by design.
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key, this.toFriendId});

  final String? toFriendId;

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  static const _consentKey = 'snap_camera_consent_v1';

  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _index = 0;
  _CamState _state = _CamState.loading;
  FlashMode _flash = FlashMode.off;
  int _timer = 0;
  int? _countdown;
  Timer? _ticker;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (mounted) ref.read(sendSnapControllerProvider.notifier).reset();
    });
    if (!kIsWeb) _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed &&
        _cameras.isNotEmpty &&
        _controller == null) {
      _open();
    }
  }

  Future<bool> _consent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_consentKey) ?? false) return true;
      if (!mounted) return false;
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Before you snap'),
          content: const Text(
            'Photos of you are personal data. Your snap goes only to the friends you pick, '
            'is stored privately and is deleted after 24 hours. We use an AI check to see '
            'whether it looks like exercise. It is not proof of effort.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Not now')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('I agree')),
          ],
        ),
      );
      if (ok == true) await prefs.setBool(_consentKey, true);
      return ok ?? false;
    } catch (_) {
      return true;
    }
  }

  Future<void> _start() async {
    if (!await _consent()) {
      if (mounted) _close();
      return;
    }
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _state = _CamState.unavailable);
        return;
      }
      final back = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      _index = back < 0 ? 0 : back;
      await _open();
    } on CameraException catch (e) {
      _fail(e);
    }
  }

  void _fail(CameraException e) {
    if (!mounted) return;
    setState(() => _state =
        e.code.startsWith('CameraAccess') ? _CamState.denied : _CamState.unavailable);
  }

  Future<void> _open() async {
    final old = _controller;
    final controller = CameraController(
      _cameras[_index],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = controller;
    await old?.dispose();
    try {
      await controller.initialize();
      await controller.setFlashMode(_flash);
      if (mounted) setState(() => _state = _CamState.ready);
    } on CameraException catch (e) {
      _fail(e);
    }
  }

  void _close() => context.canPop() ? context.pop() : context.go(AppRoutes.home);

  Future<void> _cycleFlash() async {
    const order = [FlashMode.off, FlashMode.auto, FlashMode.always];
    final next = order[(order.indexOf(_flash) + 1) % order.length];
    try {
      await _controller?.setFlashMode(next);
      setState(() => _flash = next);
    } on CameraException {
      // Some cameras (for example the front one) have no flash.
    }
  }

  void _cycleTimer() => setState(() => _timer = _timer == 0 ? 3 : (_timer == 3 ? 10 : 0));

  Future<void> _flip() async {
    if (_cameras.length < 2) return;
    _index = (_index + 1) % _cameras.length;
    setState(() => _state = _CamState.loading);
    await _open();
  }

  void _onCapture() {
    if (_timer == 0) {
      _capture();
      return;
    }
    setState(() => _countdown = _timer);
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = (_countdown ?? 1) - 1;
      if (left <= 0) {
        t.cancel();
        setState(() => _countdown = null);
        _capture();
      } else {
        setState(() => _countdown = left);
      }
    });
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _busy) return;
    _busy = true;
    try {
      final file = await c.takePicture();
      final bytes = await file.readAsBytes();
      ref.read(capturedPhotoProvider.notifier).set(CapturedPhoto(path: file.path, bytes: bytes));
      if (!mounted) return;
      final to = widget.toFriendId;
      await context.push(to == null
          ? AppRoutes.snapsPreview
          : '${AppRoutes.snapsPreview}?to=$to');
    } on CameraException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not take the photo. Try again.')),
        );
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: _close)),
        body: const StateMessage(
          icon: Icons.phone_iphone,
          title: 'Snaps need the mobile app',
          message: 'Open Vyayama on your phone to take an exercise photo.',
        ),
      );
    }
    if (_state == _CamState.denied || _state == _CamState.unavailable) {
      final denied = _state == _CamState.denied;
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: _close)),
        body: StateMessage(
          icon: Icons.no_photography_outlined,
          title: denied ? 'Camera access is off' : 'No camera found',
          message: denied
              ? 'Vyayama needs your camera to take exercise snaps. You can turn it on in your settings.'
              : 'We could not start a camera on this device.',
          actionLabel: denied ? 'Open settings' : 'Go back',
          onAction: denied ? openAppSettings : _close,
        ),
      );
    }
    final c = _controller;
    final ready = _state == _CamState.ready && c != null && c.value.isInitialized;
    return Scaffold(
      backgroundColor: scheme.scrim,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (ready)
              Center(child: CameraPreview(c))
            else
              const Center(child: CircularProgressIndicator()),
            if (_countdown != null)
              Center(
                child: Semantics(
                  liveRegion: true,
                  child: Text('$_countdown',
                      style: Theme.of(context).textTheme.displayLarge),
                ),
              ),
            Align(
              alignment: Alignment.topCenter,
              child: CameraTopBar(flash: _flash, onFlash: _cycleFlash, onClose: _close),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: CameraBottomBar(
                timerSeconds: _timer,
                enabled: ready && _countdown == null,
                onTimer: _cycleTimer,
                onCapture: _onCapture,
                onFlip: _flip,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
