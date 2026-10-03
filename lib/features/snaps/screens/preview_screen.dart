import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';
import 'package:fitbuddy/features/snaps/snap_verification_service.dart';

class PreviewScreen extends StatefulWidget {
  final String? imagePath;

  const PreviewScreen({super.key, this.imagePath});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  String? _selectedActivity;
  final TextEditingController _captionController = TextEditingController();
  bool _postToFeed = true;

  final List<String> _activities = [
    'Workout', 'Running', 'Yoga', 'Walking', 
    'Cycling', 'Gym', 'Stretching', 'Sports'
  ];

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  // ... (inside _PreviewScreenState)
  SnapVerificationState _verificationState = SnapVerificationState.idle;
  String? _rejectionReason;
  final SnapVerificationService _verificationService = MockSnapVerificationService();

  Future<void> _sendSnap() async {
    if (_selectedActivity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an activity tag')),
      );
      return;
    }

    if (widget.imagePath == null) return;

    setState(() {
      _verificationState = SnapVerificationState.sending;
      _rejectionReason = null;
    });

    try {
      final targetPath = '${widget.imagePath}_compressed.jpg';
      final compressedImage = await FlutterImageCompress.compressAndGetFile(
        widget.imagePath!,
        targetPath,
        quality: 80,
        minWidth: 1280,
        minHeight: 1280,
        keepExif: false,
      );

      if (compressedImage == null) throw Exception('Failed to compress image');

      // Pre-check
      final passesPreCheck = await _verificationService.preCheckImage(targetPath);
      if (!passesPreCheck) {
        // We could warn the user here, but the spec says it's only a hint
      }

      setState(() => _verificationState = SnapVerificationState.verifying);

      final result = await _verificationService.submitForVerification(targetPath, _selectedActivity!);

      if (mounted) {
        if (result['status'] == 'verified') {
          setState(() => _verificationState = SnapVerificationState.verified);
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) context.pop();
        } else {
          setState(() {
            _verificationState = SnapVerificationState.rejected;
            _rejectionReason = result['reason'];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _verificationState = SnapVerificationState.idle;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imagePath == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Preview Error')),
        body: const Center(child: Text('No image provided.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_verificationState == SnapVerificationState.idle)
            TextButton(
              onPressed: _sendSnap,
              child: const Text('Send', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The photo
          if (kIsWeb)
            Image.network(widget.imagePath!, fit: BoxFit.cover)
          else
            Image.file(File(widget.imagePath!), fit: BoxFit.cover),
          
          // Gradient overlay at bottom for readable text
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: 400,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.black54, Colors.transparent],
                ),
              ),
            ),
          ),

          // Controls overlay
          Positioned(
            bottom: 24, left: 16, right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Activity Chips
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _activities.length,
                    itemBuilder: (context, index) {
                      final act = _activities[index];
                      final isSelected = _selectedActivity == act;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(act),
                          selected: isSelected,
                          onSelected: (val) {
                            setState(() => _selectedActivity = val ? act : null);
                          },
                          selectedColor: Colors.blue,
                          backgroundColor: Colors.white24,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                
                // Caption input
                TextField(
                  controller: _captionController,
                  style: const TextStyle(color: Colors.white),
                  maxLength: 140,
                  decoration: InputDecoration(
                    hintText: 'Add a caption...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.black45,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    counterStyle: const TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 8),

                // Feed toggle
                SwitchListTile(
                  title: const Text('Post to Friends Feed', style: TextStyle(color: Colors.white)),
                  value: _postToFeed,
                  onChanged: (val) => setState(() => _postToFeed = val),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: Colors.blue,
                ),
              ],
            ),
          ),

          if (_verificationState != SnapVerificationState.idle)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_verificationState == SnapVerificationState.sending || _verificationState == SnapVerificationState.verifying)
                      const CircularProgressIndicator(color: Colors.blue),
                    if (_verificationState == SnapVerificationState.verified)
                      const Icon(Icons.check_circle, color: Colors.green, size: 64),
                    if (_verificationState == SnapVerificationState.rejected)
                      const Icon(Icons.error, color: Colors.red, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      _verificationState == SnapVerificationState.sending ? 'Processing Snap...' :
                      _verificationState == SnapVerificationState.verifying ? 'Verifying Exercise...' :
                      _verificationState == SnapVerificationState.verified ? 'Verified & Sent!' :
                      'Snap Rejected',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    if (_verificationState == SnapVerificationState.rejected && _rejectionReason != null)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          _rejectionReason!,
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (_verificationState == SnapVerificationState.rejected)
                      ElevatedButton(
                        onPressed: () => setState(() => _verificationState = SnapVerificationState.idle),
                        child: const Text('Retake'),
                      )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
