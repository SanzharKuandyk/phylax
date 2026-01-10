import 'dart:io';
import 'package:flutter/material.dart';

class PreviewResult {
  final double textX;
  final double textY;
  final double imageScale;
  final double imageOffsetX;
  final double imageOffsetY;

  PreviewResult({
    required this.textX,
    required this.textY,
    required this.imageScale,
    required this.imageOffsetX,
    required this.imageOffsetY,
  });
}

class PreviewScreen extends StatefulWidget {
  final String? imagePath;
  final String text;
  final double textX;
  final double textY;
  final double imageScale;
  final double imageOffsetX;
  final double imageOffsetY;

  const PreviewScreen({
    super.key,
    this.imagePath,
    required this.text,
    required this.textX,
    required this.textY,
    this.imageScale = 1.0,
    this.imageOffsetX = 0.0,
    this.imageOffsetY = 0.0,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late double _textX;
  late double _textY;
  late double _imageScale;
  late double _imageOffsetX;
  late double _imageOffsetY;

  // Track which element is being edited
  bool _editingImage = true;

  // For gesture tracking
  double _startScale = 1.0;
  double _startOffsetX = 0.0;
  double _startOffsetY = 0.0;
  Offset _lastFocalPoint = Offset.zero;

  @override
  void initState() {
    super.initState();
    _textX = widget.textX;
    _textY = widget.textY;
    _imageScale = widget.imageScale;
    _imageOffsetX = widget.imageOffsetX;
    _imageOffsetY = widget.imageOffsetY;
  }

  void _onScaleStart(ScaleStartDetails details) {
    _startScale = _imageScale;
    _startOffsetX = _imageOffsetX;
    _startOffsetY = _imageOffsetY;
    _lastFocalPoint = details.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!_editingImage || widget.imagePath == null) return;

    setState(() {
      // Calculate new scale
      final newScale = (_startScale * details.scale).clamp(0.5, 4.0);

      // Calculate pan delta from last focal point
      final delta = details.focalPoint - _lastFocalPoint;
      _lastFocalPoint = details.focalPoint;

      // Update offset with pan
      _imageOffsetX += delta.dx;
      _imageOffsetY += delta.dy;

      // Apply scale
      _imageScale = newScale;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final displayText = widget.text.isEmpty ? 'Stay Focused!' : widget.text;
    final hasImage = widget.imagePath != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(_editingImage && hasImage ? 'Pinch & drag image' : 'Drag text to position'),
        actions: [
          if (hasImage && _editingImage)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset image',
              onPressed: () {
                setState(() {
                  _imageScale = 1.0;
                  _imageOffsetX = 0.0;
                  _imageOffsetY = 0.0;
                });
              },
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(
                context,
                PreviewResult(
                  textX: _textX,
                  textY: _textY,
                  imageScale: _imageScale,
                  imageOffsetX: _imageOffsetX,
                  imageOffsetY: _imageOffsetY,
                ),
              );
            },
            child: const Text('Apply', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background - either transformable image or black
          if (hasImage)
            GestureDetector(
              onScaleStart: _editingImage ? _onScaleStart : null,
              onScaleUpdate: _editingImage ? _onScaleUpdate : null,
              child: Container(
                color: Colors.black,
                child: Transform(
                  transform: Matrix4.identity()
                    ..translate(
                      _imageOffsetX + size.width / 2,
                      _imageOffsetY + size.height / 2,
                    )
                    ..scale(_imageScale)
                    ..translate(-size.width / 2, -size.height / 2),
                  child: Image.file(
                    File(widget.imagePath!),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
            )
          else
            Container(color: Colors.black),

          // Draggable text - using FractionalTranslation to center on position point
          Positioned(
            left: _textX * size.width,
            top: _textY * size.height,
            child: FractionalTranslation(
              translation: const Offset(-0.5, -0.5),
              child: GestureDetector(
                onPanUpdate: !_editingImage
                    ? (details) {
                        setState(() {
                          _textX = ((_textX * size.width + details.delta.dx) / size.width).clamp(0.05, 0.95);
                          _textY = ((_textY * size.height + details.delta.dy) / size.height).clamp(0.05, 0.95);
                        });
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: !_editingImage ? Colors.yellow : Colors.white38,
                      width: !_editingImage ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    displayText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Mode toggle and instructions at bottom
          Positioned(
            bottom: 40,
            left: 16,
            right: 16,
            child: Column(
              children: [
                // Mode toggle buttons
                if (hasImage)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildModeButton('Image', Icons.image, _editingImage, () {
                        setState(() => _editingImage = true);
                      }),
                      const SizedBox(width: 16),
                      _buildModeButton('Text', Icons.text_fields, !_editingImage, () {
                        setState(() => _editingImage = false);
                      }),
                    ],
                  ),
                const SizedBox(height: 16),
                // Instructions
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _editingImage && hasImage
                        ? 'Drag to move, pinch to zoom'
                        : 'Drag the text to position it',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
                // Scale indicator
                if (hasImage && _editingImage)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Scale: ${(_imageScale * 100).toInt()}%  Offset: (${_imageOffsetX.toInt()}, ${_imageOffsetY.toInt()})',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.black54,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white38),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.black : Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
