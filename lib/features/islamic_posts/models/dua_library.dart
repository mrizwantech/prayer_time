import 'package:flutter/material.dart';

/// Supported languages for translations
enum TranslationLanguage {
  english,
  urdu,
  french,
  turkish,
  indonesian,
  malay,
  spanish,
  german,
}

extension TranslationLanguageExtension on TranslationLanguage {
  String get code {
    switch (this) {
      case TranslationLanguage.english:
        return 'en';
      case TranslationLanguage.urdu:
        return 'ur';
      case TranslationLanguage.french:
        return 'fr';
      case TranslationLanguage.turkish:
        return 'tr';
      case TranslationLanguage.indonesian:
        return 'id';
      case TranslationLanguage.malay:
        return 'ms';
      case TranslationLanguage.spanish:
        return 'es';
      case TranslationLanguage.german:
        return 'de';
    }
  }

  String get displayName {
    switch (this) {
      case TranslationLanguage.english:
        return 'English';
      case TranslationLanguage.urdu:
        return 'اردو (Urdu)';
      case TranslationLanguage.french:
        return 'Français';
      case TranslationLanguage.turkish:
        return 'Türkçe';
      case TranslationLanguage.indonesian:
        return 'Bahasa Indonesia';
      case TranslationLanguage.malay:
        return 'Bahasa Melayu';
      case TranslationLanguage.spanish:
        return 'Español';
      case TranslationLanguage.german:
        return 'Deutsch';
    }
  }

  String get nativeName {
    switch (this) {
      case TranslationLanguage.english:
        return 'English';
      case TranslationLanguage.urdu:
        return 'اردو';
      case TranslationLanguage.french:
        return 'Français';
      case TranslationLanguage.turkish:
        return 'Türkçe';
      case TranslationLanguage.indonesian:
        return 'Indonesia';
      case TranslationLanguage.malay:
        return 'Melayu';
      case TranslationLanguage.spanish:
        return 'Español';
      case TranslationLanguage.german:
        return 'Deutsch';
    }
  }

  bool get isRTL => this == TranslationLanguage.urdu;
}

/// Category of dua
enum DuaCategory {
  daily,
  morning,
  evening,
  prayer,
  food,
  travel,
  protection,
  forgiveness,
  gratitude,
  guidance,
  health,
  family,
  success,
  ramadan,
  hajj,
}

extension DuaCategoryExtension on DuaCategory {
  String get displayName {
    switch (this) {
      case DuaCategory.daily:
        return 'Daily Duas';
      case DuaCategory.morning:
        return 'Morning';
      case DuaCategory.evening:
        return 'Evening';
      case DuaCategory.prayer:
        return 'Prayer';
      case DuaCategory.food:
        return 'Food & Drink';
      case DuaCategory.travel:
        return 'Travel';
      case DuaCategory.protection:
        return 'Protection';
      case DuaCategory.forgiveness:
        return 'Forgiveness';
      case DuaCategory.gratitude:
        return 'Gratitude';
      case DuaCategory.guidance:
        return 'Guidance';
      case DuaCategory.health:
        return 'Health';
      case DuaCategory.family:
        return 'Family';
      case DuaCategory.success:
        return 'Success';
      case DuaCategory.ramadan:
        return 'Ramadan';
      case DuaCategory.hajj:
        return 'Hajj & Umrah';
    }
  }

  IconData get icon {
    switch (this) {
      case DuaCategory.daily:
        return Icons.today;
      case DuaCategory.morning:
        return Icons.wb_sunny;
      case DuaCategory.evening:
        return Icons.nights_stay;
      case DuaCategory.prayer:
        return Icons.mosque;
      case DuaCategory.food:
        return Icons.restaurant;
      case DuaCategory.travel:
        return Icons.flight;
      case DuaCategory.protection:
        return Icons.shield;
      case DuaCategory.forgiveness:
        return Icons.favorite;
      case DuaCategory.gratitude:
        return Icons.volunteer_activism;
      case DuaCategory.guidance:
        return Icons.lightbulb;
      case DuaCategory.health:
        return Icons.healing;
      case DuaCategory.family:
        return Icons.family_restroom;
      case DuaCategory.success:
        return Icons.emoji_events;
      case DuaCategory.ramadan:
        return Icons.star_border;
      case DuaCategory.hajj:
        return Icons.location_city;
    }
  }
}

/// A comprehensive Dua with multi-language translations
class DuaItem {
  final String id;
  final String title;
  final String arabic;
  final String transliteration;
  final Map<TranslationLanguage, String> translations;
  final DuaCategory category;
  final String? source;
  final String? occasion;

  const DuaItem({
    required this.id,
    required this.title,
    required this.arabic,
    required this.transliteration,
    required this.translations,
    required this.category,
    this.source,
    this.occasion,
  });

  String getTranslation(TranslationLanguage language) {
    return translations[language] ?? translations[TranslationLanguage.english] ?? '';
  }
}

/// Pre-written Duas library with multi-language support
class DuaLibrary {
  static const List<DuaItem> duas = [
    // === DAILY DUAS ===
    DuaItem(
      id: 'bismillah',
      title: 'Bismillah',
      arabic: 'بِسْمِ اللَّهِ',
      transliteration: 'Bismillah',
      translations: {
        TranslationLanguage.english: 'In the name of Allah',
        TranslationLanguage.urdu: 'اللہ کے نام سے',
        TranslationLanguage.french: 'Au nom d\'Allah',
        TranslationLanguage.turkish: 'Allah\'ın adıyla',
        TranslationLanguage.indonesian: 'Dengan nama Allah',
        TranslationLanguage.malay: 'Dengan nama Allah',
        TranslationLanguage.spanish: 'En el nombre de Allah',
        TranslationLanguage.german: 'Im Namen Allahs',
      },
      category: DuaCategory.daily,
      occasion: 'Before starting any task',
    ),
    DuaItem(
      id: 'bismillah_full',
      title: 'Bismillah (Full)',
      arabic: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
      transliteration: 'Bismillahir Rahmanir Raheem',
      translations: {
        TranslationLanguage.english: 'In the name of Allah, the Most Gracious, the Most Merciful',
        TranslationLanguage.urdu: 'اللہ کے نام سے جو بڑا مہربان نہایت رحم والا ہے',
        TranslationLanguage.french: 'Au nom d\'Allah, le Tout Miséricordieux, le Très Miséricordieux',
        TranslationLanguage.turkish: 'Rahman ve Rahim olan Allah\'ın adıyla',
        TranslationLanguage.indonesian: 'Dengan nama Allah Yang Maha Pengasih, Maha Penyayang',
        TranslationLanguage.malay: 'Dengan nama Allah Yang Maha Pemurah lagi Maha Penyayang',
        TranslationLanguage.spanish: 'En el nombre de Allah, el Compasivo, el Misericordioso',
        TranslationLanguage.german: 'Im Namen Allahs, des Allerbarmers, des Barmherzigen',
      },
      category: DuaCategory.daily,
      source: 'Surah Al-Fatiha',
    ),
    DuaItem(
      id: 'alhamdulillah',
      title: 'Alhamdulillah',
      arabic: 'الْحَمْدُ لِلَّهِ',
      transliteration: 'Alhamdulillah',
      translations: {
        TranslationLanguage.english: 'All praise is due to Allah',
        TranslationLanguage.urdu: 'تمام تعریفیں اللہ کے لیے ہیں',
        TranslationLanguage.french: 'Louange à Allah',
        TranslationLanguage.turkish: 'Hamd Allah\'a mahsustur',
        TranslationLanguage.indonesian: 'Segala puji bagi Allah',
        TranslationLanguage.malay: 'Segala puji bagi Allah',
        TranslationLanguage.spanish: 'Alabado sea Allah',
        TranslationLanguage.german: 'Alles Lob gebührt Allah',
      },
      category: DuaCategory.gratitude,
    ),
    DuaItem(
      id: 'subhanallah',
      title: 'SubhanAllah',
      arabic: 'سُبْحَانَ اللَّهِ',
      transliteration: 'SubhanAllah',
      translations: {
        TranslationLanguage.english: 'Glory be to Allah',
        TranslationLanguage.urdu: 'اللہ پاک ہے',
        TranslationLanguage.french: 'Gloire à Allah',
        TranslationLanguage.turkish: 'Allah\'ı tenzih ederim',
        TranslationLanguage.indonesian: 'Maha Suci Allah',
        TranslationLanguage.malay: 'Maha Suci Allah',
        TranslationLanguage.spanish: 'Gloria a Allah',
        TranslationLanguage.german: 'Gepriesen sei Allah',
      },
      category: DuaCategory.daily,
    ),
    DuaItem(
      id: 'allahu_akbar',
      title: 'Allahu Akbar',
      arabic: 'اللَّهُ أَكْبَرُ',
      transliteration: 'Allahu Akbar',
      translations: {
        TranslationLanguage.english: 'Allah is the Greatest',
        TranslationLanguage.urdu: 'اللہ سب سے بڑا ہے',
        TranslationLanguage.french: 'Allah est le Plus Grand',
        TranslationLanguage.turkish: 'Allah en büyüktür',
        TranslationLanguage.indonesian: 'Allah Maha Besar',
        TranslationLanguage.malay: 'Allah Maha Besar',
        TranslationLanguage.spanish: 'Allah es el Más Grande',
        TranslationLanguage.german: 'Allah ist der Größte',
      },
      category: DuaCategory.daily,
    ),
    DuaItem(
      id: 'la_ilaha_illallah',
      title: 'Kalima Tayyiba',
      arabic: 'لَا إِلَٰهَ إِلَّا اللَّهُ',
      transliteration: 'La ilaha illallah',
      translations: {
        TranslationLanguage.english: 'There is no god but Allah',
        TranslationLanguage.urdu: 'اللہ کے سوا کوئی معبود نہیں',
        TranslationLanguage.french: 'Il n\'y a de dieu qu\'Allah',
        TranslationLanguage.turkish: 'Allah\'tan başka ilah yoktur',
        TranslationLanguage.indonesian: 'Tiada Tuhan selain Allah',
        TranslationLanguage.malay: 'Tiada Tuhan selain Allah',
        TranslationLanguage.spanish: 'No hay más dios que Allah',
        TranslationLanguage.german: 'Es gibt keinen Gott außer Allah',
      },
      category: DuaCategory.daily,
    ),
    DuaItem(
      id: 'astaghfirullah',
      title: 'Astaghfirullah',
      arabic: 'أَسْتَغْفِرُ اللَّهَ',
      transliteration: 'Astaghfirullah',
      translations: {
        TranslationLanguage.english: 'I seek forgiveness from Allah',
        TranslationLanguage.urdu: 'میں اللہ سے معافی مانگتا ہوں',
        TranslationLanguage.french: 'Je demande pardon à Allah',
        TranslationLanguage.turkish: 'Allah\'tan bağışlanma dilerim',
        TranslationLanguage.indonesian: 'Aku memohon ampun kepada Allah',
        TranslationLanguage.malay: 'Aku memohon ampun kepada Allah',
        TranslationLanguage.spanish: 'Pido perdón a Allah',
        TranslationLanguage.german: 'Ich bitte Allah um Vergebung',
      },
      category: DuaCategory.forgiveness,
    ),
    
    // === MORNING DUAS ===
    DuaItem(
      id: 'morning_wakeup',
      title: 'Upon Waking Up',
      arabic: 'الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ',
      transliteration: 'Alhamdu lillahil-ladhi ahyana ba\'da ma amatana wa ilayhin-nushur',
      translations: {
        TranslationLanguage.english: 'All praise is for Allah who gave us life after having taken it from us and unto Him is the resurrection',
        TranslationLanguage.urdu: 'تمام تعریفیں اللہ کے لیے ہیں جس نے ہمیں موت دینے کے بعد زندہ کیا اور اسی کی طرف اٹھ کر جانا ہے',
        TranslationLanguage.french: 'Louange à Allah qui nous a redonné la vie après nous avoir fait mourir et vers Lui est la résurrection',
        TranslationLanguage.turkish: 'Bizi öldürdükten sonra dirilten Allah\'a hamdolsun. Dönüş O\'nadır',
        TranslationLanguage.indonesian: 'Segala puji bagi Allah yang telah menghidupkan kami setelah mematikan kami dan kepada-Nya kami dibangkitkan',
      },
      category: DuaCategory.morning,
      source: 'Sahih al-Bukhari',
      occasion: 'When waking up from sleep',
    ),
    DuaItem(
      id: 'morning_sayyid',
      title: 'Sayyidul Istighfar',
      arabic: 'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَٰهَ إِلَّا أَنْتَ خَلَقْتَنِي وَأَنَا عَبْدُكَ وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ',
      transliteration: 'Allahumma anta Rabbi la ilaha illa anta, khalaqtani wa ana abduka, wa ana ala ahdika wa wa\'dika mastata\'tu, a\'udhu bika min sharri ma sana\'tu, abu\'u laka bini\'matika alayya, wa abu\'u bidhanbi faghfir li fa innahu la yaghfirudh-dhunuba illa anta',
      translations: {
        TranslationLanguage.english: 'O Allah, You are my Lord, none has the right to be worshipped except You. You created me and I am Your servant, and I abide by Your covenant and promise as best I can. I seek refuge in You from the evil of what I have done. I acknowledge Your favor upon me, and I acknowledge my sin, so forgive me, for verily none can forgive sins except You.',
        TranslationLanguage.urdu: 'اے اللہ! تو میرا رب ہے، تیرے سوا کوئی معبود نہیں، تو نے مجھے پیدا کیا اور میں تیرا بندہ ہوں، میں اپنی طاقت کے مطابق تیرے عہد و پیمان پر قائم ہوں، میں اپنے کیے ہوئے گناہوں کے شر سے تیری پناہ چاہتا ہوں، میں تیری نعمتوں کا اعتراف کرتا ہوں اور اپنے گناہوں کا بھی اعتراف کرتا ہوں، پس مجھے بخش دے کیونکہ تیرے سوا کوئی گناہ نہیں بخشتا',
        TranslationLanguage.french: 'Ô Allah, Tu es mon Seigneur, il n\'y a de divinité digne d\'adoration que Toi. Tu m\'as créé et je suis Ton serviteur. Je m\'engage envers Toi autant que je le puis. Je cherche refuge auprès de Toi contre le mal que j\'ai commis. Je reconnais Tes bienfaits sur moi et je reconnais mes péchés. Pardonne-moi, car nul ne pardonne les péchés si ce n\'est Toi.',
        TranslationLanguage.turkish: 'Allah\'ım! Sen benim Rabbimsin. Senden başka ilah yoktur. Beni Sen yarattın. Ben Senin kulunum ve gücüm yettiğince Sana verdiğim söz üzereyim. İşlediğim günahların şerrinden Sana sığınırım. Bana verdiğin nimetleri itiraf eder, günahlarımı da kabul ederim. Beni bağışla. Çünkü günahları ancak Sen bağışlarsın.',
      },
      category: DuaCategory.morning,
      source: 'Sahih al-Bukhari',
      occasion: 'Best dua for seeking forgiveness',
    ),

    // === EVENING DUAS ===
    DuaItem(
      id: 'evening_protection',
      title: 'Evening Protection',
      arabic: 'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ وَالْحَمْدُ لِلَّهِ لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ',
      transliteration: 'Amsayna wa amsal-mulku lillah, walhamdu lillah, la ilaha illallahu wahdahu la sharika lah',
      translations: {
        TranslationLanguage.english: 'We have reached the evening and at this very time all sovereignty belongs to Allah. All praise is for Allah. None has the right to be worshipped except Allah, alone, without any partner.',
        TranslationLanguage.urdu: 'ہم نے شام کی اور تمام بادشاہی اللہ کی ہوگئی، تمام تعریف اللہ کے لیے ہے، اللہ کے سوا کوئی معبود نہیں، وہ اکیلا ہے، اس کا کوئی شریک نہیں',
        TranslationLanguage.french: 'Nous voici au soir et c\'est à Allah qu\'appartient la royauté. Louange à Allah. Il n\'y a de dieu qu\'Allah, Seul, sans associé.',
        TranslationLanguage.turkish: 'Akşama erdik, mülk de Allah\'ın oldu. Hamd Allah\'a mahsustur. Allah\'tan başka ilah yoktur, O tektir, ortağı yoktur.',
      },
      category: DuaCategory.evening,
      source: 'Abu Dawud',
    ),
    DuaItem(
      id: 'before_sleep',
      title: 'Before Sleeping',
      arabic: 'بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا',
      transliteration: 'Bismika Allahumma amutu wa ahya',
      translations: {
        TranslationLanguage.english: 'In Your name, O Allah, I die and I live',
        TranslationLanguage.urdu: 'اے اللہ! تیرے نام سے میں مرتا ہوں اور جیتا ہوں',
        TranslationLanguage.french: 'En Ton nom, ô Allah, je meurs et je vis',
        TranslationLanguage.turkish: 'Allah\'ım! Senin adınla ölür ve dirilirim',
        TranslationLanguage.indonesian: 'Dengan nama-Mu ya Allah, aku mati dan aku hidup',
      },
      category: DuaCategory.evening,
      source: 'Sahih al-Bukhari',
      occasion: 'Before going to sleep',
    ),

    // === FOOD DUAS ===
    DuaItem(
      id: 'before_eating',
      title: 'Before Eating',
      arabic: 'بِسْمِ اللَّهِ وَعَلَى بَرَكَةِ اللَّهِ',
      transliteration: 'Bismillahi wa \'ala barakatillah',
      translations: {
        TranslationLanguage.english: 'In the name of Allah and with the blessings of Allah',
        TranslationLanguage.urdu: 'اللہ کے نام سے اور اللہ کی برکت پر',
        TranslationLanguage.french: 'Au nom d\'Allah et avec la bénédiction d\'Allah',
        TranslationLanguage.turkish: 'Allah\'ın adıyla ve Allah\'ın bereketiyle',
        TranslationLanguage.indonesian: 'Dengan nama Allah dan dengan berkah Allah',
      },
      category: DuaCategory.food,
      occasion: 'Before starting a meal',
    ),
    DuaItem(
      id: 'after_eating',
      title: 'After Eating',
      arabic: 'الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنَا وَسَقَانَا وَجَعَلَنَا مُسْلِمِينَ',
      transliteration: 'Alhamdu lillahil-ladhi at\'amana wa saqana wa ja\'alana muslimin',
      translations: {
        TranslationLanguage.english: 'All praise is for Allah who fed us, gave us drink, and made us Muslims',
        TranslationLanguage.urdu: 'تمام تعریف اللہ کے لیے ہے جس نے ہمیں کھلایا اور پلایا اور ہمیں مسلمان بنایا',
        TranslationLanguage.french: 'Louange à Allah qui nous a nourris, nous a abreuvés et a fait de nous des musulmans',
        TranslationLanguage.turkish: 'Bizi yediren, içiren ve Müslüman kılan Allah\'a hamdolsun',
        TranslationLanguage.indonesian: 'Segala puji bagi Allah yang telah memberi kami makan dan minum dan menjadikan kami Muslim',
      },
      category: DuaCategory.food,
      source: 'Abu Dawud, Tirmidhi',
      occasion: 'After finishing a meal',
    ),

    // === TRAVEL DUAS ===
    DuaItem(
      id: 'travel_dua',
      title: 'Travel Dua',
      arabic: 'سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَٰذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ وَإِنَّا إِلَىٰ رَبِّنَا لَمُنقَلِبُونَ',
      transliteration: 'Subhanal-ladhi sakh-khara lana hadha wa ma kunna lahu muqrinin, wa inna ila Rabbina lamunqalibun',
      translations: {
        TranslationLanguage.english: 'Glory to Him who has subjected this to us, and we could never have it (by our efforts). And indeed, to our Lord we will surely return.',
        TranslationLanguage.urdu: 'پاک ہے وہ ذات جس نے اسے ہمارے لیے مسخر کیا اور ہم اس کو قابو میں نہیں کر سکتے تھے۔ اور بیشک ہم اپنے رب کی طرف لوٹنے والے ہیں',
        TranslationLanguage.french: 'Gloire à Celui qui nous a assujetti ceci alors que nous n\'étions pas capables de le dominer. Et c\'est vers notre Seigneur que nous retournerons.',
        TranslationLanguage.turkish: 'Bunu bizim hizmetimize veren Allah\'ın şanı ne yücedir. Yoksa biz buna güç yetiremezdik. Şüphesiz biz Rabbimize döneceğiz.',
        TranslationLanguage.indonesian: 'Maha Suci Allah yang telah menundukkan ini untuk kami, padahal kami tidak mampu menguasainya. Dan sungguh, kepada Tuhan kami pasti kami akan kembali.',
      },
      category: DuaCategory.travel,
      source: 'Surah Az-Zukhruf (43:13-14)',
      occasion: 'When starting a journey',
    ),
    DuaItem(
      id: 'entering_vehicle',
      title: 'Entering Vehicle',
      arabic: 'بِسْمِ اللَّهِ، الْحَمْدُ لِلَّهِ',
      transliteration: 'Bismillah, Alhamdulillah',
      translations: {
        TranslationLanguage.english: 'In the name of Allah, All praise is for Allah',
        TranslationLanguage.urdu: 'اللہ کے نام سے، تمام تعریف اللہ کے لیے ہے',
        TranslationLanguage.french: 'Au nom d\'Allah, Louange à Allah',
        TranslationLanguage.turkish: 'Allah\'ın adıyla, Hamd Allah\'a mahsustur',
      },
      category: DuaCategory.travel,
      occasion: 'When entering a vehicle',
    ),

    // === PROTECTION DUAS ===
    DuaItem(
      id: 'ayatul_kursi',
      title: 'Ayatul Kursi',
      arabic: 'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ وَلَا يَئُودُهُ حِفْظُهُمَا وَهُوَ الْعَلِيُّ الْعَظِيمُ',
      transliteration: 'Allahu la ilaha illa Huwal-Hayyul-Qayyum, la ta\'khudhuhu sinatun wa la nawm, lahu ma fis-samawati wa ma fil-ard, man dhal-ladhi yashfa\'u \'indahu illa bi-idhnih, ya\'lamu ma bayna aydihim wa ma khalfahum, wa la yuhituna bi shay\'in min \'ilmihi illa bima sha\'a, wasi\'a kursiyyuhus-samawati wal-ard, wa la ya\'uduhu hifdhuhuma, wa Huwal-\'Aliyyul-\'Adhim',
      translations: {
        TranslationLanguage.english: 'Allah! There is no deity except Him, the Ever-Living, the Sustainer of existence. Neither drowsiness overtakes Him nor sleep. To Him belongs whatever is in the heavens and whatever is on the earth. Who is it that can intercede with Him except by His permission? He knows what is before them and what will be after them, and they encompass not a thing of His knowledge except for what He wills. His Kursi extends over the heavens and the earth, and their preservation tires Him not. And He is the Most High, the Most Great.',
        TranslationLanguage.urdu: 'اللہ جس کے سوا کوئی معبود نہیں، زندہ ہے، سب کا تھامنے والا، نہ اسے اونگھ آتی ہے نہ نیند، جو کچھ آسمانوں میں ہے اور جو کچھ زمین میں ہے سب اسی کا ہے، کون ہے جو اس کے سامنے بغیر اس کی اجازت کے سفارش کر سکے، وہ جانتا ہے جو ان کے آگے ہے اور جو ان کے پیچھے ہے، اور وہ اس کے علم میں سے کسی چیز کا احاطہ نہیں کر سکتے مگر جتنا وہ چاہے، اس کی کرسی آسمانوں اور زمین کو محیط ہے اور ان دونوں کی نگہبانی اسے نہیں تھکاتی، وہ بلند اور عظیم ہے',
        TranslationLanguage.french: 'Allah! Point de divinité à part Lui, le Vivant, Celui qui subsiste par Lui-même. Ni somnolence ni sommeil ne Le saisissent. A Lui appartient tout ce qui est dans les cieux et sur la terre.',
        TranslationLanguage.turkish: 'Allah, O\'ndan başka ilah yoktur. O, Hayy\'dır, Kayyum\'dur. Onu ne uyuklama alır ne de uyku. Göklerde ve yerde ne varsa O\'nundur.',
      },
      category: DuaCategory.protection,
      source: 'Surah Al-Baqarah (2:255)',
      occasion: 'For protection - recite morning, evening, before sleep',
    ),
    DuaItem(
      id: 'protection_evil',
      title: 'Protection from Evil',
      arabic: 'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ',
      transliteration: 'A\'udhu bikalimatil-lahit-tammati min sharri ma khalaq',
      translations: {
        TranslationLanguage.english: 'I seek refuge in the perfect words of Allah from the evil of what He has created',
        TranslationLanguage.urdu: 'میں اللہ کے مکمل کلمات کی پناہ چاہتا ہوں اس کی تمام مخلوق کے شر سے',
        TranslationLanguage.french: 'Je cherche refuge dans les paroles parfaites d\'Allah contre le mal de ce qu\'Il a créé',
        TranslationLanguage.turkish: 'Allah\'ın tam kelimelerine sığınırım, yarattığı şeylerin şerrinden',
        TranslationLanguage.indonesian: 'Aku berlindung dengan kalimat-kalimat Allah yang sempurna dari kejahatan makhluk yang diciptakan-Nya',
      },
      category: DuaCategory.protection,
      source: 'Sahih Muslim',
      occasion: 'For protection from all evil',
    ),

    // === HEALTH DUAS ===
    DuaItem(
      id: 'health_cure',
      title: 'Dua for Cure',
      arabic: 'اللَّهُمَّ رَبَّ النَّاسِ أَذْهِبِ الْبَأْسَ اشْفِ أَنْتَ الشَّافِي لَا شِفَاءَ إِلَّا شِفَاؤُكَ شِفَاءً لَا يُغَادِرُ سَقَمًا',
      transliteration: 'Allahumma Rabban-nas, adhhibil-ba\'s, ishfi antash-Shafi, la shifa\'a illa shifa\'uk, shifa\'an la yughadiru saqama',
      translations: {
        TranslationLanguage.english: 'O Allah, Lord of mankind, remove the affliction. Cure, for You are the Healer. There is no cure except Your cure - a cure that leaves no illness behind.',
        TranslationLanguage.urdu: 'اے اللہ! لوگوں کے رب! تکلیف دور کر دے، شفا دے، تو ہی شفا دینے والا ہے، تیری شفا کے سوا کوئی شفا نہیں، ایسی شفا جو کوئی بیماری نہ چھوڑے',
        TranslationLanguage.french: 'Ô Allah, Seigneur des hommes, éloigne le mal, guéris car Tu es le Guérisseur. Il n\'y a de guérison que Ta guérison, une guérison qui ne laisse aucune maladie.',
        TranslationLanguage.turkish: 'Ey insanların Rabbi olan Allah\'ım! Sıkıntıyı gider, şifa ver. Şafi Sensin. Senin şifandan başka şifa yoktur. Öyle bir şifa ver ki hiçbir hastalık bırakmasın.',
      },
      category: DuaCategory.health,
      source: 'Sahih al-Bukhari',
      occasion: 'When visiting or praying for someone who is sick',
    ),
    DuaItem(
      id: 'wellbeing',
      title: 'Dua for Wellbeing',
      arabic: 'اللَّهُمَّ عَافِنِي فِي بَدَنِي اللَّهُمَّ عَافِنِي فِي سَمْعِي اللَّهُمَّ عَافِنِي فِي بَصَرِي لَا إِلَٰهَ إِلَّا أَنْتَ',
      transliteration: 'Allahumma \'afini fi badani, Allahumma \'afini fi sam\'i, Allahumma \'afini fi basari, la ilaha illa anta',
      translations: {
        TranslationLanguage.english: 'O Allah, grant me health in my body. O Allah, grant me health in my hearing. O Allah, grant me health in my sight. There is no deity except You.',
        TranslationLanguage.urdu: 'اے اللہ! میرے جسم میں عافیت دے، اے اللہ! میری سماعت میں عافیت دے، اے اللہ! میری بصارت میں عافیت دے، تیرے سوا کوئی معبود نہیں',
        TranslationLanguage.french: 'Ô Allah, accorde-moi la santé dans mon corps. Ô Allah, accorde-moi la santé dans mon ouïe. Ô Allah, accorde-moi la santé dans ma vue. Il n\'y a de divinité que Toi.',
        TranslationLanguage.turkish: 'Allah\'ım! Bedenime afiyet ver. Allah\'ım! Kulağıma afiyet ver. Allah\'ım! Gözüme afiyet ver. Senden başka ilah yoktur.',
      },
      category: DuaCategory.health,
      source: 'Abu Dawud',
    ),

    // === GUIDANCE DUAS ===
    DuaItem(
      id: 'guidance_knowledge',
      title: 'Dua for Knowledge',
      arabic: 'رَبِّ زِدْنِي عِلْمًا',
      transliteration: 'Rabbi zidni \'ilma',
      translations: {
        TranslationLanguage.english: 'My Lord, increase me in knowledge',
        TranslationLanguage.urdu: 'اے میرے رب! میرے علم میں اضافہ فرما',
        TranslationLanguage.french: 'Seigneur, augmente mes connaissances',
        TranslationLanguage.turkish: 'Rabbim! İlmimi artır',
        TranslationLanguage.indonesian: 'Ya Tuhanku, tambahkanlah ilmu kepadaku',
      },
      category: DuaCategory.guidance,
      source: 'Surah Ta-Ha (20:114)',
    ),
    DuaItem(
      id: 'guidance_straight_path',
      title: 'Guidance to Straight Path',
      arabic: 'اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ',
      transliteration: 'Ihdinas-siratal-mustaqim',
      translations: {
        TranslationLanguage.english: 'Guide us to the straight path',
        TranslationLanguage.urdu: 'ہمیں سیدھے راستے کی ہدایت دے',
        TranslationLanguage.french: 'Guide-nous vers le droit chemin',
        TranslationLanguage.turkish: 'Bizi doğru yola ilet',
        TranslationLanguage.indonesian: 'Tunjukilah kami jalan yang lurus',
      },
      category: DuaCategory.guidance,
      source: 'Surah Al-Fatiha (1:6)',
    ),
    DuaItem(
      id: 'istikhara',
      title: 'Dua Istikhara (Seeking Guidance)',
      arabic: 'اللَّهُمَّ إِنِّي أَسْتَخِيرُكَ بِعِلْمِكَ وَأَسْتَقْدِرُكَ بِقُدْرَتِكَ وَأَسْأَلُكَ مِنْ فَضْلِكَ الْعَظِيمِ فَإِنَّكَ تَقْدِرُ وَلَا أَقْدِرُ وَتَعْلَمُ وَلَا أَعْلَمُ وَأَنْتَ عَلَّامُ الْغُيُوبِ',
      transliteration: 'Allahumma inni astakhiruka bi\'ilmika, wa astaqdiruka biqudratika, wa as\'aluka min fadlikal-\'adhim, fa innaka taqdiru wa la aqdir, wa ta\'lamu wa la a\'lam, wa anta \'allamul-ghuyub',
      translations: {
        TranslationLanguage.english: 'O Allah, I seek Your guidance through Your knowledge, and I seek ability through Your power, and I ask You from Your immense bounty. For verily You are capable and I am not. You know and I do not, and You are the Knower of the unseen.',
        TranslationLanguage.urdu: 'اے اللہ! میں تیرے علم کے ذریعے تجھ سے بھلائی طلب کرتا ہوں، تیری قدرت کے ذریعے تجھ سے طاقت مانگتا ہوں، اور تیرے بڑے فضل سے سوال کرتا ہوں۔ بیشک تو قادر ہے اور میں قادر نہیں، تو جانتا ہے اور میں نہیں جانتا، اور تو غیب کا جاننے والا ہے',
        TranslationLanguage.french: 'Ô Allah, je Te consulte de par Ta science, je Te demande la capacité de par Ton pouvoir, et je Te demande de Ton immense faveur. Car Tu es Capable et je suis incapable. Tu sais et je ne sais pas, et Tu es le Grand Connaisseur de l\'invisible.',
        TranslationLanguage.turkish: 'Allah\'ım! İlminle Senden hayır istiyorum, kudretinle Senden güç istiyorum, büyük fazlından istiyorum. Şüphesiz Sen her şeye kadirsin, ben değilim. Sen bilirsin, ben bilmem. Sen gaybları bilensin.',
      },
      category: DuaCategory.guidance,
      source: 'Sahih al-Bukhari',
      occasion: 'When seeking guidance for a decision',
    ),

    // === FAMILY DUAS ===
    DuaItem(
      id: 'family_righteous',
      title: 'Dua for Righteous Family',
      arabic: 'رَبَّنَا هَبْ لَنَا مِنْ أَزْوَاجِنَا وَذُرِّيَّاتِنَا قُرَّةَ أَعْيُنٍ وَاجْعَلْنَا لِلْمُتَّقِينَ إِمَامًا',
      transliteration: 'Rabbana hab lana min azwajina wa dhurriyyatina qurrata a\'yunin waj\'alna lil-muttaqina imama',
      translations: {
        TranslationLanguage.english: 'Our Lord, grant us from among our wives and offspring comfort to our eyes and make us an example for the righteous.',
        TranslationLanguage.urdu: 'اے ہمارے رب! ہمیں ہماری بیویوں اور اولاد سے آنکھوں کی ٹھنڈک عطا فرما اور ہمیں پرہیزگاروں کا پیشوا بنا',
        TranslationLanguage.french: 'Notre Seigneur, fais de nos épouses et de nos descendants la joie de nos yeux et fais de nous un modèle pour les pieux.',
        TranslationLanguage.turkish: 'Rabbimiz! Bize eşlerimizden ve soylarımızdan göz aydınlığı olacak kimseler bağışla ve bizi takva sahiplerine önder kıl.',
      },
      category: DuaCategory.family,
      source: 'Surah Al-Furqan (25:74)',
    ),
    DuaItem(
      id: 'parents_mercy',
      title: 'Dua for Parents',
      arabic: 'رَّبِّ ارْحَمْهُمَا كَمَا رَبَّيَانِي صَغِيرًا',
      transliteration: 'Rabbir-hamhuma kama rabbayani saghira',
      translations: {
        TranslationLanguage.english: 'My Lord, have mercy upon them as they brought me up when I was small',
        TranslationLanguage.urdu: 'اے میرے رب! ان دونوں پر رحم فرما جیسا کہ انہوں نے مجھے بچپن میں پالا',
        TranslationLanguage.french: 'Seigneur, fais-leur miséricorde comme ils m\'ont élevé tout petit',
        TranslationLanguage.turkish: 'Rabbim! Onlar beni küçükken nasıl yetiştirdilerse, Sen de onlara öyle merhamet et',
        TranslationLanguage.indonesian: 'Ya Tuhanku, sayangilah keduanya sebagaimana mereka menyayangiku di waktu kecil',
      },
      category: DuaCategory.family,
      source: 'Surah Al-Isra (17:24)',
    ),

    // === SUCCESS DUAS ===
    DuaItem(
      id: 'success_ease',
      title: 'Dua for Ease',
      arabic: 'رَبِّ اشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي',
      transliteration: 'Rabbi-shrah li sadri wa yassir li amri',
      translations: {
        TranslationLanguage.english: 'My Lord, expand for me my chest and ease for me my task',
        TranslationLanguage.urdu: 'اے میرے رب! میرا سینہ کھول دے اور میرا کام آسان کر دے',
        TranslationLanguage.french: 'Seigneur, ouvre-moi ma poitrine et facilite ma tâche',
        TranslationLanguage.turkish: 'Rabbim! Göğsümü aç ve işimi kolaylaştır',
        TranslationLanguage.indonesian: 'Ya Tuhanku, lapangkanlah dadaku dan mudahkanlah urusanku',
      },
      category: DuaCategory.success,
      source: 'Surah Ta-Ha (20:25-26)',
      occasion: 'Before any important task or exam',
    ),
    DuaItem(
      id: 'success_world_hereafter',
      title: 'Dua for This World & Hereafter',
      arabic: 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
      transliteration: 'Rabbana atina fid-dunya hasanatan wa fil-akhirati hasanatan wa qina \'adhaban-nar',
      translations: {
        TranslationLanguage.english: 'Our Lord, give us good in this world and good in the Hereafter, and protect us from the punishment of the Fire',
        TranslationLanguage.urdu: 'اے ہمارے رب! ہمیں دنیا میں بھی بھلائی دے اور آخرت میں بھی بھلائی دے اور ہمیں آگ کے عذاب سے بچا',
        TranslationLanguage.french: 'Notre Seigneur, accorde-nous une belle part ici-bas et une belle part dans l\'au-delà, et préserve-nous du châtiment du Feu',
        TranslationLanguage.turkish: 'Rabbimiz! Bize dünyada da iyilik ver, ahirette de iyilik ver ve bizi ateş azabından koru',
        TranslationLanguage.indonesian: 'Ya Tuhan kami, berikanlah kami kebaikan di dunia dan kebaikan di akhirat, dan lindungilah kami dari azab neraka',
      },
      category: DuaCategory.success,
      source: 'Surah Al-Baqarah (2:201)',
    ),

    // === RAMADAN DUAS ===
    DuaItem(
      id: 'iftar_dua',
      title: 'Dua for Breaking Fast (Iftar)',
      arabic: 'ذَهَبَ الظَّمَأُ وَابْتَلَّتِ الْعُرُوقُ وَثَبَتَ الْأَجْرُ إِنْ شَاءَ اللَّهُ',
      transliteration: 'Dhahaba adh-dhama\'u wab-tallatil-\'uruqu wa thabatal-ajru in sha\'Allah',
      translations: {
        TranslationLanguage.english: 'The thirst has gone, the veins are moistened, and the reward is confirmed, if Allah wills',
        TranslationLanguage.urdu: 'پیاس چلی گئی اور رگیں تر ہوگئیں اور ان شاء اللہ اجر ثابت ہوگیا',
        TranslationLanguage.french: 'La soif est partie, les veines sont humidifiées et la récompense est confirmée si Allah le veut',
        TranslationLanguage.turkish: 'Susuzluk gitti, damarlar ıslandı ve inşaallah sevap kesinleşti',
        TranslationLanguage.indonesian: 'Telah hilang dahaga, urat-urat telah basah, dan pahala telah ditetapkan, insya Allah',
      },
      category: DuaCategory.ramadan,
      source: 'Abu Dawud',
      occasion: 'When breaking the fast at Iftar',
    ),
    DuaItem(
      id: 'laylatul_qadr',
      title: 'Dua for Laylatul Qadr',
      arabic: 'اللَّهُمَّ إِنَّكَ عَفُوٌّ تُحِبُّ الْعَفْوَ فَاعْفُ عَنِّي',
      transliteration: 'Allahumma innaka \'Afuwwun tuhibbul-\'afwa fa\'fu \'anni',
      translations: {
        TranslationLanguage.english: 'O Allah, You are Forgiving and love forgiveness, so forgive me',
        TranslationLanguage.urdu: 'اے اللہ! بیشک تو معاف کرنے والا ہے، معافی کو پسند کرتا ہے، پس مجھے معاف فرما دے',
        TranslationLanguage.french: 'Ô Allah, Tu es Pardonneur et Tu aimes le pardon, alors pardonne-moi',
        TranslationLanguage.turkish: 'Allah\'ım! Sen affedicisin, affı seversin, beni affet',
        TranslationLanguage.indonesian: 'Ya Allah, sesungguhnya Engkau Maha Pemaaf, Engkau mencintai ampunan, maka ampunilah aku',
      },
      category: DuaCategory.ramadan,
      source: 'Tirmidhi',
      occasion: 'Recommended dua for the Night of Decree',
    ),

    // === HAJJ DUAS ===
    DuaItem(
      id: 'talbiyah',
      title: 'Talbiyah',
      arabic: 'لَبَّيْكَ اللَّهُمَّ لَبَّيْكَ لَبَّيْكَ لَا شَرِيكَ لَكَ لَبَّيْكَ إِنَّ الْحَمْدَ وَالنِّعْمَةَ لَكَ وَالْمُلْكَ لَا شَرِيكَ لَكَ',
      transliteration: 'Labbayk Allahumma labbayk, labbayka la sharika laka labbayk, innal-hamda wan-ni\'mata laka wal-mulk, la sharika lak',
      translations: {
        TranslationLanguage.english: 'Here I am, O Allah, here I am. Here I am, You have no partner, here I am. Verily all praise, grace and sovereignty belong to You. You have no partner.',
        TranslationLanguage.urdu: 'میں حاضر ہوں اے اللہ میں حاضر ہوں، میں حاضر ہوں تیرا کوئی شریک نہیں، میں حاضر ہوں۔ بیشک تمام تعریف اور نعمت تیری ہے اور بادشاہی بھی، تیرا کوئی شریک نہیں',
        TranslationLanguage.french: 'Me voici, Ô Allah, me voici. Me voici, Tu n\'as pas d\'associé, me voici. Certes, la louange, la grâce et la royauté T\'appartiennent. Tu n\'as pas d\'associé.',
        TranslationLanguage.turkish: 'Lebbeyk Allahümme lebbeyk. Lebbeyk lâ şerîke leke lebbeyk. İnnel hamde ven ni\'mete leke vel mülk. Lâ şerîke lek.',
      },
      category: DuaCategory.hajj,
      occasion: 'Recited during Hajj and Umrah',
    ),
  ];

  /// Get duas by category
  static List<DuaItem> getDuasByCategory(DuaCategory category) {
    return duas.where((dua) => dua.category == category).toList();
  }

  /// Search duas by keyword
  static List<DuaItem> searchDuas(String keyword) {
    final lowerKeyword = keyword.toLowerCase();
    return duas.where((dua) {
      return dua.title.toLowerCase().contains(lowerKeyword) ||
          dua.arabic.contains(keyword) ||
          dua.transliteration.toLowerCase().contains(lowerKeyword) ||
          dua.translations.values.any((t) => t.toLowerCase().contains(lowerKeyword));
    }).toList();
  }

  /// Get all categories that have duas
  static List<DuaCategory> get availableCategories {
    return DuaCategory.values.where((cat) => getDuasByCategory(cat).isNotEmpty).toList();
  }
}
