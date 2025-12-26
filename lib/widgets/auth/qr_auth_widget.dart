import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../presentation/providers/app_providers.dart';
import '../common/error_container.dart';
import '../common/loading_button.dart';

class QrAuthWidget extends ConsumerStatefulWidget {
  const QrAuthWidget({super.key});

  @override
  ConsumerState<QrAuthWidget> createState() => _QrAuthWidgetState();
}

class _QrAuthWidgetState extends ConsumerState<QrAuthWidget> {
  bool _showScanner = false;
  MobileScannerController? _scannerController;

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue != null) {
      final link = barcode!.rawValue!;
      if (link.startsWith('tg://login')) {
        _scannerController?.stop();
        setState(() => _showScanner = false);
        ref.confirmQrCode(link);
      }
    }
  }

  void _startScanner() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
    setState(() => _showScanner = true);
  }

  void _stopScanner() {
    _scannerController?.dispose();
    _scannerController = null;
    setState(() => _showScanner = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showScanner && _isMobile) {
      return _buildScannerView(context);
    }
    return _isMobile ? _buildMobileView(context) : _buildDesktopView(context);
  }

  Widget _buildScannerView(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _stopScanner,
        ),
        title: const Text('Scan QR Code'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onBarcodeDetected,
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.primary, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 16,
            right: 16,
            child: Text(
              'Point at QR code on another Telegram device',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileView(BuildContext context) {
    final errorMessage = ref.errorMessage;
    final isLoading = ref.isLoading;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Scan QR Code',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              ErrorContainer(
                message: errorMessage,
                padding: const EdgeInsets.all(12),
                borderRadius: 8,
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: LoadingButton(
                label: 'Open Camera',
                onPressed: _startScanner,
                isLoading: isLoading,
                height: 50,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopView(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final errorMessage = ref.errorMessage;
    final isLoading = ref.isLoading;
    final qrCodeInfo = ref.qrCodeInfo;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code, size: 48, color: colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            'QR Code Authentication',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Scan this QR code with Telegram on your phone',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (qrCodeInfo != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outline),
              ),
              child: Column(
                children: [
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.qr_code,
                        size: 64,
                        color: colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Waiting for confirmation...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.secondary,
                        ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.smartphone,
                    size: 64,
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text('Generate QR Code',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            ErrorContainer(
              message: errorMessage,
              padding: const EdgeInsets.all(12),
              borderRadius: 8,
            ),
          ],
          const SizedBox(height: 32),
          LoadingButton(
            label: qrCodeInfo != null ? 'Generate New QR Code' : 'Generate QR Code',
            onPressed: () => ref.requestQrCode(),
            isLoading: isLoading,
            height: 50,
          ),
        ],
      ),
    );
  }
}
