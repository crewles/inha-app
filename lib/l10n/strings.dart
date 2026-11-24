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
      ? 'Inha University in Tashkent • Данные только на устройстве'
      : 'Inha University in Tashkent • Data stays on your device';
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
      ? 'Все данные хранятся только на вашем телефоне'
      : 'All data is stored exclusively on your device';
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
  String helloUser(String name) =>
      isRu ? 'Привет, $name 👋' : 'Hello, $name 👋';
  String yearLabel(String yr) => isRu ? '$yr курс' : 'Year $yr';
  String get cumulativeGpaCaps => isRu ? 'ОБЩИЙ GPA (INS)' : 'CUMULATIVE GPA';
  String get coursesSummaryLabel => isRu ? 'АКТИВНЫЕ КУРСЫ' : 'ACTIVE COURSES';
  String activeCoursesCount(int n) => isRu ? '$n активн.' : '$n Active';
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
  String get currentCourseTag => isRu ? 'Активный курс' : 'Active Course';

  String get tabAssignments => isRu ? 'Задания' : 'Assignments';
  String get tabGrades => isRu ? 'Оценки' : 'Grades';
  String get tabAttendance => isRu ? 'Посещаемость' : 'Attendance';
  String get tabFiles => isRu ? 'Файлы' : 'Files';
  String get syllabus => isRu ? 'Силлабус' : 'Syllabus';
  String get openSyllabus => isRu ? 'Открыть силлабус' : 'Open syllabus';
  String get refresh => isRu ? 'Обновить' : 'Refresh';
  String get offlineCache => isRu ? 'Память устройства' : 'On-device storage';

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
  String get allCaughtUpTitle => isRu ? 'Всё выполнено!' : 'All caught up!';
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
  String autoGroupBannerTitle(String group) => isRu
      ? 'Группа $group выбрана автоматически'
      : 'Group $group selected automatically';
  String get autoGroupBannerQuestion =>
      isRu ? 'Это ваша группа?' : 'Is this your group?';
  String get autoGroupYesBtn => isRu ? 'Да, верно' : 'Yes';
  String get autoGroupNoBtn => isRu ? 'Нет, выбрать другую' : 'No, pick another';
  String get nextLesson => isRu ? 'Следующая пара' : 'Next Class';
  String get noLessonsToday => isRu ? 'Пар нет' : 'No classes';
  List<String> get dayLabels => isRu
      ? ['Пн', 'Вт', 'Ср', 'Чт', 'Пт']
      : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
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
  String syncUpdatedAgo(String rel) => isRu ? 'Обновлено: $rel' : 'Sync: $rel';
  String get justNow => isRu ? 'только что' : 'just now';
  String minutesAgo(int m) => isRu ? '$m мин назад' : '${m}m ago';
  String hoursAgo(int h) => isRu ? '$h ч назад' : '${h}h ago';
  String daysAgo(int d) => isRu ? '$d д назад' : '${d}d ago';
  String get cumulativeLabel => isRu ? 'Общий' : 'Cumulative';
  String get academicSemesters =>
      isRu ? 'Учебные семестры' : 'Academic Semesters';
  String termsCount(int n) => isRu ? '$n сем.' : '$n Terms';
  String enrolledCourses(int n) => isRu ? 'Предметы ($n)' : 'Courses ($n)';
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
  String get bgSyncLabel =>
      isRu ? 'Фоновая проверка eClass' : 'Background eClass sync';
  String get bgSyncSub => isRu
      ? 'Автоматически проверяет новые задания в фоне'
      : 'Automatically checks for new assignments in the background';
  String get bgSyncInterval => isRu ? 'Интервал проверки' : 'Sync interval';
  String get syncNow => isRu ? 'Обновить всё сейчас' : 'Sync everything now';
  String get storageSection => isRu ? 'Память устройства' : 'On-Device Storage';
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
  String get displayLanguageTitle =>
      isRu ? 'Язык интерфейса' : 'Display Language';
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
  String get autoCheckTasksSub =>
      isRu ? 'Автоматическая проверка в фоне' : 'Automatic background checks';
  String get refreshAllNow =>
      isRu ? 'Обновить все данные сейчас' : 'Refresh all data now';
  String get dataPrivacySection =>
      isRu ? 'Данные и хранилище' : 'Data & Storage';
  String get clearOfflineCacheTitle =>
      isRu ? 'Очистить офлайн-кэш' : 'Clear offline cache';
  String offlineCacheSub(String sizeText) => isRu
      ? '$sizeText скачанных файлов и сохранённых данных'
      : '$sizeText of downloaded files & saved data';
  String get logoutPortal =>
      isRu ? 'Выйти из аккаунта' : 'Log out of Inha Portal';
  String get appVersionFooter =>
      'Inha App v${UpdateService.currentVersion} • Tashkent Campus';
  String get localStorageFooter => isRu
      ? 'Хранение только на устройстве • Прямое подключение к eClass & INS'
      : 'Stored on Your Device • Direct Connection to eClass & INS';

  // Unified password & INS UX
  String get loginSamePasswordNote => isRu
      ? 'Этот пароль автоматически используется для eClass и портала INS.'
      : 'Your eClass password is also used for the INS portal.';
  String get insNoData => isRu
      ? 'На портале INS пока нет записей об оценках.'
      : 'INS returned no grade records yet.';
  String get insOverridePasswordBtn =>
      isRu ? 'Указать другой пароль INS' : 'Use custom INS password';
  String get insAutoPasswordBadge => isRu ? 'Авто (eClass)' : 'Auto (eClass)';
  String get insOverrideBadge => isRu ? 'Свой пароль' : 'Custom';
  String get insPasswordHintOverride => isRu
      ? 'Оставьте пустым, чтобы использовать пароль eClass'
      : 'Leave empty to use your eClass password';
  String get retryLabel => isRu ? 'Повторить' : 'Retry';

  // Course Detail — Stitch Assignments / Grades / Files
  String get assignmentsProgressTitle =>
      isRu ? 'Прогресс по заданиям' : 'Assignment Completion';
  String completedOfTotal(int done, int total) =>
      isRu ? '$done из $total выполнено' : '$done of $total completed';
  String get hideCompletedLabel => isRu ? 'Скрыть сданные' : 'Hide completed';

  String get currentStandingLabel => isRu ? 'ТЕКУЩИЙ ИТОГ' : 'CURRENT STANDING';
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
  String get downloadedLocallyBadge => isRu ? 'На устройстве' : 'Saved offline';

  // Assignment Detail (Stitch #12)
  String get assignmentDetailTitle => isRu ? 'О задании' : 'Assignment Detail';
  String get problemStatement => isRu ? 'Условие задания' : 'Problem Statement';
  String get noDescriptionProvided => isRu
      ? 'Текстовое описание не указано в eClass.'
      : 'No description provided in eClass.';
  String get attachedFiles => isRu ? 'Прикреплённые файлы' : 'Attached Files';
  String get submissionPortal =>
      isRu ? 'Отправка решения' : 'Submission Portal';
  String get submittedFilesLabel =>
      isRu ? 'Отправленные файлы' : 'Submitted Files';
  String get professorFeedback =>
      isRu ? 'Комментарий преподавателя' : 'Instructor Feedback';
  String get pickFileToUpload =>
      isRu ? 'Выбрать файл с устройства' : 'Choose solution file';
  String get changeFile => isRu ? 'Заменить файл' : 'Replace file';
  String get honorCodeLabel => isRu
      ? 'Подтвердить отправку на проверку'
      : 'Submit for grading (Honor Code)';
  String get honorCodeSub => isRu
      ? 'Подтверждает финальную отправку работы вместо черновика'
      : 'Finalizes submission instead of keeping a draft';
  String maxPointsLabel(String pts) => isRu ? 'Макс. $pts б.' : '$pts Pts Max';
  String dueInCountdown(int d, int h, int m) {
    if (d > 0) return isRu ? 'Осталось $dд $hч' : '${d}d ${h}h remaining';
    if (h > 0) return isRu ? 'Осталось $hч $mм' : '${h}h ${m}m remaining';
    return isRu ? 'Осталось $m мин' : '$m min remaining';
  }

  String get noDeadlineSet =>
      isRu ? 'Без жёсткого дедлайна' : 'No deadline set';
  String get uploadOnlyInWebHint => isRu
      ? 'Отправка файлов для этого задания доступна только на сайте eClass.'
      : 'File upload for this task is available on the eClass website.';

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
  String classAlertsCount(int n) => isRu ? 'Пары: $n' : 'Classes: $n';
  String deadlineAlertsCount(int n) => isRu ? 'Дедлайны: $n' : 'Deadlines: $n';
  String get classesMetricLabel => isRu ? 'Пары' : 'Classes';
  String get deadlinesMetricLabel => isRu ? 'Дедлайны' : 'Deadlines';
  String get scheduledMetricLabel => isRu ? 'В очереди' : 'Scheduled';
  String get sendInstantTestBtn =>
      isRu ? 'Мгновенный тест' : 'Send Instant Test';
  String get schedule10sTestBtn => isRu ? 'Тест через 10с' : 'Test in 10s';
  String get instantTestSentToast =>
      isRu ? 'Тестовое уведомление отправлено!' : 'Test notification sent!';
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
  String get draftStatus =>
      isRu ? 'Черновик (не отправлен)' : 'Draft (not submitted)';
  String get courseGradeSliderLabel =>
      isRu ? 'Предполагаемая оценка' : 'Course Grade';
  String get autoModeBadge => isRu ? 'Авто' : 'Auto';
  String get manualModeBadge => isRu ? 'Вручную' : 'Manual';
  String get resetToAutoHint => isRu ? 'Сбросить в авто' : 'Reset to auto';
  String get fromEclassBadge => 'eClass';
  String get overallCoursePctLabel => isRu ? 'Итог по курсу' : 'Course Overall';
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
          'Новые задания в фоне: автоматическая проверка новых публикаций в eClass.',
          'Новые оценки: при обновлении оценок в eClass или портале INS.',
        ]
      : const [
          'Class Reminders (offline): weekly alerts before each group lecture.',
          'Assignment Deadlines (offline): 24h & 2h before due date (excludes hidden).',
          'Background New Tasks: automatic checks for newly posted eClass tasks.',
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
  String updateAvailableBadge(String ver) => isRu ? 'Новая v$ver' : 'New v$ver';
  String get whatsNewLabel => isRu ? 'Что нового' : "What's New";
  String get downloadAndInstallBtn =>
      isRu ? 'Скачать и установить' : 'Download & Install';
  String downloadingUpdatePct(int pct) =>
      isRu ? 'Скачивание... $pct%' : 'Downloading... $pct%';
  String get openOnGithubBtn => isRu ? 'Открыть на GitHub' : 'Open on GitHub';
  String get githubRepoTitle =>
      isRu ? 'Исходный код на GitHub' : 'Source Code on GitHub';
  String get githubRepoSub => 'github.com/crewles/inha-app • Open Source';
  String get upToDateToast =>
      isRu ? 'Установлена последняя версия' : 'You are on the latest version';
  String get updateRepoPrivateToast => isRu
      ? 'Репозиторий пока приватный или релизов ещё нет'
      : 'Repository has no public releases yet';
  String get updateCheckFailedToast =>
      isRu ? 'Не удалось проверить обновления' : 'Failed to check for updates';
  String get installPermissionPrompt => isRu
      ? 'Разрешите установку из этого источника и нажмите снова'
      : 'Allow app installs from this source and tap Install again';

  // Android Home Screen Widgets (Stitch #11)
  String get homeWidgetsTitle =>
      isRu ? 'Виджеты рабочего стола' : 'Home Screen Widgets';
  String get homeWidgetsSub => isRu
      ? '4 виджета с актуальными данными без открытия приложения'
      : '4 Material You widgets with live data at a glance';
  String get widgetGalleryTitle => isRu ? 'Галерея виджетов' : 'Widget Gallery';
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
  String get widgetPreviewLight => isRu ? 'Светлая' : 'Light Theme';
  String get widgetPreviewDark => isRu ? 'Тёмная' : 'Dark Theme';
  String get widgetNextLectureOverline =>
      isRu ? 'СЛЕДУЮЩАЯ ПАРА' : 'NEXT LECTURE';
  String get widgetTimetableOverline =>
      isRu ? 'РАСПИСАНИЕ' : 'TIMETABLE';
  String get widgetDeadlinesShortTitle =>
      isRu ? 'Дедлайны' : 'Deadlines';
  String get widgetDonePill => isRu ? 'Готово' : 'Done';
  String get widgetTapToOpen =>
      isRu ? 'Нажмите, чтобы открыть' : 'Tap to open schedule';
  String get widgetNoUpcoming =>
      isRu ? 'Ближайших пар нет' : 'No upcoming classes';
  String get widgetSelectGroupApp =>
      isRu ? 'Выберите группу в приложении' : 'Select your group in app';
  String get widgetSyncInsPrompt =>
      isRu ? 'Откройте INS' : 'Sync INS portal';
  String get widgetToday => isRu ? 'Сегодня' : 'Today';
  String get widgetTomorrow => isRu ? 'Завтра' : 'Tomorrow';
  String widgetClassesPlural(int count) {
    if (!isRu) return count == 1 ? '1 class' : '$count classes';
    final m100 = count % 100;
    final m10 = count % 10;
    if (m100 >= 11 && m100 <= 14) return '$count пар';
    if (m10 == 1) return '$count пара';
    if (m10 >= 2 && m10 <= 4) return '$count пары';
    return '$count пар';
  }
  String widgetCoursesPlural(int count) {
    if (!isRu) return count == 1 ? '1 course' : '$count courses';
    final m100 = count % 100;
    final m10 = count % 10;
    if (m100 >= 11 && m100 <= 14) return '$count курсов';
    if (m10 == 1) return '$count курс';
    if (m10 >= 2 && m10 <= 4) return '$count курса';
    return '$count курсов';
  }
  String widgetDuePlural(int count) {
    if (count == 0) return widgetDonePill;
    return isRu ? '$count активн.' : '$count due';
  }

  // #7 Privacy & Security
  String get privacyPolicyTitle =>
      isRu ? 'Политика конфиденциальности' : 'Privacy Policy';
  String get privacyPolicySub => isRu
      ? 'Почему разработчики не видят ваши пароли'
      : 'How your credentials stay private on your phone';
  String get privacyHeroBadge =>
      isRu ? 'ТОЛЬКО НА ВАШЕМ УСТРОЙСТВЕ' : 'ON-DEVICE ONLY';
  String get privacyHeroTitle => isRu
      ? 'Нулевой доступ разработчиков к вашим данным'
      : 'Zero Developer Access to Your Data';
  String get privacyHeroDesc => isRu
      ? 'Разработчики никогда не видят ваш Student ID, пароли, оценки или файлы. Приложение не использует свои серверы и работает напрямую с порталами университета.'
      : 'Developers never see your Student ID, passwords, grades, or files. There are no middleman developer servers — everything stays between your phone and Inha portals.';
  String get privacyHeroStatus => isRu
      ? 'Прямой обмен данными только с серверами Инха'
      : 'Direct connection to Inha University portals';
  String get privacySectionTitle =>
      isRu ? 'Главные гарантии приватности' : 'Core Privacy Guarantees';
  String get privacySectionSub => isRu
      ? 'Как Inha App защищает ваш аккаунт и учебные данные'
      : 'How Inha App keeps your student account strictly yours';
  String get privacyCard1Overline =>
      isRu ? 'УЧЁТНЫЕ ДАННЫЕ' : 'LOCAL CREDENTIALS';
  String get privacyCard1Title =>
      isRu ? 'Пароли не покидают ваш телефон' : '100% On-Device Credentials';
  String get privacyCard1Desc => isRu
      ? 'Ваш Student ID, пароли от eClass и INS, а также активная сессия входа сохраняются только в личном хранилище приложения на телефоне. Они никогда не отправляются разработчикам.'
      : 'Your Student ID, eClass & INS passwords, and sign-in session are stored exclusively inside your phone. They are never transmitted to or logged by any developer server.';
  String get privacyChipOnDevice =>
      isRu ? 'Только на телефоне' : 'Stored On Phone';
  String get privacyChipNoTracking =>
      isRu ? 'Без аналитики и слежки' : 'Zero Tracking';
  String get privacyChipNoServers =>
      isRu ? 'Без серверов автора' : 'No Developer Servers';
  String get privacyCard2Overline =>
      isRu ? 'СЕТЕВЫЕ ПОДКЛЮЧЕНИЯ' : 'DIRECT CONNECTIONS';
  String get privacyCard2Title =>
      isRu ? 'Прямой доступ без посредников' : 'Direct Portal Connections';
  String get privacyCard2Desc => isRu
      ? 'Каждый запрос за оценками, заданиями и расписанием идёт напрямую с вашего телефона на официальные ресурсы университета — без прокси и сторонних ретрансляторов.'
      : 'Every request for grades, assignments, and schedules goes straight from your phone to official university servers with no middleman proxy.';
  String get privacyEndpointEclassSub => isRu
      ? 'Курсы, задания, оценки и файлы'
      : 'Courses, assignments, grades & files';
  String get privacyEndpointInsSub => isRu
      ? 'Транскрипт, GPA и семестры'
      : 'Transcript, GPA & semester records';
  String get privacyEndpointEdupageSub =>
      isRu ? 'Официальное расписание пар' : 'Official lecture timetable';
  String get privacyBadgeDirect => isRu ? 'Напрямую' : 'Direct';
  String get privacyBadgeOfficial => isRu ? 'Официально' : 'Official';
  String get privacyCard3Overline =>
      isRu ? 'ХРАНЕНИЕ И ОЧИСТКА' : 'STORAGE & REMOVAL';
  String get privacyCard3Title =>
      isRu ? 'Мгновенное удаление при выходе' : 'Offline Access & Instant Wipe';
  String get privacyCard3Desc => isRu
      ? 'Расписание, оценки и скачанные файлы хранятся на телефоне, чтобы приложение мгновенно открывалось даже без интернета.'
      : 'Your schedule, grades, and downloaded documents are saved on your phone so the app opens instantly even without internet.';
  String get privacyLogoutWipeNote => isRu
      ? 'Полное удаление при выходе: при нажатии «Выйти из аккаунта» все пароли, история, загруженные материалы и черновики стираются с телефона.'
      : 'Instant wipe on sign out: tapping Log out permanently removes all saved passwords, downloaded files, and drafts from your phone.';
  String privacyClearFilesBtn(String size) =>
      isRu ? 'Очистить сохранённые файлы ($size)' : 'Clear Saved Files ($size)';
  String get privacyCard4Overline => isRu ? 'ОТКРЫТЫЙ КОД' : 'OPEN SOURCE';
  String get privacyCard4Title =>
      isRu ? 'Полная прозрачность кода' : 'Open Source & Transparent';
  String get privacyCard4Desc => isRu
      ? 'Весь исходный код приложения открыт для проверки любым студентом или преподавателем. В приложении нет рекламы, скрытой телеметрии и сбора статистики.'
      : 'Every line of code in the app is public and open for inspection by any student or faculty member. Zero ads, zero hidden analytics, zero tracking.';
  String get privacyInspectGithubBtn =>
      isRu ? 'Проверить код на GitHub' : 'Inspect Source on GitHub';
  String get privacyFooterNote => isRu
      ? 'Inha App • Независимый клиент от студентов для студентов IUT'
      : 'Inha App • Independent student-built client for IUT';

  // #8 Submission Drafts
  String get draftsTitle => isRu ? 'Файлы и черновики' : 'Submission Drafts';
  String get draftsSub => isRu
      ? 'Неотправленные черновики и подготовленные файлы'
      : 'Unsubmitted eClass drafts & prepared files';
  String get draftsWorkspaceOverline =>
      isRu ? 'ЧЕРНОВИКИ РАБОТ' : 'ASSIGNMENT WORKSPACE';
  String get draftsOverviewTitle =>
      isRu ? 'Подготовленные файлы' : 'Draft Staging Overview';
  String get draftsOverviewDesc => isRu
      ? 'Неотправленные попытки и личные файлы в eClass, а также файлы, подготовленные на телефоне.'
      : 'Unsubmitted attempts, personal files saved on eClass, and files prepared on your phone.';
  String get draftsOnEclassLabel => isRu ? 'На eClass' : 'On eClass';
  String get draftsOnPhoneLabel => isRu ? 'На телефоне' : 'On Phone';
  String get draftsSavedCountLabel => isRu ? 'на портале' : 'saved items';
  String get draftsLocalCountLabel => isRu ? 'подготовлено' : 'staged locally';
  String draftsFilterAll(int n) => isRu ? 'Все ($n)' : 'All Drafts ($n)';
  String draftsFilterEclass(int n) => isRu ? 'eClass ($n)' : 'eClass ($n)';
  String draftsFilterLocal(int n) =>
      isRu ? 'На телефоне ($n)' : 'On Phone ($n)';
  String draftsEclassSectionTitle(int n) =>
      isRu ? 'ЧЕРНОВИКИ ЗАДАНИЙ В ECLASS ($n)' : 'ECLASS UNSUBMITTED DRAFTS ($n)';
  String draftsPrivateFilesSectionTitle(int n) =>
      isRu ? 'ЛИЧНЫЕ ФАЙЛЫ ECLASS ($n)' : 'ECLASS SAVED FILES ($n)';
  String get draftsPrivateFilesSectionSub => isRu
      ? 'Файлы из вашего личного хранилища eClass — их можно открыть или сразу прикрепить к заданию.'
      : 'Files stored in your personal eClass area — open or attach directly to any assignment.';
  String get draftsRootFolderLabel =>
      isRu ? 'Мои файлы eClass' : 'eClass My Files';
  String get draftsOpenFileBtn => isRu ? 'Открыть' : 'Open';
  String get draftsAttachToAssignmentBtn =>
      isRu ? 'Прикрепить к заданию' : 'Attach to Assignment';
  String get draftsChooseActionTitle =>
      isRu ? 'Выберите способ отправки' : 'Choose Submission Mode';
  String get draftsReplaceFileBtn => isRu ? 'Заменить файл' : 'Replace File';
  String get draftsSubmitForGradingBtn =>
      isRu ? 'Отправить на проверку' : 'Submit for Grading';
  String draftsLocalSectionTitle(int n) =>
      isRu ? 'ФАЙЛЫ НА ТЕЛЕФОНЕ ($n)' : 'STAGED ON THIS PHONE ($n)';
  String get draftsLocalSectionSub => isRu
      ? 'Сохранены только на вашем телефоне и ещё не загружены в eClass.'
      : 'Stored only on your phone and not yet uploaded to eClass.';
  String get draftsOnDeviceBadge => isRu ? 'На телефоне' : 'On Device';
  String get draftsUploadAsDraftBtn => isRu ? 'В черновик' : 'Upload Draft';
  String get draftsSubmitNowBtn => isRu ? 'Сдать сейчас' : 'Submit Now';
  String get draftsStageNewBtn =>
      isRu ? 'Добавить локальный черновик' : 'Add Local Draft';
  String get draftsPickAssignmentTitle =>
      isRu ? 'Выберите задание для черновика' : 'Pick Assignment for Draft';
  String get draftsEmptyTitle => isRu ? 'Черновиков пока нет' : 'No Drafts Yet';
  String get draftsEmptySub => isRu
      ? 'Когда сохраните работу как черновик на eClass или подготовите файл заранее, он появится здесь.'
      : 'When you save a work-in-progress on eClass or prepare a file on your phone, it will appear here.';
  String get draftStagedToast =>
      isRu ? 'Файл сохранён в черновиках' : 'File staged in drafts';
  String get draftRemovedToast =>
      isRu ? 'Локальный черновик удалён' : 'Local draft removed';
  String get draftSubmittedToast =>
      isRu ? 'Работа отправлена!' : 'Draft submitted!';

  // #9 Optional Diagnostics & Logs
  String get logsTitle => isRu ? 'Диагностика и логи' : 'Diagnostics & Logs';
  String get logsSub => isRu
      ? 'Необязательный журнал ошибок без личных данных'
      : 'Optional error log with zero personal data';
  String get logsOptInTitle =>
      isRu ? 'Записывать диагностические логи' : 'Record diagnostic logs';
  String get logsOptInSub => isRu
      ? 'По умолчанию выключено — включайте только по желанию при проблемах'
      : 'Off by default — turn on only if you want to troubleshoot issues';
  String get logsPrivacyNotice => isRu
      ? 'Личные данные не записываются: ваши пароли, Student ID, коды доступа и оценки автоматически скрываются (***). Логи хранятся только на телефоне и никуда не отправляются сами.'
      : 'No personal data is ever recorded: your passwords, Student ID, access tokens, and grades are automatically masked (***). Logs stay on your phone and are never sent automatically.';
  String get logsFilterAll => isRu ? 'Все' : 'All';
  String get logsFilterErrors => isRu ? 'Ошибки' : 'Errors';
  String get logsFilterCrashes => isRu ? 'Сбои' : 'Crashes';
  String get logsCopyBtn => isRu ? 'Скопировать логи' : 'Copy Logs';
  String get logsCopiedToast =>
      isRu ? 'Логи скопированы в буфер обмена' : 'Logs copied to clipboard';
  String get logsClearBtn => isRu ? 'Очистить' : 'Clear';
  String get logsClearedToast => isRu ? 'Логи очищены' : 'Logs cleared';
  String get logsEmptyTitle => isRu ? 'Записей пока нет' : 'No Log Entries Yet';
  String get logsEmptySub => isRu
      ? 'Запись диагностических логов отключена или сбоев ещё не возникало.'
      : 'Diagnostic logging is off or no events have been recorded yet.';
  String get logsStatusOn => isRu ? 'Вкл' : 'ON';
  String get logsStatusOff => isRu ? 'Выкл' : 'OFF';

  String get crashBannerTitle =>
      isRu ? 'Обнаружен сбой в приложении' : 'Unexpected App Error Detected';
  String get crashBannerDesc => isRu
      ? 'Рекомендуем включить логи и скопировать отчёт об ошибке, чтобы мы могли быстро её исправить. Пароли и личные данные в отчёт не попадают.'
      : 'We strongly recommend enabling logs and copying the crash report so it can be fixed quickly. Passwords and personal data are never included.';
  String get crashBannerEnableBtn =>
      isRu ? 'Включить логи и открыть отчёт' : 'Enable Logs & Open Report';
  String get crashBannerViewOnlyBtn =>
      isRu ? 'Открыть без включения' : 'View Report Only';
  String get crashBannerDismissBtn => isRu ? 'Не сейчас' : 'Not Now';
  String get crashBannerReportBtn =>
      isRu ? 'Отправить на GitHub' : 'Report on GitHub';
  String get logsReportGithubBtn =>
      isRu ? 'Создать Issue на GitHub' : 'Open GitHub Issue';
  String get logsReportOpenFailedToast => isRu
      ? 'Не удалось открыть GitHub — отчёт скопирован в буфер'
      : 'Could not open GitHub — report copied to clipboard';

  String get privacyCardLogsOverline =>
      isRu ? 'ДИАГНОСТИКА ПО ЖЕЛАНИЮ' : 'OPTIONAL DIAGNOSTICS';
  String get privacyCardLogsTitle =>
      isRu ? 'Логи без личных данных' : 'Optional Logs with Zero Personal Data';
  String get privacyCardLogsDesc => isRu
      ? 'Запись диагностических логов по умолчанию выключена и работает только по вашему желанию (или предлагается после сбоя). В логах никогда не сохраняются пароли, Student ID, оценки или личные данные — они автоматически вырезаются.'
      : 'Diagnostic logging is turned off by default and is completely optional (only suggested if an error occurs). Logs never collect passwords, Student ID, grades, or personal information — any sensitive fields are automatically stripped.';
  String get privacyOpenLogsBtn =>
      isRu ? 'Настроить диагностические логи' : 'Configure Diagnostic Logs';

  String get avatarSheetTitle => isRu ? 'Фото профиля' : 'Profile Photo';
  String get avatarSheetSub => isRu
      ? 'Хранится только на вашем устройстве'
      : 'Stored locally on your device only';
  String get avatarChooseGallery =>
      isRu ? 'Выбрать из галереи' : 'Choose from Gallery';
  String get avatarResetBtn =>
      isRu ? 'Сбросить к фото из eClass' : 'Reset to eClass Photo';
  String get avatarUpdatedToast =>
      isRu ? 'Аватарка обновлена' : 'Profile photo updated';
  String get avatarResetToast =>
      isRu ? 'Аватарка сброшена' : 'Profile photo reset';
  String get avatarErrorToast => isRu
      ? 'Не удалось обновить аватарку'
      : 'Failed to update profile photo';
  String get avatarUploadEclassTitle =>
      isRu ? 'Также загрузить в eClass' : 'Also upload to eClass';
  String get avatarUploadEclassSub => isRu
      ? 'Фото увидят преподаватели и одногруппники'
      : 'Visible to professors and classmates';
  String get avatarUploadedEclassToast => isRu
      ? 'Аватарка обновлена и загружена в eClass'
      : 'Profile photo updated & uploaded to eClass';
  String get avatarUploadEclassFailedToast => isRu
      ? 'Сохранено локально, но не удалось загрузить в eClass'
      : 'Saved locally, but upload to eClass failed';
}
