import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Identité VISCERA commune à Android, iOS et Flutter Web.
/// Les deux variantes SVG utilisent exactement les mêmes tracés.
class VisceraMark extends StatelessWidget {
  const VisceraMark({super.key, this.size = 32, this.onDark = false});
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'VISCERA',
    image: true,
    child: SvgPicture.asset(
      onDark
          ? 'assets/branding/viscera-symbol-light.svg'
          : 'assets/branding/viscera-symbol.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    ),
  );
}

/// Logo et signature institutionnelle pour l'authentification, splash et menus.
class VisceraBrandLockup extends StatelessWidget {
  const VisceraBrandLockup({
    super.key,
    this.onDark = false,
    this.markSize = 46,
    this.subtitle = 'HUIM6 BOUSKOURA · CHIRURGIE VISCÉRALE',
  });
  final bool onDark;
  final double markSize;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final mainColor = onDark ? Colors.white : const Color(0xFF083B46);
    final subtitleColor = onDark ? const Color(0xFFEAF6F7) : const Color(0xFF617A80);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        VisceraMark(size: markSize, onDark: onDark),
        const SizedBox(width: 11),
        Flexible(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('VISCERA', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: mainColor, fontSize: markSize * .52,
                fontWeight: FontWeight.w900, letterSpacing: .8)),
            if (subtitle != null && subtitle!.isNotEmpty)
              Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: subtitleColor, fontSize: 10,
                  fontWeight: FontWeight.w600, letterSpacing: .5)),
          ],
        )),
      ],
    );
  }
}

/// Même marque en miniature dans les barres de navigation internes.
class VisceraPageTitle extends StatelessWidget {
  const VisceraPageTitle(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const VisceraMark(size: 25),
      const SizedBox(width: 10),
      Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
    ],
  );
}
