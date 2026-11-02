import 'package:flutter/material.dart';
import 'branding.dart';

/// Splash de chargement réellement lié à l'initialisation de VISCERA.
/// La barre est indéterminée : aucun pourcentage artificiel ni délai ajouté.
class VisceraBootSplash extends StatelessWidget {
  const VisceraBootSplash({
    super.key,
    this.message = 'Initialisation sécurisée…',
  });

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5FAFB),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const VisceraMark(size: 108),
                const SizedBox(height: 18),
                const Text(
                  'VISCERA',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF083B46),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'CHIRURGIE VISCÉRALE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF617A80),
                  ),
                ),
                const SizedBox(height: 37),
                SizedBox(
                  width: 254,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: const LinearProgressIndicator(
                      minHeight: 7,
                      backgroundColor: Color(0xFFDFEFF1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF13B8B0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Color(0xFF617A80),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
