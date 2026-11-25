// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'ICEX Alumni';

  @override
  String get loginTitle => 'Tu red profesional ICEX';

  @override
  String get loginSubtitle => 'La comunidad privada de becarios y alumni de todas las promociones.';

  @override
  String get loginButton => 'Entrar con mi cuenta ICEX Alumni';

  @override
  String get loginPrivacyNote =>
      'Solo para socios verificados de ICEX Alumni. Usamos tu cuenta de la web de la asociación.';

  @override
  String get loginInProgress => 'Conectando con ICEX Alumni…';

  @override
  String get loginError => 'No se pudo iniciar sesión. Inténtalo de nuevo.';

  @override
  String get accessDeniedTitle => 'Acceso solo para socios';

  @override
  String get accessDeniedBody =>
      'La cuenta con la que has entrado no figura como socia de ICEX Alumni. Hazte socio en la web de la asociación o entra con otra cuenta.';

  @override
  String get accessDeniedWeb => 'Hacerme socio de ICEX Alumni';

  @override
  String get accessDeniedRetry => 'Volver al inicio';

  @override
  String get navHome => 'Inicio';

  @override
  String get navNetwork => 'Red';

  @override
  String get navMap => 'Mapa';

  @override
  String get navMessages => 'Mensajes';

  @override
  String get navOrientador => 'Orientador';

  @override
  String get navNews => 'Novedades';

  @override
  String get navProfile => 'Perfil';

  @override
  String get navNotifications => 'Notificaciones';

  @override
  String get navSettings => 'Ajustes';

  @override
  String unreadBadge(int count) {
    return '$count sin leer';
  }

  @override
  String get demoBanner =>
      'Comunidad de demostración · Perfiles, publicaciones, oportunidades y conversaciones ficticios.';

  @override
  String get homeTitle => 'Inicio · ICEX Alumni';

  @override
  String get followers => 'Seguidores';

  @override
  String get following => 'Siguiendo';

  @override
  String get followersEmpty => 'Aún no tiene seguidores.';

  @override
  String get followingEmpty => 'Aún no sigue a nadie.';

  @override
  String get composerHint => 'Comparte una novedad con la red ICEX Alumni…';

  @override
  String get composerPhoto => 'Foto';

  @override
  String get composerOffer => 'Oferta';

  @override
  String get composerPublish => 'Publicar';

  @override
  String get composerPublishing => 'Publicando…';

  @override
  String get composerType => 'Tipo de publicación';

  @override
  String get postTypeGeneral => 'General';

  @override
  String get postTypeEvent => 'Evento';

  @override
  String get postTypeJob => 'Oportunidad laboral';

  @override
  String get postTypeAchievement => 'Logro';

  @override
  String get postTypeOfficial => 'Comunicado de la asociación';

  @override
  String get recommend => 'Recomendar';

  @override
  String get comment => 'Comentar';

  @override
  String get share => 'Compartir';

  @override
  String get send => 'Enviar';

  @override
  String recommendationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recomendaciones',
      one: '1 recomendación',
    );
    return '$_temp0';
  }

  @override
  String commentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comentarios',
      one: '1 comentario',
    );
    return '$_temp0';
  }

  @override
  String sharedFrom(String name) {
    return 'Compartido de $name';
  }

  @override
  String get commentHint => 'Escribe un comentario…';

  @override
  String get commentsTitle => 'Comentarios';

  @override
  String get noComments => 'Sé la primera persona en comentar.';

  @override
  String get shareInNetwork => 'Compartir en la red';

  @override
  String get shareExternal => 'Compartir fuera de la app';

  @override
  String get report => 'Denunciar';

  @override
  String get deletePost => 'Eliminar publicación';

  @override
  String get loadMore => 'Ver más';

  @override
  String get pinned => 'Fijado';

  @override
  String get communityStatsTitle => 'La comunidad en cifras';

  @override
  String get statsAlumni => 'Alumni';

  @override
  String get statsActive => 'Activos';

  @override
  String get statsCountries => 'Países';

  @override
  String get statsPromotions => 'Promociones';

  @override
  String get suggestionsTitle => 'Personas que quizá conozcas';

  @override
  String get newsTitle => 'Novedades de la asociación';

  @override
  String newsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comunicados de la asociación',
      one: '1 comunicado de la asociación',
    );
    return '$_temp0';
  }

  @override
  String get networkTitle => 'Red de alumni';

  @override
  String networkSubtitle(int members, int countries, int promos) {
    return '$members miembros · $countries países · $promos promociones';
  }

  @override
  String get tabAll => 'Todos';

  @override
  String tabMyPromo(int promo) {
    return 'Mi promoción ($promoª)';
  }

  @override
  String get tabAbroad => 'En el exterior';

  @override
  String get tabActive => 'ACTIVO';

  @override
  String get searchDirectoryHint => 'Nombre, promoción, empresa, ciudad…';

  @override
  String get searchDirectoryLabel => 'Buscar en el directorio';

  @override
  String get allPromotions => 'Todas las promociones';

  @override
  String promotionLabel(int promo) {
    return '$promoª promoción';
  }

  @override
  String get allPhases => 'Todas las fases';

  @override
  String resultsCount(int shown, int total) {
    return '$shown de $total resultados';
  }

  @override
  String get noResults => 'No hay alumni que coincidan con tu búsqueda.';

  @override
  String get follow => 'Seguir';

  @override
  String get followingButton => 'Siguiendo';

  @override
  String get phase0 => 'Fase 0';

  @override
  String get phase1 => 'Fase I';

  @override
  String get phase2 => 'Fase II';

  @override
  String get phaseActive => 'ACTIVO';

  @override
  String get mapTitle => 'Mapa de la comunidad';

  @override
  String mapSubtitle(int alumni, int clubs) {
    return '$alumni alumni · $clubs clubs en esta vista';
  }

  @override
  String get mapFilters => 'Filtros';

  @override
  String get mapShowClubs => 'Mostrar clubs locales';

  @override
  String get mapPhases => 'Fases';

  @override
  String mapClusterTitle(int count) {
    return '$count alumni en esta zona';
  }

  @override
  String get mapZoomIn => 'Acercar para ver más';

  @override
  String clubMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count miembros',
      one: '1 miembro',
    );
    return '$_temp0';
  }

  @override
  String get clubJoin => 'Unirme al club';

  @override
  String get clubLeave => 'Salir del club';

  @override
  String get clubUpcoming => 'Próximos eventos';

  @override
  String get clubNoEvents => 'No hay eventos programados.';

  @override
  String get eventRegister => 'Inscribirme';

  @override
  String get eventRegistered => 'Inscrito';

  @override
  String get eventWaitlist => 'En lista de espera';

  @override
  String get eventCancel => 'Cancelar inscripción';

  @override
  String eventSeats(int taken, int total) {
    return '$taken / $total plazas';
  }

  @override
  String get eventOnline => 'Online';

  @override
  String get messagesTitle => 'Mensajes';

  @override
  String messagesSubtitle(int conversations, int unread) {
    return '$conversations conversaciones · $unread mensajes sin leer';
  }

  @override
  String get conversationsTitle => 'Conversaciones';

  @override
  String get noConversations =>
      'Aún no tienes conversaciones. Escribe a un alumni desde su perfil o desde una publicación.';

  @override
  String get messageHint => 'Escribe un mensaje…';

  @override
  String get messageSend => 'Enviar mensaje';

  @override
  String get messageCategory => 'Categoría';

  @override
  String newConversation(String name) {
    return 'Nueva conversación con $name';
  }

  @override
  String get messageSending => 'Enviando…';

  @override
  String get messageSent => 'Enviado';

  @override
  String get messageRead => 'Leído';

  @override
  String get messageFailed => 'No enviado. Toca para reintentar.';

  @override
  String get back => 'Volver';

  @override
  String get catSolicitudInformacion => 'Solicitud de información';

  @override
  String get catOportunidadLaboral => 'Oportunidad laboral';

  @override
  String get catMentoria => 'Mentoría';

  @override
  String get catNetworking => 'Networking';

  @override
  String get catEvento => 'Evento';

  @override
  String get catColaboracionEmpresarial => 'Colaboración empresarial';

  @override
  String get orientadorTitle => 'Orientador';

  @override
  String get orientadorPhase => 'Fase';

  @override
  String get orientadorCountry => 'País de interés';

  @override
  String get orientadorSector => 'Sector';

  @override
  String get orientadorHint =>
      'Ej.: Termino la beca en Berlín y quiero preparar las entrevistas de Fase II…';

  @override
  String get orientadorSubmit => 'Pedir orientación';

  @override
  String get orientadorLoading => 'Buscando…';

  @override
  String get orientadorSteps => 'Pasos recomendados';

  @override
  String get orientadorAlumni => 'Alumni con quien hablar';

  @override
  String orientadorRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Te quedan $count consultas hoy',
      one: 'Te queda 1 consulta hoy',
    );
    return '$_temp0';
  }

  @override
  String get orientadorRateLimited => 'Has alcanzado el límite de consultas de hoy. Vuelve mañana.';

  @override
  String get profileTrajectory => 'Trayectoria';

  @override
  String get profileAbout => 'Sobre mí';

  @override
  String get profileEdit => 'Editar perfil';

  @override
  String get profileSendMessage => 'Enviar mensaje';

  @override
  String get profilePosts => 'Publicaciones';

  @override
  String get profileCurrent => 'Actualidad';

  @override
  String get profileBlock => 'Bloquear';

  @override
  String get profileUnblock => 'Desbloquear';

  @override
  String profileBlockConfirm(String name) {
    return '¿Bloquear a $name? No podrá ver tu contenido ni escribirte, y dejaréis de seguiros.';
  }

  @override
  String get profileNotAvailable => 'Este perfil no está disponible.';

  @override
  String get fieldName => 'Nombre';

  @override
  String get fieldRole => 'Cargo';

  @override
  String get fieldCompany => 'Empresa';

  @override
  String get fieldPhase => 'Fase';

  @override
  String get fieldCountry => 'País';

  @override
  String get fieldCity => 'Ciudad';

  @override
  String get fieldSector => 'Sector';

  @override
  String get fieldBio => 'Sobre mí';

  @override
  String get fieldFrom => 'Desde';

  @override
  String get fieldTo => 'Hasta';

  @override
  String get addExperience => 'Añadir experiencia';

  @override
  String get changePhoto => 'Cambiar foto';

  @override
  String get save => 'Guardar';

  @override
  String get saved => 'Cambios guardados';

  @override
  String get cancel => 'Cancelar';

  @override
  String get confirm => 'Confirmar';

  @override
  String get delete => 'Eliminar';

  @override
  String get requiredField => 'Campo obligatorio';

  @override
  String get notificationsTitle => 'Notificaciones';

  @override
  String get notificationsEmpty => 'No tienes notificaciones.';

  @override
  String get markAllRead => 'Marcar todo como leído';

  @override
  String notifFollow(String name) {
    return '$name empezó a seguirte';
  }

  @override
  String notifFollowMany(String name, int others) {
    return '$name y $others más empezaron a seguirte';
  }

  @override
  String notifRecommendation(String name) {
    return '$name recomendó tu publicación';
  }

  @override
  String notifRecommendationMany(String name, int others) {
    return '$name y $others más recomendaron tu publicación';
  }

  @override
  String notifComment(String name) {
    return '$name comentó tu publicación';
  }

  @override
  String notifCommentMany(String name, int others) {
    return '$name y $others más comentaron tu publicación';
  }

  @override
  String notifNews(String title) {
    return 'Novedad: $title';
  }

  @override
  String get notifGeneric => 'Tienes novedades';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsNotifications => 'Preferencias de notificación';

  @override
  String get settingsPrivacy => 'Privacidad';

  @override
  String get settingsExport => 'Exportar mis datos';

  @override
  String get settingsExportDone => 'Tus datos están listos para compartir o guardar.';

  @override
  String get settingsDelete => 'Borrar mi cuenta';

  @override
  String get settingsDeleteBody =>
      'Se borrarán tu perfil, publicaciones, comentarios, mensajes enviados, imágenes y preferencias. No se puede deshacer. Escribe BORRAR MI CUENTA para confirmar.';

  @override
  String get settingsDeleteConfirmWord => 'BORRAR MI CUENTA';

  @override
  String get settingsSignOut => 'Cerrar sesión';

  @override
  String get settingsBlocked => 'Personas bloqueadas';

  @override
  String settingsVersion(String version) {
    return 'Versión $version';
  }

  @override
  String get prefPushMessages => 'Mensajes';

  @override
  String get prefPushSocial => 'Seguidores, recomendaciones y comentarios';

  @override
  String get prefPushEvents => 'Eventos de mis clubs';

  @override
  String get prefPushNews => 'Novedades de la asociación';

  @override
  String get prefEmailConsent => 'Acepto recibir comunicaciones por email de ICEX Alumni';

  @override
  String get prefEmailNews => 'Novedades por email';

  @override
  String get prefEmailDigest => 'Resumen semanal por email';

  @override
  String get prefPushSection => 'Notificaciones push';

  @override
  String get prefEmailSection => 'Email';

  @override
  String get privacyIntro => 'Elige quién ve cada dato de tu perfil.';

  @override
  String get privacyEveryone => 'Todos los socios';

  @override
  String get privacyFollowers => 'Solo mis seguidores';

  @override
  String get privacyOnlyMe => 'Solo yo';

  @override
  String get privacyLocation => 'Ubicación en el mapa';

  @override
  String get privacySuggestions => 'Aparecer en sugerencias y en el Orientador';

  @override
  String get errorGeneric => 'Algo ha fallado. Inténtalo de nuevo.';

  @override
  String get errorNetwork => 'Sin conexión. Mostramos lo último guardado.';

  @override
  String get errorForbidden => 'No tienes permiso para hacer esto.';

  @override
  String get errorNotFound => 'No encontrado.';

  @override
  String get retry => 'Reintentar';

  @override
  String get loading => 'Cargando…';

  @override
  String get emptyFeed => 'Sigue a otros alumni para ver aquí sus publicaciones.';

  @override
  String get timeNow => 'ahora';

  @override
  String timeMinutes(int n) {
    return 'hace $n min';
  }

  @override
  String timeHours(int n) {
    return 'hace $n h';
  }

  @override
  String get timeYesterday => 'ayer';

  @override
  String timeDays(int n) {
    return 'hace $n días';
  }

  @override
  String get reportTitle => 'Denunciar contenido';

  @override
  String get reportSpam => 'Spam';

  @override
  String get reportHarassment => 'Acoso';

  @override
  String get reportInappropriate => 'Contenido inapropiado';

  @override
  String get reportPersonalData => 'Datos personales';

  @override
  String get reportImpersonation => 'Suplantación';

  @override
  String get reportOther => 'Otro motivo';

  @override
  String get reportThanks => 'Gracias. El equipo de moderación lo revisará.';

  @override
  String get close => 'Cerrar';

  @override
  String get moreOptions => 'Más opciones';

  @override
  String get copyText => 'Copiar texto';

  @override
  String get copied => 'Copiado';

  @override
  String viewProfileOf(String name) {
    return 'Ver el perfil de $name';
  }

  @override
  String get deletePostBody =>
      'La publicación desaparecerá de tu perfil y del feed. No se puede deshacer.';

  @override
  String get shareInNetworkHint => 'Añade tu opinión (opcional)';

  @override
  String get sharedDone => 'Compartido en tu red';

  @override
  String get shareDefaultText => 'Comparto esta publicación';

  @override
  String get composeTitle => 'Crear publicación';

  @override
  String get composeHint => '¿Qué quieres compartir con la comunidad ICEX Alumni?';

  @override
  String get composeDiscardTitle => '¿Descartar la publicación?';

  @override
  String get composeDiscardBody => 'Perderás lo que has escrito.';

  @override
  String get keepEditing => 'Seguir editando';

  @override
  String get discard => 'Descartar';

  @override
  String get removePhoto => 'Quitar foto';

  @override
  String get composerEvent => 'Evento';

  @override
  String get composerPublished => 'Publicado';

  @override
  String get exploreNetwork => 'Explorar la red';

  @override
  String get seeAll => 'Ver todo';

  @override
  String get dismiss => 'Descartar';

  @override
  String get postTitle => 'Publicación';

  @override
  String get profileNoPosts => 'Aún no hay publicaciones.';

  @override
  String get followsYou => 'Te sigue';

  @override
  String get postsLabel => 'publicaciones';

  @override
  String profileBlocked(String name) {
    return 'Has bloqueado a $name';
  }

  @override
  String get today => 'Hoy';

  @override
  String get yesterday => 'Ayer';

  @override
  String get messageFailedTapRetry => 'No enviado · toca para reintentar';

  @override
  String get noConversationsFilter => 'No hay conversaciones en esta categoría.';

  @override
  String get clearSearch => 'Borrar búsqueda';

  @override
  String get filters => 'Filtros';

  @override
  String get directoryGroups => 'Grupos de alumni';

  @override
  String get clearFilters => 'Quitar filtros';

  @override
  String get showResults => 'Ver resultados';

  @override
  String get notificationsNew => 'Nuevas';

  @override
  String get notificationsEarlier => 'Anteriores';

  @override
  String get change => 'Cambiar';

  @override
  String get unsavedChangesTitle => '¿Descartar los cambios?';

  @override
  String get unsavedChangesBody => 'Tienes cambios sin guardar en tu perfil.';

  @override
  String get loginFeatureWorld => 'Encuentra alumni en cualquier país';

  @override
  String get loginFeaturePromo => 'Conecta con tu promoción y tu club';

  @override
  String get loginFeatureOpportunities => 'Descubre ofertas, mentorías y eventos';

  @override
  String get loginNotMember => '¿Aún no eres socio?';

  @override
  String get loginJoin => 'Hazte socio';

  @override
  String get accessDeniedOtherAccount => 'Entrar con otra cuenta';

  @override
  String linkOpenError(String url) {
    return 'No se pudo abrir $url';
  }

  @override
  String get devLoginTitle => 'Modo desarrollo';

  @override
  String get devLoginHint =>
      'Entra directamente como una cuenta de prueba, sin navegador. No aparece en producción.';

  @override
  String get readMore => 'Leer más';

  @override
  String get showLess => 'Mostrar menos';

  @override
  String homeGreeting(String name) {
    return 'Hola, $name';
  }

  @override
  String get homeSubtitle => 'Lo último de tu red ICEX Alumni';

  @override
  String get orientadorIntro =>
      'Elige tu situación y te proponemos pasos concretos y alumni con quienes hablar.';

  @override
  String get orientadorQuestion => '¿En qué te podemos orientar?';

  @override
  String get orientadorContext => 'Tu situación';

  @override
  String get newsEmpty => 'Todavía no hay comunicados de la asociación.';

  @override
  String get betaBadge => 'BETA';

  @override
  String get betaSubtitle =>
      'Estás probando la beta de la red profesional de ICEX Alumni. Crea tu cuenta y cuéntanos qué te parece.';

  @override
  String get betaCreateAccount => 'Crear cuenta';

  @override
  String get betaHaveAccount => 'Ya tengo cuenta';

  @override
  String get betaPrivacyNote =>
      'Beta abierta: no hace falta ser socio. Más adelante podrás vincular tu cuenta de ICEX Alumni.';

  @override
  String get authEmail => 'Correo electrónico';

  @override
  String get authPassword => 'Contraseña';

  @override
  String get authPasswordHint => 'Mínimo 8 caracteres';

  @override
  String get authName => 'Nombre y apellidos';

  @override
  String get authPromo => 'Promoción ICEX (opcional, si eres alumni)';

  @override
  String get authPromoNone => 'Sin promoción';

  @override
  String get authShowPassword => 'Mostrar contraseña';

  @override
  String get authHidePassword => 'Ocultar contraseña';

  @override
  String get authAcceptPrivacy => 'He leído y acepto la política de privacidad';

  @override
  String get authReadPrivacy => 'Leer la política de privacidad';

  @override
  String get authSignInTitle => 'Entrar';

  @override
  String get authSignInButton => 'Entrar';

  @override
  String get authSignUpTitle => 'Crear cuenta';

  @override
  String get authSignUpButton => 'Crear mi cuenta';

  @override
  String get authForgot => '¿Has olvidado tu contraseña?';

  @override
  String get authNoAccount => '¿No tienes cuenta? Crear una';

  @override
  String get authHaveAccount => '¿Ya tienes cuenta? Entrar';

  @override
  String get authInvalidEmail => 'Escribe un correo válido';

  @override
  String get authShortPassword => 'La contraseña debe tener al menos 8 caracteres';

  @override
  String get authNameRequired => 'Escribe tu nombre (mínimo 2 letras)';

  @override
  String get authMustAcceptPrivacy => 'Tienes que aceptar la política de privacidad';

  @override
  String get authErrInvalidCredentials => 'Correo o contraseña incorrectos.';

  @override
  String get authErrUserExists =>
      'Ya hay una cuenta con este correo. Prueba a entrar o a recuperar la contraseña.';

  @override
  String get authErrWeakPassword =>
      'La contraseña es demasiado débil. Usa al menos 8 caracteres y mezcla letras y números.';

  @override
  String get authErrRateLimit =>
      'Demasiados intentos seguidos. Espera unos minutos y vuelve a probar.';

  @override
  String get authErrSignupClosed => 'El registro está cerrado en este momento.';

  @override
  String get authErrSamePassword => 'La contraseña nueva tiene que ser distinta de la anterior.';

  @override
  String get authForgotTitle => 'Recuperar contraseña';

  @override
  String get authForgotIntro =>
      'Te enviaremos un correo con un enlace para elegir una contraseña nueva.';

  @override
  String get authForgotSend => 'Enviar enlace';

  @override
  String get authForgotSent =>
      'Si hay una cuenta con ese correo, te acabamos de enviar el enlace. Ábrelo desde este móvil.';

  @override
  String get authCheckEmailTitle => 'Revisa tu correo';

  @override
  String authCheckEmailBody(String email) {
    return 'Te hemos enviado un enlace a $email. Ábrelo desde este móvil para activar tu cuenta.';
  }

  @override
  String get authCheckEmailSpam => '¿No llega? Mira en la carpeta de correo no deseado.';

  @override
  String get authResend => 'Reenviar el correo';

  @override
  String get authResent => 'Correo reenviado.';

  @override
  String get authConfirmedSignIn => 'Ya lo he confirmado: entrar';

  @override
  String get authBack => 'Volver';

  @override
  String get authNewPasswordTitle => 'Elige una contraseña nueva';

  @override
  String get authNewPasswordButton => 'Guardar y entrar';

  @override
  String get authRepeatPassword => 'Repite la contraseña';

  @override
  String get authPasswordsDontMatch => 'Las contraseñas no coinciden';

  @override
  String get settingsFeedback => 'Enviar comentarios de la beta';

  @override
  String get settingsPrivacyPolicy => 'Política de privacidad';

  @override
  String get editPromo => 'Promoción ICEX';

  @override
  String get editPromoHelp => 'Si eres alumni, indica tu promoción. Aparecerá en tu perfil.';
}
