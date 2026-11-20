class S {
  final String lang;
  const S(this.lang);

  bool get isRu => lang == 'ru';

  String get appTitle => 'Inha App';
  String get appSubtitle =>
      isRu ? 'eClass • INS • Расписание' : 'eClass • INS • Timetable';

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
  String get studentId =>
      isRu ? 'Student ID (например U2210001)' : 'Student ID (e.g. U2210001)';
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
  String get tabAssignments => isRu ? 'Задания' : 'Assignments';
  String get tabGrades => isRu ? 'Оценки' : 'Grades';
  String get tabAttendance => isRu ? 'Посещаемость' : 'Attendance';
  String get tabFiles => isRu ? 'Файлы' : 'Files';
  String get syllabus => isRu ? 'Силлабус' : 'Syllabus';
  String get openSyllabus => isRu ? 'Открыть силлабус' : 'Open syllabus';
  String get refresh => isRu ? 'Обновить' : 'Refresh';
  String get offlineCache => isRu ? 'Локальная база SQLite' : 'Local SQLite DB';

  // Assignments
  String get filterAll => isRu ? 'Все' : 'All';
  String get filterPending => isRu ? 'Несданные' : 'Pending';
  String get filterSubmitted => isRu ? 'Сданные' : 'Submitted';
  String get noAssignments => isRu ? 'Заданий нет' : 'No assignments';
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
  String get recentSessions => isRu ? 'История занятий' : 'Session History';

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

  // INS
  String get insNotConfigured => isRu
      ? 'Введите пароль от INS (ins.inha.uz), чтобы смотреть оценки и транскрипт'
      : 'Enter your INS (ins.inha.uz) password to view grades and transcript';
  String get saveInsPassword => isRu ? 'Сохранить и загрузить' : 'Save & Load';
  String get gpaLabel => 'GPA';
  String get creditsLabel => isRu ? 'Кредиты' : 'Credits';
  String get rankLabel => isRu ? 'Ранг' : 'Rank';
  String get allSemesters => isRu ? 'Все семестры' : 'All semesters';
  String get insLoadError => isRu
      ? 'Не удалось загрузить данные INS. Проверьте пароль и интернет.'
      : 'Failed to load INS data. Check password and network.';

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
      isRu ? 'Фоновая проверка eClass (WorkManager)' : 'Background eClass sync (WorkManager)';
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
}
