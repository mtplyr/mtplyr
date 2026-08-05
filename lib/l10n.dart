import 'package:flutter/widgets.dart';
import 'xtream.dart';

/// Leichtgewichtige App-Lokalisierung ohne Codegen.
/// Reihenfolge der Werte je Schlüssel: [de, en, tr, ar, fr, it, el].

const List<List<String>> kLangs = [
  ['de', '🇩🇪  Deutsch'],
  ['en', '🇬🇧  English'],
  ['tr', '🇹🇷  Türkçe'],
  ['ar', '🇸🇦  العربية'],
  ['fr', '🇫🇷  Français'],
  ['it', '🇮🇹  Italiano'],
  ['el', '🇬🇷  Ελληνικά'],
];

const List<String> _order = ['de', 'en', 'tr', 'ar', 'fr', 'it', 'el'];

/// Bei Sprachwechsel erhöhen → App baut neu (siehe VelaApp).
final ValueNotifier<int> langTick = ValueNotifier<int>(0);

class L {
  static int get _i {
    final i = _order.indexOf(Prefs.lang);
    return i < 0 ? 0 : i;
  }

  static String t(String key) {
    final row = _m[key];
    if (row == null) return key;
    final v = _i < row.length ? row[_i] : '';
    return v.isEmpty ? row[0] : v;
  }

  static Future<void> set(String code) async {
    await Prefs.setLang(code);
    langTick.value++;
  }

  static String nameOf(String code) {
    for (final l in kLangs) {
      if (l[0] == code) return l[1];
    }
    return code;
  }

  static const Map<String, List<String>> _m = {
    // Verbinden
    'connect_title': ['Playlist verbinden', 'Connect playlist', 'Oynatma listesi bağla', 'ربط قائمة التشغيل', 'Connecter la playlist', 'Collega playlist', 'Σύνδεση λίστας'],
    'connect_sub': ['Gib deine Xtream-Zugangsdaten ein.', 'Enter your Xtream credentials.', 'Xtream bilgilerinizi girin.', 'أدخل بيانات Xtream الخاصة بك.', 'Saisissez vos identifiants Xtream.', 'Inserisci le tue credenziali Xtream.', 'Εισάγετε τα στοιχεία Xtream σας.'],
    'connect_server': ['Server (http://host:port)', 'Server (http://host:port)', 'Sunucu (http://host:port)', 'الخادم (http://host:port)', 'Serveur (http://host:port)', 'Server (http://host:port)', 'Διακομιστής (http://host:port)'],
    'username': ['Benutzername', 'Username', 'Kullanıcı adı', 'اسم المستخدم', 'Nom d\'utilisateur', 'Nome utente', 'Όνομα χρήστη'],
    'password': ['Passwort', 'Password', 'Şifre', 'كلمة المرور', 'Mot de passe', 'Password', 'Κωδικός'],
    'connect_btn': ['Verbinden', 'Connect', 'Bağlan', 'اتصال', 'Connecter', 'Connetti', 'Σύνδεση'],
    'connect_err': ['Verbindung fehlgeschlagen – Zugangsdaten prüfen.', 'Connection failed – check your credentials.', 'Bağlantı başarısız – bilgileri kontrol edin.', 'فشل الاتصال – تحقق من البيانات.', 'Échec de la connexion – vérifiez vos identifiants.', 'Connessione fallita – controlla le credenziali.', 'Αποτυχία σύνδεσης – ελέγξτε τα στοιχεία.'],
    // Home
    'home_live': ['Live-TV', 'Live TV', 'Canlı TV', 'البث المباشر', 'TV en direct', 'TV in diretta', 'Ζωντανή TV'],
    'home_live_sub': ['Fernsehen live', 'Live television', 'Canlı yayın', 'تلفزيون مباشر', 'Télévision en direct', 'Televisione dal vivo', 'Ζωντανή τηλεόραση'],
    'home_movies': ['Filme', 'Movies', 'Filmler', 'أفلام', 'Films', 'Film', 'Ταινίες'],
    'home_movies_sub': ['Spielfilme', 'Feature films', 'Sinema filmleri', 'أفلام سينمائية', 'Longs métrages', 'Lungometraggi', 'Ταινίες'],
    'home_series': ['Serien', 'Series', 'Diziler', 'مسلسلات', 'Séries', 'Serie TV', 'Σειρές'],
    'home_series_sub': ['Serien & Staffeln', 'Series & seasons', 'Diziler & sezonlar', 'مسلسلات ومواسم', 'Séries & saisons', 'Serie & stagioni', 'Σειρές & σεζόν'],
    'home_replay': ['Replay', 'Replay', 'Tekrar', 'إعادة', 'Replay', 'Replay', 'Επανάληψη'],
    'home_replay_sub': ['Verpasstes nachholen', 'Catch up on what you missed', 'Kaçırdıklarını izle', 'شاهد ما فاتك', 'Rattraper vos programmes', 'Recupera ciò che hai perso', 'Δείτε όσα χάσατε'],
    // Live / Kategorien
    'live_title': ['Live-Sender', 'Live channels', 'Canlı kanallar', 'القنوات المباشرة', 'Chaînes en direct', 'Canali in diretta', 'Ζωντανά κανάλια'],
    'replay_pick': ['Replay – Sender wählen', 'Replay – choose channel', 'Tekrar – kanal seç', 'إعادة – اختر قناة', 'Replay – choisir une chaîne', 'Replay – scegli canale', 'Επανάληψη – επιλέξτε κανάλι'],
    'favorites': ['Favoriten', 'Favorites', 'Favoriler', 'المفضلة', 'Favoris', 'Preferiti', 'Αγαπημένα'],
    'err_load': ['Fehler beim Laden.', 'Error while loading.', 'Yükleme hatası.', 'خطأ أثناء التحميل.', 'Erreur de chargement.', 'Errore durante il caricamento.', 'Σφάλμα φόρτωσης.'],
    'search_in_cat': ['In Kategorie suchen…', 'Search in category…', 'Kategoride ara…', 'ابحث في الفئة…', 'Rechercher dans la catégorie…', 'Cerca nella categoria…', 'Αναζήτηση στην κατηγορία…'],
    'no_fav': ['Noch keine Favoriten', 'No favorites yet', 'Henüz favori yok', 'لا مفضلة بعد', 'Aucun favori pour l\'instant', 'Ancora nessun preferito', 'Δεν υπάρχουν αγαπημένα ακόμη'],
    'no_hits': ['Keine Treffer', 'No results', 'Sonuç yok', 'لا نتائج', 'Aucun résultat', 'Nessun risultato', 'Κανένα αποτέλεσμα'],
    'no_content': ['Keine Inhalte', 'No content', 'İçerik yok', 'لا محتوى', 'Aucun contenu', 'Nessun contenuto', 'Χωρίς περιεχόμενο'],
    // Suche
    'search_title': ['Suche', 'Search', 'Arama', 'بحث', 'Recherche', 'Cerca', 'Αναζήτηση'],
    'search_hint': ['Film oder Serie suchen…', 'Search movie or series…', 'Film veya dizi ara…', 'ابحث عن فيلم أو مسلسل…', 'Rechercher un film ou une série…', 'Cerca film o serie…', 'Αναζήτηση ταινίας ή σειράς…'],
    'search_min2': ['Mindestens 2 Zeichen eingeben', 'Enter at least 2 characters', 'En az 2 karakter girin', 'أدخل حرفين على الأقل', 'Saisissez au moins 2 caractères', 'Inserisci almeno 2 caratteri', 'Εισάγετε τουλάχιστον 2 χαρακτήρες'],
    // Detail
    'no_desc': ['Keine Beschreibung verfügbar.', 'No description available.', 'Açıklama yok.', 'لا يوجد وصف.', 'Aucune description disponible.', 'Nessuna descrizione disponibile.', 'Δεν υπάρχει περιγραφή.'],
    'play': ['Abspielen', 'Play', 'Oynat', 'تشغيل', 'Lire', 'Riproduci', 'Αναπαραγωγή'],
    'season': ['Staffel', 'Season', 'Sezon', 'الموسم', 'Saison', 'Stagione', 'Σεζόν'],
    'no_eps': ['Keine Folgen', 'No episodes', 'Bölüm yok', 'لا حلقات', 'Aucun épisode', 'Nessun episodio', 'Χωρίς επεισόδια'],
    'catchup_none': ['Keine aufgezeichneten Sendungen für diesen Sender', 'No recorded programs for this channel', 'Bu kanal için kayıt yok', 'لا برامج مسجلة لهذه القناة', 'Aucune émission enregistrée pour cette chaîne', 'Nessun programma registrato per questo canale', 'Δεν υπάρχουν εγγραφές για αυτό το κανάλι'],
    'minutes_short': ['Min', 'min', 'dk', 'دقيقة', 'min', 'min', 'λεπτά'],
    // Player
    'player_err': ['Wiedergabe nicht möglich – Sendung evtl. noch nicht im Archiv verfügbar.', 'Playback failed – program may not be archived yet.', 'Oynatılamıyor – yayın henüz arşivde olmayabilir.', 'تعذّر التشغيل – قد لا يكون البرنامج مؤرشفًا بعد.', 'Lecture impossible – l\'émission n\'est peut-être pas encore archivée.', 'Riproduzione non riuscita – il programma potrebbe non essere ancora in archivio.', 'Αδύνατη η αναπαραγωγή – ίσως δεν έχει αρχειοθετηθεί ακόμη.'],
    'now': ['Jetzt', 'Now', 'Şimdi', 'الآن', 'En ce moment', 'Ora', 'Τώρα'],
    'pick_audio': ['Audiospur wählen', 'Select audio track', 'Ses parçası seç', 'اختر المسار الصوتي', 'Choisir la piste audio', 'Seleziona traccia audio', 'Επιλογή ήχου'],
    'pick_subs': ['Untertitel wählen', 'Select subtitles', 'Altyazı seç', 'اختر الترجمة', 'Choisir les sous-titres', 'Seleziona sottotitoli', 'Επιλογή υποτίτλων'],
    'no_tracks': ['Keine Spuren verfügbar', 'No tracks available', 'Parça yok', 'لا مسارات متاحة', 'Aucune piste disponible', 'Nessuna traccia disponibile', 'Δεν υπάρχουν κομμάτια'],
    // Einstellungen
    'settings_title': ['Einstellungen', 'Settings', 'Ayarlar', 'الإعدادات', 'Paramètres', 'Impostazioni', 'Ρυθμίσεις'],
    's_stream_format': ['Stream-Format', 'Stream format', 'Yayın formatı', 'صيغة البث', 'Format de flux', 'Formato stream', 'Μορφή ροής'],
    's_buffer': ['Puffergröße', 'Buffer size', 'Tampon boyutu', 'حجم التخزين المؤقت', 'Taille du tampon', 'Dimensione buffer', 'Μέγεθος buffer'],
    's_subsize': ['Untertitelgröße', 'Subtitle size', 'Altyazı boyutu', 'حجم الترجمة', 'Taille des sous-titres', 'Dimensione sottotitoli', 'Μέγεθος υποτίτλων'],
    's_parental': ['Kindersicherung', 'Parental control', 'Ebeveyn kontrolü', 'الرقابة الأبوية', 'Contrôle parental', 'Controllo genitori', 'Γονικός έλεγχος'],
    's_hidden': ['Versteckte Kategorien', 'Hidden categories', 'Gizli kategoriler', 'الفئات المخفية', 'Catégories masquées', 'Categorie nascoste', 'Κρυφές κατηγορίες'],
    's_about': ['Über Vela', 'About Vela', 'Vela hakkında', 'حول Vela', 'À propos de Vela', 'Informazioni su Vela', 'Σχετικά με το Vela'],
    's_language': ['Sprache', 'Language', 'Dil', 'اللغة', 'Langue', 'Lingua', 'Γλώσσα'],
    'buffer_desc': ['Wie viel Video vorab geladen wird. Bei Rucklern/Nachladen: höher stellen.', 'How much video is preloaded. Increase if playback stutters.', 'Ne kadar videonun önceden yükleneceği. Takılmada artırın.', 'مقدار الفيديو المحمّل مسبقًا. زده عند التقطيع.', 'Quantité de vidéo préchargée. Augmentez en cas de saccades.', 'Quanto video viene precaricato. Aumenta se scatta.', 'Πόσο βίντεο προφορτώνεται. Αυξήστε αν κολλάει.'],
    'buf_low': ['Niedrig', 'Low', 'Düşük', 'منخفض', 'Faible', 'Basso', 'Χαμηλό'],
    'buf_default': ['Standard', 'Default', 'Varsayılan', 'افتراضي', 'Par défaut', 'Predefinito', 'Προεπιλογή'],
    'buf_high': ['Hoch', 'High', 'Yüksek', 'عالٍ', 'Élevé', 'Alto', 'Υψηλό'],
    'buf_extreme': ['Extrem', 'Extreme', 'Aşırı', 'أقصى', 'Extrême', 'Estremo', 'Ακραίο'],
    'subs_desc': ['Wie groß Untertitel angezeigt werden.', 'How large subtitles are displayed.', 'Altyazıların ne kadar büyük görüneceği.', 'حجم عرض الترجمة.', 'Taille d\'affichage des sous-titres.', 'Quanto grandi appaiono i sottotitoli.', 'Πόσο μεγάλοι εμφανίζονται οι υπότιτλοι.'],
    'sub_large': ['Groß', 'Large', 'Büyük', 'كبير', 'Grand', 'Grande', 'Μεγάλο'],
    'sub_normal': ['Normal', 'Normal', 'Normal', 'عادي', 'Normal', 'Normale', 'Κανονικό'],
    'sub_small': ['Klein', 'Small', 'Küçük', 'صغير', 'Petit', 'Piccolo', 'Μικρό'],
    'sf_title': ['Stream-Format (Live)', 'Stream format (Live)', 'Yayın formatı (Canlı)', 'صيغة البث (المباشر)', 'Format de flux (Direct)', 'Formato stream (Live)', 'Μορφή ροής (Ζωντανά)'],
    'sf_desc': ['Falls ein Sender nicht startet, das andere Format probieren.', 'If a channel won\'t start, try the other format.', 'Bir kanal başlamazsa diğer formatı deneyin.', 'إذا لم تبدأ قناة، جرّب الصيغة الأخرى.', 'Si une chaîne ne démarre pas, essayez l\'autre format.', 'Se un canale non parte, prova l\'altro formato.', 'Αν δεν ξεκινά ένα κανάλι, δοκιμάστε την άλλη μορφή.'],
    'sf_ts': ['TS (Standard)', 'TS (default)', 'TS (varsayılan)', 'TS (افتراضي)', 'TS (par défaut)', 'TS (predefinito)', 'TS (προεπιλογή)'],
    'sf_hls': ['HLS (m3u8)', 'HLS (m3u8)', 'HLS (m3u8)', 'HLS (m3u8)', 'HLS (m3u8)', 'HLS (m3u8)', 'HLS (m3u8)'],
    'parental_desc': ['Blendet XXX-/18+-Kategorien überall aus.', 'Hides XXX/18+ categories everywhere.', 'XXX/18+ kategorilerini her yerde gizler.', 'يخفي فئات XXX/18+ في كل مكان.', 'Masque partout les catégories XXX/18+.', 'Nasconde ovunque le categorie XXX/18+.', 'Κρύβει παντού κατηγορίες XXX/18+.'],
    'hide_adult': ['Erwachsenen-Inhalte ausblenden', 'Hide adult content', 'Yetişkin içeriğini gizle', 'إخفاء محتوى البالغين', 'Masquer le contenu adulte', 'Nascondi contenuti per adulti', 'Απόκρυψη περιεχομένου ενηλίκων'],
    'set_pin': ['PIN festlegen', 'Set PIN', 'PIN belirle', 'تعيين رمز PIN', 'Définir un code PIN', 'Imposta PIN', 'Ορισμός PIN'],
    'change_pin': ['PIN ändern', 'Change PIN', 'PIN değiştir', 'تغيير رمز PIN', 'Modifier le code PIN', 'Cambia PIN', 'Αλλαγή PIN'],
    'use_bio': ['Face ID / Touch ID verwenden', 'Use Face ID / Touch ID', 'Face ID / Touch ID kullan', 'استخدام Face ID / Touch ID', 'Utiliser Face ID / Touch ID', 'Usa Face ID / Touch ID', 'Χρήση Face ID / Touch ID'],
    'bio_enable': ['Face ID / Touch ID aktivieren', 'Enable Face ID / Touch ID', 'Face ID / Touch ID etkinleştir', 'تفعيل Face ID / Touch ID', 'Activer Face ID / Touch ID', 'Attiva Face ID / Touch ID', 'Ενεργοποίηση Face ID / Touch ID'],
    'bio_none': ['Keine Biometrie auf diesem Gerät verfügbar.', 'No biometrics available on this device.', 'Bu cihazda biyometri yok.', 'لا يوجد قياس حيوي على هذا الجهاز.', 'Aucune biométrie disponible sur cet appareil.', 'Nessuna biometria disponibile su questo dispositivo.', 'Δεν υπάρχει βιομετρία σε αυτή τη συσκευή.'],
    'bio_release': ['Zum Freigeben authentifizieren', 'Authenticate to unlock', 'Kilidi açmak için doğrulayın', 'تحقّق لإلغاء القفل', 'Authentifiez-vous pour déverrouiller', 'Autenticati per sbloccare', 'Πιστοποίηση για ξεκλείδωμα'],
    'pin_release': ['PIN zum Freigeben', 'PIN to unlock', 'Kilit açma PIN\'i', 'رمز PIN لإلغاء القفل', 'Code PIN pour déverrouiller', 'PIN per sbloccare', 'PIN για ξεκλείδωμα'],
    'pin_min': ['Mind. 4 Ziffern', 'At least 4 digits', 'En az 4 hane', '4 أرقام على الأقل', 'Au moins 4 chiffres', 'Almeno 4 cifre', 'Τουλάχιστον 4 ψηφία'],
    'cancel': ['Abbrechen', 'Cancel', 'İptal', 'إلغاء', 'Annuler', 'Annulla', 'Άκυρο'],
    'save': ['Speichern', 'Save', 'Kaydet', 'حفظ', 'Enregistrer', 'Salva', 'Αποθήκευση'],
    'favs_saved': ['gespeicherte Sender', 'saved channels', 'kayıtlı kanal', 'قنوات محفوظة', 'chaînes enregistrées', 'canali salvati', 'αποθηκευμένα κανάλια'],
    'favs_clear': ['Alle Favoriten löschen', 'Clear all favorites', 'Tüm favorileri sil', 'مسح كل المفضلة', 'Effacer tous les favoris', 'Cancella tutti i preferiti', 'Διαγραφή όλων των αγαπημένων'],
    'lang_desc': ['Sprache der App-Oberfläche.', 'App interface language.', 'Uygulama arayüz dili.', 'لغة واجهة التطبيق.', 'Langue de l\'interface.', 'Lingua dell\'interfaccia.', 'Γλώσσα διεπαφής.'],
    // Konto
    'account_title': ['Playlist-Info', 'Playlist info', 'Liste bilgisi', 'معلومات القائمة', 'Infos playlist', 'Info playlist', 'Πληροφορίες λίστας'],
    'logout': ['Abmelden', 'Log out', 'Çıkış yap', 'تسجيل الخروج', 'Se déconnecter', 'Esci', 'Αποσύνδεση'],
    'acc_status': ['Status', 'Status', 'Durum', 'الحالة', 'Statut', 'Stato', 'Κατάσταση'],
    'acc_connections': ['Verbindungen', 'Connections', 'Bağlantılar', 'الاتصالات', 'Connexions', 'Connessioni', 'Συνδέσεις'],
    'acc_expires': ['Läuft ab', 'Expires', 'Bitiş', 'تنتهي', 'Expire le', 'Scade', 'Λήγει'],
    'acc_trial': ['Testzugang', 'Trial', 'Deneme', 'تجريبي', 'Essai', 'Prova', 'Δοκιμή'],
    'acc_created': ['Erstellt am', 'Created', 'Oluşturuldu', 'أُنشئ في', 'Créé le', 'Creato il', 'Δημιουργήθηκε'],
    'type_live': ['Live', 'Live', 'Canlı', 'مباشر', 'Direct', 'Live', 'Ζωντανά'],
    'continue_watching': ['Weiterschauen', 'Continue watching', 'İzlemeye devam et', 'متابعة المشاهدة', 'Reprendre', 'Continua a guardare', 'Συνέχεια'],
    'retry': ['Erneut', 'Retry', 'Tekrar dene', 'إعادة', 'Réessayer', 'Riprova', 'Επανάληψη'],
    'welcome': ['Willkommen bei Vela', 'Welcome to Vela', 'Vela\'ya hoş geldin', 'مرحبًا بك في Vela', 'Bienvenue sur Vela', 'Benvenuto su Vela', 'Καλώς ήρθες στο Vela'],
    'activate_intro': ['So verbindest du deine Playlist:', 'How to connect your playlist:', 'Oynatma listeni şöyle bağlarsın:', 'كيف تربط قائمتك:', 'Comment connecter votre playlist :', 'Come collegare la playlist:', 'Πώς να συνδέσεις τη λίστα σου:'],
    'device_code': ['Dein Geräte-Code', 'Your device code', 'Cihaz kodun', 'رمز جهازك', 'Votre code appareil', 'Il tuo codice dispositivo', 'Ο κωδικός συσκευής σου'],
    'mac_address': ['MAC-Adresse', 'MAC address', 'MAC adresi', 'عنوان MAC', 'Adresse MAC', 'Indirizzo MAC', 'Διεύθυνση MAC'],
    'device_key_label': ['Geräteschlüssel', 'Device key', 'Cihaz anahtarı', 'مفتاح الجهاز', 'Clé appareil', 'Chiave dispositivo', 'Κλειδί συσκευής'],
    'activate_s1': ['Öffne im Browser', 'Open in your browser', 'Tarayıcıda aç', 'افتح في المتصفح', 'Ouvrez dans le navigateur', 'Apri nel browser', 'Άνοιξε στον browser'],
    'activate_s2': ['MAC + Schlüssel + deine M3U-/Xtream-Playlist eingeben', 'Enter MAC + key + your M3U/Xtream playlist', 'MAC + anahtar + M3U/Xtream listeni gir', 'أدخل MAC + المفتاح + قائمة M3U/Xtream', 'Saisir MAC + clé + votre playlist M3U/Xtream', 'Inserisci MAC + chiave + playlist M3U/Xtream', 'Βάλε MAC + κλειδί + λίστα M3U/Xtream'],
    'activate_s3': ['Zurück in die App, dann auf „Prüfen"', 'Back to the app, then tap "Check"', 'Uygulamaya dön, „Kontrol et"e bas', 'ارجع للتطبيق ثم اضغط „تحقق"', 'Revenez à l\'app, puis „Vérifier"', 'Torna all\'app, poi „Verifica"', 'Πίσω στην εφαρμογή, μετά „Έλεγχος"'],
    'activate_check': ['Playlist prüfen', 'Check playlist', 'Listeyi kontrol et', 'تحقق من القائمة', 'Vérifier la playlist', 'Verifica playlist', 'Έλεγχος λίστας'],
    'activate_pending': ['Noch keine Playlist für diesen Code gefunden.', 'No playlist found for this code yet.', 'Bu kod için henüz liste yok.', 'لا توجد قائمة لهذا الرمز بعد.', 'Aucune playlist pour ce code pour l\'instant.', 'Nessuna playlist per questo codice.', 'Δεν βρέθηκε λίστα για αυτόν τον κωδικό.'],
    'activate_manual': ['Zugangsdaten manuell eingeben', 'Enter credentials manually', 'Bilgileri elle gir', 'إدخال يدوي', 'Saisir manuellement', 'Inserisci manualmente', 'Χειροκίνητη εισαγωγή'],
    'copied': ['Code kopiert', 'Code copied', 'Kod kopyalandı', 'تم نسخ الرمز', 'Code copié', 'Codice copiato', 'Ο κωδικός αντιγράφηκε'],
    'free_days_left': ['Tage gratis übrig', 'free days left', 'gün ücretsiz kaldı', 'أيام مجانية متبقية', 'jours gratuits restants', 'giorni gratis rimasti', 'δωρεάν ημέρες'],
    'last_free_day': ['Letzter Gratis-Tag', 'Last free day', 'Son ücretsiz gün', 'آخر يوم مجاني', 'Dernier jour gratuit', 'Ultimo giorno gratis', 'Τελευταία δωρεάν ημέρα'],
    'unlock': ['Freischalten', 'Unlock', 'Kilidi aç', 'فتح', 'Débloquer', 'Sblocca', 'Ξεκλείδωμα'],
    'paywall_title': ['Testzeitraum abgelaufen', 'Trial period ended', 'Deneme süresi bitti', 'انتهت الفترة التجريبية', 'Période d\'essai terminée', 'Periodo di prova terminato', 'Η δοκιμή έληξε'],
    'paywall_body': ['Schalte Vela dauerhaft frei, um weiterzuschauen.', 'Unlock Vela permanently to keep watching.', 'İzlemeye devam etmek için Vela\'yı kalıcı olarak aç.', 'افتح Vela بشكل دائم للمتابعة.', 'Débloquez Vela définitivement pour continuer.', 'Sblocca Vela per sempre per continuare.', 'Ξεκλείδωσε το Vela μόνιμα για να συνεχίσεις.'],
    'lifetime': ['Lifetime', 'Lifetime', 'Ömür boyu', 'مدى الحياة', 'À vie', 'A vita', 'Εφ\' όρου ζωής'],
    'buy_now': ['Jetzt kaufen', 'Buy now', 'Şimdi satın al', 'اشترِ الآن', 'Acheter maintenant', 'Acquista ora', 'Αγορά τώρα'],
    'restore': ['Kauf wiederherstellen', 'Restore purchase', 'Satın almayı geri yükle', 'استعادة الشراء', 'Restaurer l\'achat', 'Ripristina acquisto', 'Επαναφορά αγοράς'],
    'playlist_expired_title': ['Playlist abgelaufen', 'Playlist expired', 'Liste süresi doldu', 'انتهت القائمة', 'Playlist expirée', 'Playlist scaduta', 'Η λίστα έληξε'],
    'playlist_expired_body': ['Deine Playlist ist abgelaufen oder nicht aktiv. Wende dich an deinen Anbieter.', 'Your playlist has expired or is inactive. Contact your provider.', 'Listenin süresi doldu veya aktif değil. Sağlayıcına başvur.', 'قائمتك منتهية أو غير نشطة. تواصل مع مزوّدك.', 'Votre playlist a expiré ou est inactive. Contactez votre fournisseur.', 'La tua playlist è scaduta o non attiva. Contatta il tuo fornitore.', 'Η λίστα σου έληξε ή δεν είναι ενεργή. Επικοινώνησε με τον πάροχό σου.'],
    'recheck': ['Erneut prüfen', 'Check again', 'Tekrar kontrol et', 'تحقق مجددًا', 'Vérifier à nouveau', 'Ricontrolla', 'Έλεγχος ξανά'],
    'menu': ['Menü', 'Menu', 'Menü', 'القائمة', 'Menu', 'Menu', 'Μενού'],
    'reload': ['Neu laden', 'Reload', 'Yenile', 'إعادة تحميل', 'Recharger', 'Ricarica', 'Επαναφόρτωση'],
    'reload_playlist': ['Playlist neu laden', 'Reload playlist', 'Playlist’i yenile', 'إعادة تحميل القائمة', 'Recharger la playlist', 'Ricarica playlist', 'Επαναφόρτωση λίστας'],
    'reload_confirm': ['Playlist wirklich von velaplayer.com neu laden?', 'Really reload the playlist from velaplayer.com?', 'Playlist velaplayer.com’dan gerçekten yenilensin mi?', 'هل تريد فعلاً إعادة تحميل القائمة من velaplayer.com؟', 'Vraiment recharger la playlist depuis velaplayer.com ?', 'Ricaricare davvero la playlist da velaplayer.com?', 'Να επαναφορτωθεί η λίστα από το velaplayer.com;'],
    'reloaded': ['Playlist aktualisiert.', 'Playlist updated.', 'Playlist güncellendi.', 'تم تحديث القائمة.', 'Playlist mise à jour.', 'Playlist aggiornata.', 'Η λίστα ενημερώθηκε.'],
    'reload_none': ['Keine aktive Playlist auf velaplayer.com verknüpft.', 'No active playlist linked on velaplayer.com.', 'velaplayer.com’da bağlı aktif playlist yok.', 'لا توجد قائمة نشطة مرتبطة على velaplayer.com.', 'Aucune playlist active liée sur velaplayer.com.', 'Nessuna playlist attiva collegata su velaplayer.com.', 'Καμία ενεργή λίστα συνδεδεμένη στο velaplayer.com.'],
    'reload_offline': ['Server nicht erreichbar – aktuelle Playlist bleibt.', 'Server unreachable – current playlist kept.', 'Sunucuya ulaşılamıyor – mevcut playlist korunuyor.', 'الخادم غير متاح – تم الإبقاء على القائمة الحالية.', 'Serveur injoignable – playlist actuelle conservée.', 'Server irraggiungibile – playlist attuale mantenuta.', 'Ο διακομιστής δεν είναι προσβάσιμος – διατηρείται η τρέχουσα λίστα.'],
    'server_save_err': ['Konnte nicht auf velaplayer.com gespeichert werden. Später erneut versuchen.', 'Could not save to velaplayer.com. Please try again later.', 'velaplayer.com’a kaydedilemedi. Lütfen sonra tekrar deneyin.', 'تعذّر الحفظ على velaplayer.com. حاول لاحقًا.', 'Impossible d’enregistrer sur velaplayer.com. Réessayez plus tard.', 'Impossibile salvare su velaplayer.com. Riprova più tardi.', 'Αποτυχία αποθήκευσης στο velaplayer.com. Δοκιμάστε αργότερα.'],
    'manual_m3u': ['M3U-Link', 'M3U link', 'M3U bağlantısı', 'رابط M3U', 'Lien M3U', 'Link M3U', 'Σύνδεσμος M3U'],
    'm3u_url_hint': ['M3U-URL (http…)', 'M3U URL (http…)', 'M3U URL (http…)', 'عنوان M3U ‏(http…)', 'URL M3U (http…)', 'URL M3U (http…)', 'URL M3U (http…)'],
    'm3u_url_err': ['Bitte eine gültige M3U-URL (http…) eingeben.', 'Please enter a valid M3U URL (http…).', 'Lütfen geçerli bir M3U URL’si (http…) girin.', 'يرجى إدخال رابط M3U صالح ‏(http…).', 'Veuillez saisir une URL M3U valide (http…).', 'Inserisci un URL M3U valido (http…).', 'Εισαγάγετε έγκυρο URL M3U (http…).'],
    'change_playlist': ['Playlist ändern', 'Change playlist', 'Listeyi değiştir', 'تغيير القائمة', 'Changer de playlist', 'Cambia playlist', 'Αλλαγή λίστας'],
    'sleep_timer': ['Sleep-Timer', 'Sleep timer', 'Uyku zamanlayıcı', 'مؤقت النوم', 'Minuterie de veille', 'Timer di spegnimento', 'Χρονοδιακόπτης'],
    'off': ['Aus', 'Off', 'Kapalı', 'إيقاف', 'Désactivé', 'Spento', 'Ανενεργό'],
    'yes': ['Ja', 'Yes', 'Evet', 'نعم', 'Oui', 'Sì', 'Ναι'],
    'no': ['Nein', 'No', 'Hayır', 'لا', 'Non', 'No', 'Όχι'],
  };
}
