/**
 * VISCERA — passerelle Gmail vers Supabase.
 * À coller dans https://script.google.com en étant connecté à elghali.araqi@gmail.com.
 * Les identifiants sont dans les propriétés du script, jamais dans ce fichier.
 *
 * Propriétés requises :
 * VISCERA_BLOC_ENDPOINT = https://qkupckqgczdqiwxozxko.supabase.co/functions/v1/bloc-gmail-ingest
 * VISCERA_BLOC_INGEST_KEY = secret aléatoire identique à celui de Supabase
 */
function syncBlocPrograms() {
  const properties = PropertiesService.getScriptProperties();
  const endpoint = properties.getProperty('VISCERA_BLOC_ENDPOINT');
  const key = properties.getProperty('VISCERA_BLOC_INGEST_KEY');
  if (!endpoint || !key || key.length < 32) {
    throw new Error('Configuration de la connexion VISCERA manquante.');
  }
  if (!/^https:\/\/qkupckqgczdqiwxozxko\.supabase\.co\/functions\/v1\/bloc-gmail-ingest$/.test(endpoint)) {
    throw new Error('Adresse de destination VISCERA non autorisée.');
  }

  const lock = LockService.getScriptLock();
  if (!lock.tryLock(1000)) return;
  try {
    const threads = GmailApp.search(
      'from:bloc.operatoire@hm6.ma newer_than:15d has:attachment', 0, 60);
    const messages = [];
    threads.forEach(function(thread) {
      thread.getMessages().forEach(function(message) {
        if (/PROGRAMME OPERATOIR/i.test(message.getSubject()) &&
            /bloc\.operatoire@hm6\.ma/i.test(message.getFrom())) {
          messages.push(message);
        }
      });
    });
    messages.sort(function(a, b) { return a.getDate() - b.getDate(); });

    messages.forEach(function(message) {
      message.getAttachments({includeInlineImages: false, includeAttachments: true})
        .forEach(function(attachment) {
          const filename = attachment.getName();
          if (!/^PROGRAMME PREVU DU \d{2}-\d{2}-\d{4}\.xlsx$/i.test(filename)) return;
          const doneKey = 'synced_' + message.getId() + '_' + filename;
          if (properties.getProperty(doneKey)) return;
          const payload = {
            message_id: message.getId(),
            filename: filename,
            received_at: message.getDate().toISOString(),
            base64: Utilities.base64Encode(attachment.getBytes())
          };
          const response = UrlFetchApp.fetch(endpoint, {
            method: 'post',
            contentType: 'application/json',
            payload: JSON.stringify(payload),
            headers: {'x-viscera-ingest-key': key},
            muteHttpExceptions: true
          });
          const status = response.getResponseCode();
          if (status !== 200) {
            // Ne pas enregistrer de données nominatives dans les journaux.
            console.error('Échec de synchronisation VISCERA. Statut HTTP : ' + status);
            return;
          }
          const result = JSON.parse(response.getContentText());
          if (['imported', 'duplicate', 'stale'].indexOf(result.status) !== -1) {
            properties.setProperty(doneKey, '1');
            console.log('Programme synchronisé : ' + result.date + ' (' + result.status + ')');
          }
        });
    });
  } finally {
    lock.releaseLock();
  }
}

/** À exécuter UNE seule fois après avoir défini les propriétés du script. */
function installVisceraSync() {
  ScriptApp.getProjectTriggers().forEach(function(t) {
    if (t.getHandlerFunction() === 'syncBlocPrograms') ScriptApp.deleteTrigger(t);
  });
  ScriptApp.newTrigger('syncBlocPrograms').timeBased().everyMinutes(15).create();
  syncBlocPrograms(); // Premier import après autorisation de Gmail/URLFetch.
}
