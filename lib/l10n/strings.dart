class S {
  final String lang;
  const S(this.lang);

  bool get isRu => lang == 'ru';

  String get appTitle => 'Inha App';
  String get appSubtitle =>
      isRu ? 'eClass • INS • Расписание' : 'eClass • INS • Timetable';
  String get portalHeader => 'IUT PORTAL';
  String get campusFooter => isRu
      ? 'Inha University in Tashkent • Локальный SQLite'
      : 'Inha University in Tashkent • Local SQLite';
  String get appVersion => 'v1.0.1';

  // Navigation
  String get navCourses => isRu ? 'Курсы' : 'Courses';
  String get navAssignments => isRu ? 'Задания' : 'Assignments';
  String get navTimetable => isRu ? 'Расписание' : 'Timetable';
  String get navIns => 'INS';
  String get navSettings => isRu ? 'Настройки' : 'Settings';

  // Login
  String get loginTitle => isRu ? 'Вход в Inha' : 'Sign in to Inha';
  String get loginSubtitle => isRu
      ? 'Все данные хранятся локально в SQLite на вашем телефоне'
      : 'All data is stored locally in SQLite on your device';
  String get loginTagline => isRu
      ? 'Ваши курсы, оценки и расписание в одном месте'
      : 'Your classes, grades, and schedule in one place';
  String get studentId =>
      isRu ? 'Student ID (например U2210001)' : 'Student ID (e.g. U2210001)';
  String get studentIdLabel => 'Student ID';
  String get portalIdTag => 'Portal ID';
  String get requiredTag => isRu ? 'Обязательно' : 'Required';
  String get autoSyncTag => 'Auto-Sync';
  String get insSyncHelper => isRu
      ? 'Для автоматической синхронизации оценок и транскрипта'
      : 'For automatic grade and transcript sync';
  String get enterStudentIdHint => 'U2210001';
  String get enterEclassPasswordHint =>
      isRu ? 'Введите пароль eClass' : 'Enter eClass password';
  String get enterInsPasswordHint =>
      isRu ? 'Введите пароль INS' : 'Enter INS password';
  String get eclassPassword => isRu ? 'Пароль eClass' : 'eClass Password';
  String get insPasswordOptional =>
      isRu ? 'Пароль INS (необязательно)' : 'INS Password (optional)';
  String get signIn => isRu ? 'Войти' : 'Sign in';
  String get signingIn => isRu ? 'Выполняется вход...' : 'Signing in...';
  String get loginFailed => isRu
      ? 'Неверный логин или пароль eClass, либо нет сети'
      : 'Invalid eClass credentials or network error';
  String get fieldRequired => isRu ? 'Обязательное поле' : 'Required field';

  // Courses & Course Detail
  String get coursesEmpty => isRu
      ? 'Курсы не найдены. Потяните вниз для обновления.'
      : 'No courses found. Pull down to refresh.';
  String get currentSemester => isRu ? 'Текущий' : 'Current';
  String get allCourses => isRu ? 'Все курсы' : 'All courses';
  String get welcomeBack => isRu ? 'С возвращением' : 'Welcome back';
  String helloUser(String name) => isRu ? 'Привет, $name 👋' : 'Hello, $name 👋';
  String yearLabel(String yr) => isRu ? '$yr курс' : 'Year $yr';
  String get cumulativeGpaCaps => isRu ? 'ОБЩИЙ GPA (INS)' : 'CUMULATIVE GPA';
  String get coursesSummaryLabel => isRu ? 'АКТИВНЫЕ КУРСЫ' : 'ACTIVE COURSES';
  String activeCoursesCount(int n) =>
      isRu ? '$n активн.' : '$n Active';
  String tasksDueCount(int n) {
    if (!isRu) return n == 1 ? '1 task due' : '$n tasks due';
    final mod100 = n % 100;
    final mod10 = n % 10;
    if (mod10 == 1 && mod100 != 11) return '$n задание';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return '$n задания';
    }
    return '$n заданий';
  }

  String get allCaughtUp => isRu ? 'Всё сдано ✓' : 'All caught up ✓';
  String get tapCourseHint => isRu
      ? 'Нажмите на курс, чтобы открыть материалы и задания'
      : 'Tap any card to view lecture slides & assignments';
  String get archiveTag => isRu ? 'Архив' : 'Archive';

  String get tabAssignments => isRu ? 'Задания' : 'Assignments';
  String get tabGrades => isRu ? 'Оценки' : 'Grades';
  String get tabAttendance => isRu ? 'Посещаемость' : 'Attendance';
  String get tabFiles => isRu ? 'Файлы' : 'Files';
  String get syllabus => isRu ? 'Силлабус' : 'Syllabus';
  String get openSyllabus => isRu ? 'Открыть силлабус' : 'Open syllabus';
  String get refresh => isRu ? 'Обновить' : 'Refresh';
  String get offlineCache => isRu ? 'Локальная база SQLite' : 'Local SQLite DB';

  String get courseDetailTitle => isRu ? 'О курсе' : 'Course Detail';
  String get attendanceRecord => isRu ? 'Посещаемость' : 'Attendance Record';
  String get attendanceThreshold => isRu
      ? 'Минимум 80% для допуска к экзамену'
      : 'Threshold minimum: 80% to sit final';
  String get statusSafe => isRu ? 'Статус: В норме' : 'Status: Safe';
  String get statusAtRisk => isRu ? 'Статус: Ниже 80%' : 'Status: Below 80%';
  String get savedOffline => isRu ? 'Сохранено офлайн' : 'Saved offline';
  String filesCount(int n) => isRu ? '$n файлов' : '$n Files';
  String get courseMaterials => isRu ? 'Материалы курса' : 'Course Materials';
  String get submitWork => isRu ? 'Сдать файл' : 'Submit work';

  // Assignments
  String get filterAll => isRu ? 'Все' : 'All';
  String get filterPending => isRu ? 'Несданные' : 'Pending';
  String get filterSubmitted => isRu ? 'Сданные' : 'Submitted';
  String get filterGraded => isRu ? 'С оценкой' : 'Graded';
  String get noAssignments => isRu ? 'Заданий нет' : 'No assignments';
  String assignmentsAttention(int n) {
    if (n == 0) {
      return isRu
          ? 'Все текущие задания сданы'
          : 'All current assignments submitted';
    }
    return isRu
        ? '${tasksDueCount(n)} требуют внимания'
        : '$n ${n == 1 ? "task needs" : "tasks need"} your attention';
  }

  String get completionPace => isRu ? 'Прогресс сдачи' : 'Completion Pace';
  String percentFinished(int pct) =>
      isRu ? '$pct% выполнено' : '$pct% Finished';
  String completedOf(int done, int total) =>
      isRu ? '$done из $total сдано' : '$done of $total completed';
  String dueIn7Days(int n) =>
      isRu ? '$n в ближайшие 7 дн.' : '$n due in 7 days';
  String get allCaughtUpTitle =>
      isRu ? 'Всё выполнено!' : 'All caught up!';
  String get allCaughtUpBody => isRu
      ? 'В этой категории нет заданий. Отличная работа!'
      : 'No assignments found in this category.';
  String get noSubmissionYet =>
      isRu ? 'Файл ещё не отправлен' : 'No submission yet';
  String get openInEclass => isRu ? 'Открыть в eClass' : 'Open in eClass';
  String get overdueLabel => isRu ? 'Просрочено' : 'Overdue';
  String get dueSoonLabel => isRu ? 'Скоро дедлайн' : 'Urgent';
  String get submitSolution => isRu ? 'Сдать файл' : 'Submit Solution';

  String get dueLabel => isRu ? 'Срок' : 'Due';
  String get submitted => isRu ? 'Сдано' : 'Submitted';
  String get notSubmitted => isRu ? 'Не сдано' : 'Pending';
  String get uploadFile => isRu ? 'Сдать файл' : 'Submit file';
  String get uploading => isRu ? 'Загрузка файла...' : 'Uploading file...';
  String get uploadSuccess =>
      isRu ? 'Файл успешно отправлен!' : 'File uploaded successfully!';
  String get download => isRu ? 'Скачать' : 'Download';
  String get downloaded => isRu ? 'Скачано' : 'Downloaded';
  String get noFiles => isRu ? 'Файлов нет' : 'No files';
  String get noGrades => isRu ? 'Оценок пока нет' : 'No grades yet';

  // Attendance
  String get attendanceUnavailable =>
      isRu ? 'Данные о посещаемости недоступны' : 'Attendance data unavailable';
  String get present => isRu ? 'Присутствие' : 'Present';
  String get absent => isRu ? 'Пропуск' : 'Absent';
  String get lateLabel => isRu ? 'Опоздание' : 'Late';
  String get others => isRu ? 'Другое' : 'Others';
  String get recentSessions => isRu ? 'История занятий' : 'Recent Sessions';

  // Timetable
  String get selectGroup => isRu ? 'Выбрать группу' : 'Select group';
  String get searchGroup => isRu ? 'Поиск группы...' : 'Search group...';
  String get noGroupSelected => isRu
      ? 'Выберите свою группу, чтобы увидеть расписание'
      : 'Select your group to view the timetable';
  String get nextLesson => isRu ? 'Следующая пара' : 'Next Class';
  String get noLessonsToday => isRu ? 'Пар нет' : 'No classes';
  List<String> get dayLabels =>
      isRu ? ['Пн', 'Вт', 'Ср', 'Чт', 'Пт'] : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
  List<String> get dayFullNames => isRu
      ? ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница']
      : ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  String dayScheduleTitle(int idx) => isRu
      ? 'Расписание • ${dayFullNames[idx]}'
      : '${dayFullNames[idx]} Schedule';
  String classesCount(int n) {
    if (!isRu) return n == 1 ? '1 Class' : '$n Classes';
    final mod100 = n % 100;
    final mod10 = n % 10;
    if (mod10 == 1 && mod100 != 11) return '$n пара';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return '$n пары';
    }
    return '$n пар';
  }

  List<String> get monthShortNames => isRu
      ? const [
          'янв',
          'фев',
          'мар',
          'апр',
          'май',
          'июн',
          'июл',
          'авг',
          'сен',
          'окт',
          'ноя',
          'дек',
        ]
      : const [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];

  String formatCountdown(int mins) {
    final h = mins ~/ 60;
    final m = mins % 60;
    if (isRu) {
      return h > 0 ? 'через $h ч $m мин' : 'через $m мин';
    }
    return h > 0 ? 'in ${h}h ${m}m' : 'in $m min';
  }

  // INS
  String get insNotConfigured => isRu
      ? 'Введите пароль от INS (ins.inha.uz), чтобы смотреть оценки и транскрипт'
      : 'Enter your INS (ins.inha.uz) password to view grades and transcript';
  String get saveInsPassword => isRu ? 'Сохранить и загрузить' : 'Save & Load';
  String get gpaLabel => 'GPA';
  String get creditsLabel => isRu ? 'Кредиты' : 'Credits';
  String get rankLabel => isRu ? 'Ранг' : 'Rank';
  String get allSemesters => isRu ? 'Все семестры' : 'All Semesters';
  String get insLoadError => isRu
      ? 'Не удалось загрузить данные INS. Проверьте пароль и интернет.'
      : 'Failed to load INS data. Check password and network.';
  String get insPortalTitle => isRu ? 'Портал INS' : 'INS Portal';
  String get insSyncSub => isRu
      ? 'Прямое подключение к ins.inha.uz'
      : 'Direct ins.inha.uz connection';
  String syncUpdatedAgo(String rel) =>
      isRu ? 'Обновлено: $rel' : 'Sync: $rel';
  String get justNow => isRu ? 'только что' : 'just now';
  String minutesAgo(int m) => isRu ? '$m мин назад' : '${m}m ago';
  String hoursAgo(int h) => isRu ? '$h ч назад' : '${h}h ago';
  String daysAgo(int d) => isRu ? '$d д назад' : '${d}d ago';
  String get cumulativeLabel => isRu ? 'Общий' : 'Cumulative';
  String get academicSemesters =>
      isRu ? 'Учебные семестры' : 'Academic Semesters';
  String termsCount(int n) => isRu ? '$n сем.' : '$n Terms';
  String enrolledCourses(int n) =>
      isRu ? 'Предметы ($n)' : 'Courses ($n)';
  String get letterGrading => isRu ? 'Буквенные оценки' : 'Letter Grading';
  String ptsLabel(String pts) => isRu ? '$pts б.' : '$pts pts';

  // Settings
  String get accountSection => isRu ? 'Аккаунт' : 'Account';
  String get appearanceSection =>
      isRu ? 'Оформление (Material 3)' : 'Appearance (Material 3)';
  String get themeLabel => isRu ? 'Тема' : 'Theme';
  String get themeSystem => isRu ? 'Системная' : 'System';
  String get themeLight => isRu ? 'Светлая' : 'Light';
  String get themeDark => isRu ? 'Тёмная' : 'Dark';
  String get dynamicColorLabel => 'Dynamic Color (Material You)';
  String get dynamicColorSub => isRu
      ? 'Адаптировать цвета под обои телефона'
      : 'Adapt colors from device wallpaper';
  String get languageLabel => isRu ? 'Язык' : 'Language';
  String get notificationsSection =>
      isRu ? 'Уведомления и фоновый синк' : 'Notifications & Background Sync';
  String get notifyAssignments =>
      isRu ? 'Дедлайны заданий (за 24ч и 2ч)' : 'Deadline alerts (24h & 2h)';
  String get notifyGrades => isRu ? 'Новые оценки' : 'New grades';
  String get notifyTimetable =>
      isRu ? 'Напоминания о парах (офлайн)' : 'Class reminders (offline)';
  String get reminderOffset => isRu ? 'За сколько до пары' : 'Before class';
  String get bgSyncLabel => isRu
      ? 'Фоновая проверка eClass (WorkManager)'
      : 'Background eClass sync (WorkManager)';
  String get bgSyncSub => isRu
      ? 'Проверяет новые задания через JSON API в фоне'
      : 'Checks new assignments via JSON API in background';
  String get bgSyncInterval => isRu ? 'Интервал проверки' : 'Sync interval';
  String get syncNow => isRu ? 'Обновить всё сейчас' : 'Sync everything now';
  String get storageSection =>
      isRu ? 'Локальная база SQLite' : 'Local SQLite Storage';
  String get clearCache => isRu ? 'Очистить кэш данных' : 'Clear cached data';
  String get cacheCleared => isRu ? 'Кэш очищен' : 'Cache cleared';
  String get changeInsPassword =>
      isRu ? 'Изменить пароль INS' : 'Change INS password';
  String get logout => isRu ? 'Выйти из аккаунта' : 'Log out';
  String get logoutConfirm => isRu
      ? 'Удалить учётные данные и локальный кэш с этого устройства?'
      : 'Remove credentials and local cache from this device?';
  String get cancel => isRu ? 'Отмена' : 'Cancel';
  String get confirm => isRu ? 'Подтвердить' : 'Confirm';
  String get save => isRu ? 'Сохранить' : 'Save';

  String get preferencesOverline => isRu ? 'ПАРАМЕТРЫ' : 'PREFERENCES';
  String get settingsSubtitle => isRu
      ? 'Оформление, уведомления и синхронизация'
      : 'Preferences, notifications & sync';
  String get connectedBadge => isRu ? 'Подключён' : 'Connected';
  String get notSetBadge => isRu ? 'Не задан' : 'Not set';
  String get updateInsSub =>
      isRu ? 'Синхронизация оценок и транскрипта' : 'Portal credentials sync';
  String get themeModeTitle => isRu ? 'Режим темы' : 'Theme Mode';
  String get matchWallpaperTitle =>
      isRu ? 'Цвета обоев (Material You)' : 'Match wallpaper colors';
  String get matchWallpaperSub => isRu
      ? 'Адаптирует акценты под системные обои Android'
      : 'Derives expressive dynamic accents from system wallpaper';
  String get displayLanguageTitle => isRu ? 'Язык интерфейса' : 'Display Language';
  String get displayLanguageSub =>
      isRu ? 'Локализация приложения' : 'Portal localized interface';
  String get deadlineRemindersTitle =>
      isRu ? 'Напоминания о дедлайнах' : 'Deadline reminders';
  String get deadlineRemindersSub => isRu
      ? 'За 24ч и 2ч до срока сдачи задания'
      : '24h & 2h before assignment due date';
  String get classRemindersTitle =>
      isRu ? 'Напоминания о парах' : 'Class reminders';
  String classRemindersBefore(int m) => isRu
      ? 'За $m мин до начала пары (офлайн)'
      : '$m min before lecture starts (offline)';
  String get autoCheckTasksTitle =>
      isRu ? 'Фоновая проверка заданий' : 'Auto-check new tasks';
  String get autoCheckTasksSub => isRu
      ? 'Периодическая синхронизация WorkManager'
      : 'Background sync frequency (WorkManager)';
  String get refreshAllNow =>
      isRu ? 'Обновить все данные сейчас' : 'Refresh all data now';
  String get dataPrivacySection =>
      isRu ? 'Данные и хранилище' : 'Data & Storage';
  String get clearOfflineCacheTitle =>
      isRu ? 'Очистить офлайн-кэш' : 'Clear offline cache';
  String offlineCacheSub(String sizeText) => isRu
      ? '$sizeText скачанных файлов и кэш SQLite'
      : '$sizeText of downloaded files & SQLite cache';
  String get logoutPortal =>
      isRu ? 'Выйти из аккаунта' : 'Log out of Inha Portal';
  String get appVersionFooter =>
      'Inha App v1.0.1 • Tashkent Campus';
  String get localStorageFooter => isRu
      ? 'Локальное хранилище SQLite • Прямое подключение к eClass & INS'
      : 'Local SQLite Storage • Direct eClass & INS Client';

  // Unified password & INS UX
  String get loginSamePasswordNote => isRu
      ? 'Этот пароль автоматически используется для eClass и портала INS.'
      : 'Your eClass password is also used for the INS portal.';
  String get insNoData => isRu
      ? 'На портале INS пока нет записей об оценках.'
      : 'INS returned no grade records yet.';
  String get insOverridePasswordBtn =>
      isRu ? 'Указать другой пароль INS' : 'Use custom INS password';
  String get insAutoPasswordBadge =>
      isRu ? 'Авто (eClass)' : 'Auto (eClass)';
  String get insOverrideBadge => isRu ? 'Свой пароль' : 'Custom';
  String get insPasswordHintOverride => isRu
      ? 'Оставьте пустым, чтобы использовать пароль eClass'
      : 'Leave empty to use your eClass password';
  String get retryLabel => isRu ? 'Повторить' : 'Retry';

  // Course Detail — Stitch Assignments / Grades / Files
  String get assignmentsProgressTitle =>
      isRu ? 'Прогресс по заданиям' : 'Assignment Completion';
  String completedOfTotal(int done, int total) => isRu
      ? '$done из $total выполнено'
      : '$done of $total completed';
  String get hideCompletedLabel =>
      isRu ? 'Скрыть сданные' : 'Hide completed';

  String get currentStandingLabel =>
      isRu ? 'ТЕКУЩИЙ ИТОГ' : 'CURRENT STANDING';
  String get courseTotalLabel => isRu ? 'Итог по курсу' : 'Course Total';
  String get syllabusWeightsTitle =>
      isRu ? 'Разбивка по весам' : 'Syllabus Weight Breakdown';
  String get weightCol => isRu ? 'Вес' : 'Weight';
  String get scoreCol => isRu ? 'Оценка' : 'Score';
  String get rangeCol => isRu ? 'Диапазон' : 'Range';
  String get percentCol => isRu ? 'Процент' : 'Percent';
  String categoryItemsCount(int n) => isRu ? '$n поз.' : '$n items';
  String get itemsPending =>
      isRu ? 'Оценок по этой категории пока нет' : 'No items recorded yet';

  String get offlineStorageTitle =>
      isRu ? 'Офлайн-материалы' : 'Offline Materials';
  String offlineFilesCount(int cached, int total) => isRu
      ? 'Скачано $cached из $total файлов'
      : '$cached of $total files saved offline';
  String get searchMaterialsHint =>
      isRu ? 'Поиск файлов курса...' : 'Search course files...';
  String get filterLectures => isRu ? 'Слайды' : 'Slides';
  String get filterLabs => isRu ? 'Практика' : 'Labs & Code';
  String get filterDocuments => isRu ? 'Документы' : 'Documents';
  String get filterOffline => isRu ? 'Офлайн' : 'Offline';
  String downloadAllCount(int n) =>
      isRu ? 'Скачать все ($n)' : 'Download all ($n)';
  String downloadingAllProgress(int done, int total) =>
      isRu ? 'Скачивание $done/$total...' : 'Downloading $done/$total...';
  String get downloadedLocallyBadge =>
      isRu ? 'На устройстве' : 'Saved offline';
}
