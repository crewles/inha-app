import '../services/update_service.dart';

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
  String get appVersion => 'v${UpdateService.currentVersion}';

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
      'Inha App v${UpdateService.currentVersion} • Tashkent Campus';
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

  // Assignment Detail (Stitch #12)
  String get assignmentDetailTitle =>
      isRu ? 'О задании' : 'Assignment Detail';
  String get problemStatement =>
      isRu ? 'Условие задания' : 'Problem Statement';
  String get noDescriptionProvided =>
      isRu ? 'Текстовое описание не указано в eClass.' : 'No description provided in eClass.';
  String get attachedFiles =>
      isRu ? 'Прикреплённые файлы' : 'Attached Files';
  String get submissionPortal =>
      isRu ? 'Отправка решения' : 'Submission Portal';
  String get submittedFilesLabel =>
      isRu ? 'Отправленные файлы' : 'Submitted Files';
  String get professorFeedback =>
      isRu ? 'Комментарий преподавателя' : 'Instructor Feedback';
  String get pickFileToUpload =>
      isRu ? 'Выбрать файл с устройства' : 'Choose solution file';
  String get changeFile => isRu ? 'Заменить файл' : 'Replace file';
  String get honorCodeLabel =>
      isRu ? 'Подтвердить отправку на проверку' : 'Submit for grading (Honor Code)';
  String get honorCodeSub => isRu
      ? 'Подтверждает финальную отправку работы вместо черновика'
      : 'Finalizes submission instead of keeping a draft';
  String maxPointsLabel(String pts) =>
      isRu ? 'Макс. $pts б.' : '$pts Pts Max';
  String dueInCountdown(int d, int h, int m) {
    if (d > 0) return isRu ? 'Осталось $dд $hч' : '${d}d ${h}h remaining';
    if (h > 0) return isRu ? 'Осталось $hч $mм' : '${h}h ${m}m remaining';
    return isRu ? 'Осталось $m мин' : '$m min remaining';
  }

  String get noDeadlineSet => isRu ? 'Без жёсткого дедлайна' : 'No deadline set';
  String get uploadOnlyInWebHint => isRu
      ? 'Отправка файлов через API недоступна — откройте задание в eClass.'
      : 'API file upload unavailable for this task — open in eClass.';

  // Hide / Dismiss Deadlines & Assignment Details
  String get hideDeadline => isRu ? 'Скрыть задание' : 'Hide assignment';
  String get hideAssignment => isRu ? 'Скрыть задание' : 'Hide assignment';
  String get restoreDeadline => isRu ? 'Вернуть' : 'Restore';
  String get hiddenFilter => isRu ? 'Скрытые' : 'Hidden';
  String get deadlineHiddenToast => isRu
      ? 'Задание скрыто из активных'
      : 'Assignment hidden from active list';
  String get deadlineRestoredToast =>
      isRu ? 'Задание возвращено' : 'Assignment restored';
  String get undoLabel => isRu ? 'Отменить' : 'Undo';
  String get hiddenBadge => isRu ? 'Скрыто' : 'Hidden';
  String get noInstructorComment =>
      isRu ? 'Комментария от преподавателя нет' : 'No comment from instructor';
  String get viewDetailsLabel => isRu ? 'Подробнее' : 'View Details';
  String get gradedLabel => isRu ? 'Оценено' : 'Graded';
  String get deadlineSectionLabel => isRu ? 'Срок сдачи' : 'Deadline';
  String get openInEclassShort => 'eClass';

  // Completion Breakdown Sheet
  String get progressBreakdownTitle =>
      isRu ? 'Детализация прогресса' : 'Completion Breakdown';
  String get byStatusLabel => isRu ? 'ПО СТАТУСУ' : 'BY STATUS';
  String get byCourseLabel => isRu ? 'ПО КУРСАМ' : 'BY COURSE';
  String get tapToFilterHint => isRu
      ? 'Нажмите на статус или курс для перехода'
      : 'Tap a status or course to jump in';
  String get noPendingInCourse =>
      isRu ? 'Все задания сданы' : 'All tasks submitted';

  // Syllabus Weights
  String get fromSyllabusBadge => isRu ? 'Из силлабуса' : 'From Syllabus';

  // Cross-Navigation & Info Sheets
  String get classDetailsTitle => isRu ? 'Занятие' : 'Class Session';
  String get transcriptDetailsTitle =>
      isRu ? 'Запись транскрипта' : 'Transcript Record';
  String copiedToast(String label) =>
      isRu ? 'Скопировано: $label' : 'Copied: $label';
  String get creditsFullLabel => isRu ? 'Кредиты' : 'Credits';
  String get courseTypeLabel => isRu ? 'Тип курса' : 'Category';
  String get semesterLabel => isRu ? 'Семестр' : 'Semester';
  String get professorLabel => isRu ? 'Преподаватель' : 'Instructor';
  String get classroomLabel => isRu ? 'Аудитория' : 'Classroom';
  String get groupsLabel => isRu ? 'Группы' : 'Groups';
  String get openCourseBtn => isRu ? 'Открыть курс' : 'Open Course';

  // Haptics
  String get hapticsTitle => isRu ? 'Тактильный отклик' : 'Haptic feedback';
  String get hapticsSub => isRu
      ? 'Лёгкая вибрация при переключениях и действиях'
      : 'Subtle tactile vibration on taps and switches';

  // Notifications & Diagnostics
  String get gradeAlertsTitle => isRu ? 'Новые оценки' : 'New grade alerts';
  String get gradeAlertsSub => isRu
      ? 'Уведомлять при появлении или изменении оценок'
      : 'Alert when course or INS grades update';
  String get testNotificationsTitle =>
      isRu ? 'Проверить уведомления' : 'Test Notifications';
  String get testNotificationsSub => isRu
      ? 'Мгновенный и отложенный тест, статус и расписание'
      : 'Instant & 10s test, permission & scheduled queue';
  String get notifDiagnosticsTitle =>
      isRu ? 'Диагностика уведомлений' : 'Notification Diagnostics';
  String get permissionStatusLabel =>
      isRu ? 'Разрешение системы' : 'System Permission';
  String get permissionGranted => isRu ? 'Разрешено' : 'Granted';
  String get permissionDenied => isRu ? 'Отключено' : 'Denied';
  String get grantPermissionBtn => isRu ? 'Разрешить' : 'Allow';
  String scheduledAlertsCount(int total) =>
      isRu ? '$total в очереди' : '$total scheduled';
  String classAlertsCount(int n) =>
      isRu ? 'Пары: $n' : 'Classes: $n';
  String deadlineAlertsCount(int n) =>
      isRu ? 'Дедлайны: $n' : 'Deadlines: $n';
  String get classesMetricLabel => isRu ? 'Пары' : 'Classes';
  String get deadlinesMetricLabel => isRu ? 'Дедлайны' : 'Deadlines';
  String get scheduledMetricLabel => isRu ? 'В очереди' : 'Scheduled';
  String get sendInstantTestBtn =>
      isRu ? 'Мгновенный тест' : 'Send Instant Test';
  String get schedule10sTestBtn => isRu ? 'Тест через 10с' : 'Test in 10s';
  String get instantTestSentToast => isRu
      ? 'Тестовое уведомление отправлено!'
      : 'Test notification sent!';
  String get delayedTestScheduledToast => isRu
      ? 'Уведомление придёт через 10с — можно свернуть приложение'
      : 'Notification scheduled in 10s — try minimizing the app';
  String get delayedTestInexactToast => isRu
      ? 'Разрешите «Будильники и напоминания» в настройках, иначе система задержит тест'
      : 'Allow exact alarms in Android settings so 10s test fires on time';

  // GPA Calculator & Simulator (Stitch)
  String get gpaCalculatorTitle => isRu ? 'Калькулятор GPA' : 'GPA Calculator';
  String get gpaCalculatorCaps => isRu ? 'КАЛЬКУЛЯТОР GPA' : 'GPA CALCULATOR';
  String get gpaCalculatorSub => isRu
      ? 'Прогноз семестрового и общего GPA по шкале 4.5'
      : 'Simulate semester & cumulative GPA (4.5 scale)';
  String get gpaSimulatorTitle =>
      isRu ? 'Симулятор влияния на GPA' : 'GPA Impact Simulator';
  String get gpaSimulatorDesc => isRu
      ? 'Смоделируйте оценку за экзамен и посмотрите, как изменится итоговый GPA по предмету и семестру.'
      : 'Simulate final exam outcomes and preview how they shift your course grade and semester GPA.';
  String get calculateScenariosBtn =>
      isRu ? 'Рассчитать сценарии' : 'Calculate Scenarios';
  String get projectedGpaLabel =>
      isRu ? 'ПРОГНОЗ ОБЩЕГО GPA' : 'PROJECTED CUMULATIVE GPA';
  String get semesterGpaLabel => isRu ? 'GPA за семестр' : 'Semester GPA';
  String get totalCreditsLabel => isRu ? 'Всего кредитов' : 'Total Credits';
  String get currentStandingTitle =>
      isRu ? 'Текущие данные (INS)' : 'Current Standing (INS)';
  String get currentStandingSub => isRu
      ? 'База по завершённым семестрам'
      : 'Baseline from previous semesters';
  String get priorCumGpaLabel => isRu ? 'Текущий GPA' : 'Prior Cumulative GPA';
  String get completedCreditsLabel =>
      isRu ? 'Закрыто кредитов' : 'Completed Credits';
  String get semesterCoursesTitle =>
      isRu ? 'Предметы семестра' : 'Current Semester Courses';
  String coursesCountBadge(int n) {
    if (!isRu) return n == 1 ? '1 course' : '$n courses';
    final mod100 = n % 100;
    final mod10 = n % 10;
    if (mod10 == 1 && mod100 != 11) return '$n предмет';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return '$n предмета';
    }
    return '$n предметов';
  }

  String get addCourseBtn => isRu ? 'Добавить предмет' : 'Add Course';
  String get resetBtn => isRu ? 'Сбросить' : 'Reset';
  String get courseScoreSimTitle =>
      isRu ? 'Симулятор балла по курсу' : 'Course Score Simulator';
  String get expectedRemainingScore =>
      isRu ? 'Оценка за оставшийся итог' : 'Remaining Exam / Work Score';
  String get customCourseHint => isRu ? 'Новый предмет' : 'New Course';
  String crShort(int cr) => isRu ? '$cr кр.' : '$cr cr';
  String get draftStatus => isRu ? 'Черновик (не отправлен)' : 'Draft (not submitted)';
  String get courseGradeSliderLabel =>
      isRu ? 'Предполагаемая оценка' : 'Course Grade';
  String get autoModeBadge => isRu ? 'Авто' : 'Auto';
  String get manualModeBadge => isRu ? 'Вручную' : 'Manual';
  String get resetToAutoHint =>
      isRu ? 'Сбросить в авто' : 'Reset to auto';
  String get fromEclassBadge => 'eClass';
  String get overallCoursePctLabel =>
      isRu ? 'Итог по курсу' : 'Course Overall';
  String get upcomingScheduledLabel =>
      isRu ? 'БЛИЖАЙШИЕ ЗАПЛАНИРОВАННЫЕ' : 'NEXT SCHEDULED ALERTS';
  String get noScheduledAlerts => isRu
      ? 'Запланированных уведомлений пока нет. Выберите группу в Расписании или включите напоминания о дедлайнах.'
      : 'No scheduled alerts yet. Pick a timetable group or enable deadline reminders.';
  String get whatWeNotifyTitle =>
      isRu ? 'О чём сообщают уведомления' : 'What Notifications Cover';
  List<String> get whatWeNotifyItems => isRu
      ? const [
          'Начало пар (офлайн): за выбранное число минут до каждой пары недели.',
          'Дедлайны (офлайн): за 24 часа и за 2 часа до сдачи (кроме скрытых).',
          'Новые задания в фоне (WorkManager): периодическая проверка eClass API.',
          'Новые оценки: при обновлении оценок в eClass или портале INS.',
        ]
      : const [
          'Class Reminders (offline): weekly alerts before each group lecture.',
          'Assignment Deadlines (offline): 24h & 2h before due date (excludes hidden).',
          'Background New Tasks (WorkManager): periodic eClass API checks.',
          'Grade Updates: when new grades appear on eClass or INS sync.',
        ];

  // Auto-Updater
  String get appUpdatesTitle => isRu ? 'Обновления' : 'App Updates';
  String get checkUpdatesTitle =>
      isRu ? 'Проверить обновления' : 'Check for updates';
  String checkUpdatesSub(String ver) => isRu
      ? 'Текущая версия v$ver • GitHub Releases'
      : 'Current version v$ver • GitHub Releases';
  String get updateAvailableTitle =>
      isRu ? 'Доступно обновление' : 'Update Available';
  String updateAvailableBadge(String ver) =>
      isRu ? 'Новая v$ver' : 'New v$ver';
  String get whatsNewLabel => isRu ? 'Что нового' : "What's New";
  String get downloadAndInstallBtn =>
      isRu ? 'Скачать и установить' : 'Download & Install';
  String downloadingUpdatePct(int pct) =>
      isRu ? 'Скачивание... $pct%' : 'Downloading... $pct%';
  String get openOnGithubBtn =>
      isRu ? 'Открыть на GitHub' : 'Open on GitHub';
  String get upToDateToast =>
      isRu ? 'Установлена последняя версия' : 'You are on the latest version';
  String get updateRepoPrivateToast => isRu
      ? 'Репозиторий пока приватный или релизов ещё нет'
      : 'Repository has no public releases yet';
  String get updateCheckFailedToast => isRu
      ? 'Не удалось проверить обновления'
      : 'Failed to check for updates';
  String get installPermissionPrompt => isRu
      ? 'Разрешите установку из этого источника и нажмите снова'
      : 'Allow app installs from this source and tap Install again';

  // Android Home Screen Widgets (Stitch #11)
  String get homeWidgetsTitle =>
      isRu ? 'Виджеты рабочего стола' : 'Home Screen Widgets';
  String get homeWidgetsSub => isRu
      ? '4 виджета с живыми данными без открытия приложения'
      : '4 Material You widgets synced from local SQLite';
  String get widgetGalleryTitle =>
      isRu ? 'Галерея виджетов' : 'Widget Gallery';
  String get widgetGallerySubtitle => isRu
      ? 'Предпросмотр с вашими текущими данными и быстрое добавление на экран Android'
      : 'Live preview with your real portal data and one-tap home screen pinning';
  String get addToHomeBtn => isRu ? 'На экран' : 'Add to Home';
  String get widgetPinSentToast => isRu
      ? 'Запрос на добавление виджета отправлен лаунчеру'
      : 'Widget pin request sent to launcher';
  String get widgetPinFallbackToast => isRu
      ? 'Удерживайте пустое место на рабочем столе -> Виджеты -> Inha App'
      : 'Long-press your home screen -> Widgets -> Inha App';
  String get widgetNextLectureTitle =>
      isRu ? 'Следующая пара' : 'Next Lecture Glance';
  String get widgetNextLectureDesc => isRu
      ? 'Ближайшее занятие, время и аудитория'
      : 'Upcoming lecture countdown, time slot & room';
  String get widgetTodayScheduleTitle =>
      isRu ? 'Расписание на сегодня' : "Today's Schedule";
  String get widgetTodayScheduleDesc => isRu
      ? 'Список пар выбранной группы на текущий день'
      : 'Up to 4 classes for your group today';
  String get widgetInsAcademicTitle =>
      isRu ? 'INS GPA и кредиты' : 'INS Academic';
  String get widgetInsAcademicDesc => isRu
      ? 'Компактная карточка GPA и активных курсов'
      : 'Compact GPA dial & earned credits snapshot';
  String get widgetDeadlinesTitle =>
      isRu ? 'Дедлайны eClass' : 'Deadlines & Tasks';
  String get widgetDeadlinesDesc => isRu
      ? 'Срочные несданные задания (без скрытых)'
      : 'Upcoming pending tasks (excludes hidden)';
}
