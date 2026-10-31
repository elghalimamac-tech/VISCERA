import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Dictée courte dans un champ, jamais enregistrée automatiquement.
/// La reconnaissance du système peut utiliser un service distant :
/// exclusivement des données de démonstration avant validation institutionnelle.
class VoiceDictationService {
  VoiceDictationService._();
  static final instance = VoiceDictationService._();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final ValueNotifier<String?> active = ValueNotifier<String?>(null);
  bool _initialized = false;

  Future<String?> toggle(String fieldId, TextEditingController controller) async {
    if (active.value == fieldId) {
      await _speech.stop();
      active.value = null;
      return null;
    }
    if (active.value != null) {
      await _speech.stop();
      active.value = null;
    }
    try {
      if (!_initialized) {
        final available = await _speech.initialize(
          onStatus: (status) {
            if (status == 'done' || status == 'notListening') active.value = null;
          },
          onError: (_) => active.value = null,
        );
        if (!available) return 'Microphone ou reconnaissance vocale indisponible. Vous pouvez saisir le texte au clavier.';
        _initialized = true;
      }
      final prefix = controller.text.trimRight();
      final separator = prefix.isEmpty ? '' : ' ';
      active.value = fieldId;
      await _speech.listen(
        localeId: 'fr_FR',
        listenFor: const Duration(seconds: 45),
        pauseFor: const Duration(seconds: 5),
        listenOptions: stt.SpeechListenOptions(partialResults: true),
        onResult: (result) {
          if (active.value != fieldId) return;
          final recognized = result.recognizedWords.trim();
          controller.value = TextEditingValue(
            text: '$prefix$separator$recognized',
            selection: TextSelection.collapsed(offset: ('$prefix$separator$recognized').length),
          );
        },
      );
      return null;
    } catch (_) {
      active.value = null;
      return 'La dictée n’a pas pu démarrer. Vérifiez les autorisations et la disponibilité du français.';
    }
  }

  Future<void> stopIfActive(String fieldId) async {
    if (active.value == fieldId) {
      await _speech.stop();
      active.value = null;
    }
  }
}

/// Champ réutilisable dans les formulaires cliniques et observations.
class VoiceClinicalField extends StatefulWidget {
  const VoiceClinicalField({super.key, required this.label, required this.controller,
    this.maxLines = 3, this.hint, this.readOnly = false});
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final String? hint;
  final bool readOnly;
  @override State<VoiceClinicalField> createState() => _VoiceClinicalFieldState();
}

class _VoiceClinicalFieldState extends State<VoiceClinicalField> {
  late final String id = 'voice-${identityHashCode(this)}';
  @override void dispose() {
    VoiceDictationService.instance.stopIfActive(id);
    super.dispose();
  }
  @override Widget build(BuildContext context) => ValueListenableBuilder<String?>(
    valueListenable: VoiceDictationService.instance.active,
    builder: (context, active, _) {
      final listening = active == id;
      return TextField(
        controller: widget.controller,
        readOnly: widget.readOnly,
        minLines: widget.maxLines > 1 ? 2 : 1,
        maxLines: widget.maxLines,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          alignLabelWithHint: true,
          suffixIcon: widget.readOnly ? null : IconButton(
            tooltip: listening ? 'Arrêter la dictée' : 'Dicter en français (à relire)',
            icon: Icon(listening ? Icons.stop_circle_outlined : Icons.mic_none_rounded,
              color: listening ? Colors.red.shade700 : const Color(0xFF173A36)),
            onPressed: () async {
              final issue = await VoiceDictationService.instance.toggle(id, widget.controller);
              if (issue != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(issue)));
              }
            },
          ),
        ),
      );
    },
  );
}
