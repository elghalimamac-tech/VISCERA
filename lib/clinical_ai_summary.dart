import 'biological_followup.dart';
import 'models.dart';

/// Aperçu remis au médecin AVANT tout envoi externe.
/// Aucun nom, ID de dossier, date de naissance ou date exacte des prélèvements.
String buildClinicalAiSummary(PatientCase patient, {DateTime? referenceDate}) {
  final today = referenceDate ?? DateTime.now();
  final buffer = StringBuffer();
  final age = int.tryParse(patient.age);
  final bracket = age == null || age < 0 || age > 125
      ? 'non précisé'
      : '${(age ~/ 10) * 10}–${(age ~/ 10) * 10 + 9} ans';
  buffer.writeln('CHIRURGIE VISCÉRALE — SYNTHÈSE À RELIRE ET ANONYMISER');
  buffer.writeln('Tranche d’âge : $bracket');
  buffer.writeln('Phase : ${patient.stage.label}');
  if (patient.effectiveProcedure.trim().isNotEmpty) {
    buffer.writeln('Intervention / contexte : '
      '${_redact(patient.effectiveProcedure, patient)}');
  }
  if (patient.cfsScore != null) {
    buffer.writeln('Clinical Frailty Scale : ${patient.cfsScore}');
  }
  if (patient.asaClass.isNotEmpty) {
    buffer.writeln('ASA : ${_redact(patient.asaClass, patient)}');
  }
  for (final score in patient.clinicalScores.entries) {
    final record = score.value;
    if (record is! Map || record['value'] == null) continue;
    final key = score.key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final value = record['value'].toString();
    if (value.length <= 15) {
      buffer.writeln('Score $key : ${_redact(value, patient)}');
    }
  }
  void section(String label, String value) {
    final cleaned = _redact(value, patient);
    if (cleaned.trim().isNotEmpty) buffer.writeln('$label : $cleaned');
  }
  section('Motif', patient.motive);
  section('Antécédents utiles', patient.history);
  section('Examen initial', patient.exam);
  section('Examens complémentaires', patient.investigations);
  final entries = [...patient.dailyObservations]
    ..sort((a,b)=>b.date.compareTo(a.date));
  for (final note in entries.take(5)) {
    final d = DateTime(note.date.year, note.date.month, note.date.day);
    final now = DateTime(today.year, today.month, today.day);
    final days = now.difference(d).inDays;
    buffer.writeln('Observation ${days >= 0 ? "J-$days" : "date à contrôler"} :');
    final values = <String>[];
    for (final field in biologyFields) {
      final value = note.biology[field.key];
      if (value == null || !value.isFinite) continue;
      values.add('${field.label}: ${field.displayStored(value)} ${field.unit}');
    }
    if (values.isNotEmpty) buffer.writeln('Biologie : ${values.join(" ; ")}');
    section('Constantes', note.vitals);
    section('Symptômes', note.symptoms);
    section('Examen', note.clinicalExam);
    section('Résultats complémentaires', note.results);
    section('Prise en charge déjà notée', note.plan);
  }
  buffer.writeln('Les valeurs manquantes ne doivent pas être extrapolées.');
  return buffer.toString().trim();
}

/// Détection simple non exhaustive ; la relecture du médecin reste obligatoire.
String _redact(String raw, PatientCase patient) {
  var cleaned = raw;
  for (final known in [patient.name, patient.id]) {
    final value = known.trim();
    if (value.length >= 3) {
      cleaned = cleaned.replaceAll(
        RegExp(RegExp.escape(value), caseSensitive:false), '[masqué]');
    }
  }
  cleaned = cleaned.replaceAll(
    RegExp(r'[\w.+-]+@[\w.-]+\.[a-zA-Z]{2,}'), '[e-mail masqué]');
  cleaned = cleaned.replaceAll(
    RegExp(r'\b(?:\+?212|0)[5-7][0-9 .-]{8,13}\b'),
    '[téléphone masqué]');
  cleaned = cleaned.replaceAll(
    RegExp(r'\b(?:19|20)\d{2}[-/]\d{2}[-/]\d{2}\b'),
    '[date masquée]');
  cleaned = cleaned.replaceAll(
    RegExp(r'\b\d{2}[-/]\d{2}[-/]\d{4}\b'), '[date masquée]');
  return cleaned.length > 450 ? '${cleaned.substring(0,450)}…' : cleaned;
}
