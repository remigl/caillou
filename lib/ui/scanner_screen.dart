import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/off/off_api.dart';
import 'product_screen.dart';

/// Lecture d'un code-barres alimentaire (EAN-13, EAN-8, UPC).
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE],
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final b in capture.barcodes) {
      final code = OffApi.cleanBarcode(b.rawValue ?? '');
      if (code != null) {
        _open(code);
        return;
      }
    }
  }

  void _open(String code) {
    if (_handled || !mounted) return;
    _handled = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => ProductScreen(barcode: code)),
    );
  }

  Future<void> _manualEntry() async {
    final textController = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Saisir le code-barres'),
        content: TextField(
          controller: textController,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Ex. 3017620422003'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(context).pop(textController.text), child: const Text('Rechercher')),
        ],
      ),
    );
    textController.dispose();
    if (code == null || !mounted) return;
    final clean = OffApi.cleanBarcode(code);
    if (clean == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code-barres invalide (6 à 14 chiffres).')),
      );
      return;
    }
    _open(clean);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scanner un produit'),
        actions: [
          IconButton(
            tooltip: 'Lampe',
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        // Zone de lecture : seuls les codes-barres entièrement dans le cadre sont pris en compte.
        final size = constraints.biggest;
        final width = (size.width - 48).clamp(200.0, 340.0).toDouble();
        final window = Rect.fromCenter(
          center: Offset(size.width / 2, size.height * 0.42),
          width: width,
          height: width * 0.55,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(controller: _controller, onDetect: _onDetect, scanWindow: window),
            IgnorePointer(child: CustomPaint(painter: _ScanWindowPainter(window))),
            Positioned(
              left: 24,
              right: 24,
              top: window.bottom + 20,
              child: const Text(
                'Placez le code-barres dans le cadre',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 32,
              child: Center(
                child: FilledButton.tonalIcon(
                  onPressed: _manualEntry,
                  icon: const Icon(Icons.keyboard),
                  label: const Text('Saisir le code'),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// Assombrit tout sauf le cadre de lecture.
class _ScanWindowPainter extends CustomPainter {
  const _ScanWindowPainter(this.window);
  final Rect window;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = RRect.fromRectAndRadius(window, const Radius.circular(20));
    final outside = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(frame)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(outside, Paint()..color = const Color(0x99000000));
    canvas.drawRRect(
      frame,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_ScanWindowPainter old) => old.window != window;
}
