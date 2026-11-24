import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('es')];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'ICEX Alumni'**
  String get appTitle;

  /// No description provided for @loginTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu red profesional ICEX'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In es, this message translates to:
  /// **'La comunidad privada de becarios y alumni de las 51 promociones.'**
  String get loginSubtitle;

  /// No description provided for @loginButton.
  ///
  /// In es, this message translates to:
  /// **'Entrar con mi cuenta ICEX Alumni'**
  String get loginButton;

  /// No description provided for @loginPrivacyNote.
  ///
  /// In es, this message translates to:
  /// **'Solo para socios verificados de ICEX Alumni. Usamos tu cuenta de la web de la asociación.'**
  String get loginPrivacyNote;

  /// No description provided for @loginInProgress.
  ///
  /// In es, this message translates to:
  /// **'Conectando con ICEX Alumni…'**
  String get loginInProgress;

  /// No description provided for @loginError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo iniciar sesión. Inténtalo de nuevo.'**
  String get loginError;

  /// No description provided for @accessDeniedTitle.
  ///
  /// In es, this message translates to:
  /// **'Acceso solo para socios'**
  String get accessDeniedTitle;

  /// No description provided for @accessDeniedBody.
  ///
  /// In es, this message translates to:
  /// **'La cuenta con la que has entrado no figura como socia de ICEX Alumni. Hazte socio en la web de la asociación o entra con otra cuenta.'**
  String get accessDeniedBody;

  /// No description provided for @accessDeniedWeb.
  ///
  /// In es, this message translates to:
  /// **'Hacerme socio de ICEX Alumni'**
  String get accessDeniedWeb;

  /// No description provided for @accessDeniedRetry.
  ///
  /// In es, this message translates to:
  /// **'Volver al inicio'**
  String get accessDeniedRetry;

  /// No description provided for @navHome.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get navHome;

  /// No description provided for @navNetwork.
  ///
  /// In es, this message translates to:
  /// **'Red'**
  String get navNetwork;

  /// No description provided for @navMap.
  ///
  /// In es, this message translates to:
  /// **'Mapa'**
  String get navMap;

  /// No description provided for @navMessages.
  ///
  /// In es, this message translates to:
  /// **'Mensajes'**
  String get navMessages;

  /// No description provided for @navOrientador.
  ///
  /// In es, this message translates to:
  /// **'Orientador'**
  String get navOrientador;

  /// No description provided for @navNews.
  ///
  /// In es, this message translates to:
  /// **'Novedades'**
  String get navNews;

  /// No description provided for @navProfile.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get navProfile;

  /// No description provided for @navNotifications.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get navNotifications;

  /// No description provided for @navSettings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get navSettings;

  /// No description provided for @unreadBadge.
  ///
  /// In es, this message translates to:
  /// **'{count} sin leer'**
  String unreadBadge(int count);

  /// No description provided for @demoBanner.
  ///
  /// In es, this message translates to:
  /// **'Comunidad de demostración · Perfiles, publicaciones, oportunidades y conversaciones ficticios.'**
  String get demoBanner;

  /// No description provided for @homeTitle.
  ///
  /// In es, this message translates to:
  /// **'Inicio · ICEX Alumni'**
  String get homeTitle;

  /// No description provided for @followers.
  ///
  /// In es, this message translates to:
  /// **'Seguidores'**
  String get followers;

  /// No description provided for @following.
  ///
  /// In es, this message translates to:
  /// **'Siguiendo'**
  String get following;

  /// No description provided for @composerHint.
  ///
  /// In es, this message translates to:
  /// **'Comparte una novedad con la red ICEX Alumni…'**
  String get composerHint;

  /// No description provided for @composerPhoto.
  ///
  /// In es, this message translates to:
  /// **'Foto'**
  String get composerPhoto;

  /// No description provided for @composerOffer.
  ///
  /// In es, this message translates to:
  /// **'Oferta'**
  String get composerOffer;

  /// No description provided for @composerPublish.
  ///
  /// In es, this message translates to:
  /// **'Publicar'**
  String get composerPublish;

  /// No description provided for @composerPublishing.
  ///
  /// In es, this message translates to:
  /// **'Publicando…'**
  String get composerPublishing;

  /// No description provided for @composerType.
  ///
  /// In es, this message translates to:
  /// **'Tipo de publicación'**
  String get composerType;

  /// No description provided for @postTypeGeneral.
  ///
  /// In es, this message translates to:
  /// **'General'**
  String get postTypeGeneral;

  /// No description provided for @postTypeEvent.
  ///
  /// In es, this message translates to:
  /// **'Evento'**
  String get postTypeEvent;

  /// No description provided for @postTypeJob.
  ///
  /// In es, this message translates to:
  /// **'Oportunidad laboral'**
  String get postTypeJob;

  /// No description provided for @postTypeAchievement.
  ///
  /// In es, this message translates to:
  /// **'Logro'**
  String get postTypeAchievement;

  /// No description provided for @postTypeOfficial.
  ///
  /// In es, this message translates to:
  /// **'Comunicado de la asociación'**
  String get postTypeOfficial;

  /// No description provided for @recommend.
  ///
  /// In es, this message translates to:
  /// **'Recomendar'**
  String get recommend;

  /// No description provided for @comment.
  ///
  /// In es, this message translates to:
  /// **'Comentar'**
  String get comment;

  /// No description provided for @share.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get share;

  /// No description provided for @send.
  ///
  /// In es, this message translates to:
  /// **'Enviar'**
  String get send;

  /// No description provided for @recommendationsCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 recomendación} other{{count} recomendaciones}}'**
  String recommendationsCount(int count);

  /// No description provided for @commentsCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 comentario} other{{count} comentarios}}'**
  String commentsCount(int count);

  /// No description provided for @sharedFrom.
  ///
  /// In es, this message translates to:
  /// **'Compartido de {name}'**
  String sharedFrom(String name);

  /// No description provided for @commentHint.
  ///
  /// In es, this message translates to:
  /// **'Escribe un comentario…'**
  String get commentHint;

  /// No description provided for @commentsTitle.
  ///
  /// In es, this message translates to:
  /// **'Comentarios'**
  String get commentsTitle;

  /// No description provided for @noComments.
  ///
  /// In es, this message translates to:
  /// **'Sé la primera persona en comentar.'**
  String get noComments;

  /// No description provided for @shareInNetwork.
  ///
  /// In es, this message translates to:
  /// **'Compartir en la red'**
  String get shareInNetwork;

  /// No description provided for @shareExternal.
  ///
  /// In es, this message translates to:
  /// **'Compartir fuera de la app'**
  String get shareExternal;

  /// No description provided for @report.
  ///
  /// In es, this message translates to:
  /// **'Denunciar'**
  String get report;

  /// No description provided for @deletePost.
  ///
  /// In es, this message translates to:
  /// **'Eliminar publicación'**
  String get deletePost;

  /// No description provided for @loadMore.
  ///
  /// In es, this message translates to:
  /// **'Ver más'**
  String get loadMore;

  /// No description provided for @pinned.
  ///
  /// In es, this message translates to:
  /// **'Fijado'**
  String get pinned;

  /// No description provided for @communityStatsTitle.
  ///
  /// In es, this message translates to:
  /// **'La comunidad en cifras'**
  String get communityStatsTitle;

  /// No description provided for @statsAlumni.
  ///
  /// In es, this message translates to:
  /// **'Alumni'**
  String get statsAlumni;

  /// No description provided for @statsActive.
  ///
  /// In es, this message translates to:
  /// **'Activos'**
  String get statsActive;

  /// No description provided for @statsCountries.
  ///
  /// In es, this message translates to:
  /// **'Países'**
  String get statsCountries;

  /// No description provided for @statsPromotions.
  ///
  /// In es, this message translates to:
  /// **'Promociones'**
  String get statsPromotions;

  /// No description provided for @suggestionsTitle.
  ///
  /// In es, this message translates to:
  /// **'Personas que quizá conozcas'**
  String get suggestionsTitle;

  /// No description provided for @newsTitle.
  ///
  /// In es, this message translates to:
  /// **'Novedades de la asociación'**
  String get newsTitle;

  /// No description provided for @newsCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 comunicado de la asociación} other{{count} comunicados de la asociación}}'**
  String newsCount(int count);

  /// No description provided for @networkTitle.
  ///
  /// In es, this message translates to:
  /// **'Red de alumni'**
  String get networkTitle;

  /// No description provided for @networkSubtitle.
  ///
  /// In es, this message translates to:
  /// **'{members} miembros · {countries} países · {promos} promociones'**
  String networkSubtitle(int members, int countries, int promos);

  /// No description provided for @tabAll.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get tabAll;

  /// No description provided for @tabMyPromo.
  ///
  /// In es, this message translates to:
  /// **'Mi promoción ({promo}ª)'**
  String tabMyPromo(int promo);

  /// No description provided for @tabAbroad.
  ///
  /// In es, this message translates to:
  /// **'En el exterior'**
  String get tabAbroad;

  /// No description provided for @tabActive.
  ///
  /// In es, this message translates to:
  /// **'ACTIVO'**
  String get tabActive;

  /// No description provided for @searchDirectoryHint.
  ///
  /// In es, this message translates to:
  /// **'Nombre, promoción, empresa, ciudad…'**
  String get searchDirectoryHint;

  /// No description provided for @searchDirectoryLabel.
  ///
  /// In es, this message translates to:
  /// **'Buscar en el directorio'**
  String get searchDirectoryLabel;

  /// No description provided for @allPromotions.
  ///
  /// In es, this message translates to:
  /// **'Todas las promociones'**
  String get allPromotions;

  /// No description provided for @promotionLabel.
  ///
  /// In es, this message translates to:
  /// **'{promo}ª promoción'**
  String promotionLabel(int promo);

  /// No description provided for @allPhases.
  ///
  /// In es, this message translates to:
  /// **'Todas las fases'**
  String get allPhases;

  /// No description provided for @resultsCount.
  ///
  /// In es, this message translates to:
  /// **'{shown} de {total} resultados'**
  String resultsCount(int shown, int total);

  /// No description provided for @noResults.
  ///
  /// In es, this message translates to:
  /// **'No hay alumni que coincidan con tu búsqueda.'**
  String get noResults;

  /// No description provided for @follow.
  ///
  /// In es, this message translates to:
  /// **'Seguir'**
  String get follow;

  /// No description provided for @followingButton.
  ///
  /// In es, this message translates to:
  /// **'Siguiendo'**
  String get followingButton;

  /// No description provided for @phase0.
  ///
  /// In es, this message translates to:
  /// **'Fase 0'**
  String get phase0;

  /// No description provided for @phase1.
  ///
  /// In es, this message translates to:
  /// **'Fase I'**
  String get phase1;

  /// No description provided for @phase2.
  ///
  /// In es, this message translates to:
  /// **'Fase II'**
  String get phase2;

  /// No description provided for @phaseActive.
  ///
  /// In es, this message translates to:
  /// **'ACTIVO'**
  String get phaseActive;

  /// No description provided for @mapTitle.
  ///
  /// In es, this message translates to:
  /// **'Mapa de la comunidad'**
  String get mapTitle;

  /// No description provided for @mapSubtitle.
  ///
  /// In es, this message translates to:
  /// **'{alumni} alumni · {clubs} clubs en esta vista'**
  String mapSubtitle(int alumni, int clubs);

  /// No description provided for @mapFilters.
  ///
  /// In es, this message translates to:
  /// **'Filtros'**
  String get mapFilters;

  /// No description provided for @mapShowClubs.
  ///
  /// In es, this message translates to:
  /// **'Mostrar clubs locales'**
  String get mapShowClubs;

  /// No description provided for @mapPhases.
  ///
  /// In es, this message translates to:
  /// **'Fases'**
  String get mapPhases;

  /// No description provided for @mapClusterTitle.
  ///
  /// In es, this message translates to:
  /// **'{count} alumni en esta zona'**
  String mapClusterTitle(int count);

  /// No description provided for @mapZoomIn.
  ///
  /// In es, this message translates to:
  /// **'Acercar para ver más'**
  String get mapZoomIn;

  /// No description provided for @clubMembers.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 miembro} other{{count} miembros}}'**
  String clubMembers(int count);

  /// No description provided for @clubJoin.
  ///
  /// In es, this message translates to:
  /// **'Unirme al club'**
  String get clubJoin;

  /// No description provided for @clubLeave.
  ///
  /// In es, this message translates to:
  /// **'Salir del club'**
  String get clubLeave;

  /// No description provided for @clubUpcoming.
  ///
  /// In es, this message translates to:
  /// **'Próximos eventos'**
  String get clubUpcoming;

  /// No description provided for @clubNoEvents.
  ///
  /// In es, this message translates to:
  /// **'No hay eventos programados.'**
  String get clubNoEvents;

  /// No description provided for @eventRegister.
  ///
  /// In es, this message translates to:
  /// **'Inscribirme'**
  String get eventRegister;

  /// No description provided for @eventRegistered.
  ///
  /// In es, this message translates to:
  /// **'Inscrito'**
  String get eventRegistered;

  /// No description provided for @eventWaitlist.
  ///
  /// In es, this message translates to:
  /// **'En lista de espera'**
  String get eventWaitlist;

  /// No description provided for @eventCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar inscripción'**
  String get eventCancel;

  /// No description provided for @eventSeats.
  ///
  /// In es, this message translates to:
  /// **'{taken} / {total} plazas'**
  String eventSeats(int taken, int total);

  /// No description provided for @eventOnline.
  ///
  /// In es, this message translates to:
  /// **'Online'**
  String get eventOnline;

  /// No description provided for @messagesTitle.
  ///
  /// In es, this message translates to:
  /// **'Mensajes'**
  String get messagesTitle;

  /// No description provided for @messagesSubtitle.
  ///
  /// In es, this message translates to:
  /// **'{conversations} conversaciones · {unread} mensajes sin leer'**
  String messagesSubtitle(int conversations, int unread);

  /// No description provided for @conversationsTitle.
  ///
  /// In es, this message translates to:
  /// **'Conversaciones'**
  String get conversationsTitle;

  /// No description provided for @noConversations.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes conversaciones. Escribe a un alumni desde su perfil o desde una publicación.'**
  String get noConversations;

  /// No description provided for @messageHint.
  ///
  /// In es, this message translates to:
  /// **'Escribe un mensaje…'**
  String get messageHint;

  /// No description provided for @messageSend.
  ///
  /// In es, this message translates to:
  /// **'Enviar mensaje'**
  String get messageSend;

  /// No description provided for @messageCategory.
  ///
  /// In es, this message translates to:
  /// **'Categoría'**
  String get messageCategory;

  /// No description provided for @newConversation.
  ///
  /// In es, this message translates to:
  /// **'Nueva conversación con {name}'**
  String newConversation(String name);

  /// No description provided for @messageSending.
  ///
  /// In es, this message translates to:
  /// **'Enviando…'**
  String get messageSending;

  /// No description provided for @messageSent.
  ///
  /// In es, this message translates to:
  /// **'Enviado'**
  String get messageSent;

  /// No description provided for @messageRead.
  ///
  /// In es, this message translates to:
  /// **'Leído'**
  String get messageRead;

  /// No description provided for @messageFailed.
  ///
  /// In es, this message translates to:
  /// **'No enviado. Toca para reintentar.'**
  String get messageFailed;

  /// No description provided for @back.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get back;

  /// No description provided for @catSolicitudInformacion.
  ///
  /// In es, this message translates to:
  /// **'Solicitud de información'**
  String get catSolicitudInformacion;

  /// No description provided for @catOportunidadLaboral.
  ///
  /// In es, this message translates to:
  /// **'Oportunidad laboral'**
  String get catOportunidadLaboral;

  /// No description provided for @catMentoria.
  ///
  /// In es, this message translates to:
  /// **'Mentoría'**
  String get catMentoria;

  /// No description provided for @catNetworking.
  ///
  /// In es, this message translates to:
  /// **'Networking'**
  String get catNetworking;

  /// No description provided for @catEvento.
  ///
  /// In es, this message translates to:
  /// **'Evento'**
  String get catEvento;

  /// No description provided for @catColaboracionEmpresarial.
  ///
  /// In es, this message translates to:
  /// **'Colaboración empresarial'**
  String get catColaboracionEmpresarial;

  /// No description provided for @orientadorTitle.
  ///
  /// In es, this message translates to:
  /// **'Orientador'**
  String get orientadorTitle;

  /// No description provided for @orientadorPhase.
  ///
  /// In es, this message translates to:
  /// **'Fase'**
  String get orientadorPhase;

  /// No description provided for @orientadorCountry.
  ///
  /// In es, this message translates to:
  /// **'País de interés'**
  String get orientadorCountry;

  /// No description provided for @orientadorSector.
  ///
  /// In es, this message translates to:
  /// **'Sector'**
  String get orientadorSector;

  /// No description provided for @orientadorHint.
  ///
  /// In es, this message translates to:
  /// **'Ej.: Termino la beca en Berlín y quiero preparar las entrevistas de Fase II…'**
  String get orientadorHint;

  /// No description provided for @orientadorSubmit.
  ///
  /// In es, this message translates to:
  /// **'Pedir orientación'**
  String get orientadorSubmit;

  /// No description provided for @orientadorLoading.
  ///
  /// In es, this message translates to:
  /// **'Buscando…'**
  String get orientadorLoading;

  /// No description provided for @orientadorSteps.
  ///
  /// In es, this message translates to:
  /// **'Pasos recomendados'**
  String get orientadorSteps;

  /// No description provided for @orientadorAlumni.
  ///
  /// In es, this message translates to:
  /// **'Alumni con quien hablar'**
  String get orientadorAlumni;

  /// No description provided for @orientadorRemaining.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Te queda 1 consulta hoy} other{Te quedan {count} consultas hoy}}'**
  String orientadorRemaining(int count);

  /// No description provided for @orientadorRateLimited.
  ///
  /// In es, this message translates to:
  /// **'Has alcanzado el límite de consultas de hoy. Vuelve mañana.'**
  String get orientadorRateLimited;

  /// No description provided for @profileTrajectory.
  ///
  /// In es, this message translates to:
  /// **'Trayectoria'**
  String get profileTrajectory;

  /// No description provided for @profileAbout.
  ///
  /// In es, this message translates to:
  /// **'Sobre mí'**
  String get profileAbout;

  /// No description provided for @profileEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar perfil'**
  String get profileEdit;

  /// No description provided for @profileSendMessage.
  ///
  /// In es, this message translates to:
  /// **'Enviar mensaje'**
  String get profileSendMessage;

  /// No description provided for @profilePosts.
  ///
  /// In es, this message translates to:
  /// **'Publicaciones'**
  String get profilePosts;

  /// No description provided for @profileCurrent.
  ///
  /// In es, this message translates to:
  /// **'Actualidad'**
  String get profileCurrent;

  /// No description provided for @profileBlock.
  ///
  /// In es, this message translates to:
  /// **'Bloquear'**
  String get profileBlock;

  /// No description provided for @profileUnblock.
  ///
  /// In es, this message translates to:
  /// **'Desbloquear'**
  String get profileUnblock;

  /// No description provided for @profileBlockConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Bloquear a {name}? No podrá ver tu contenido ni escribirte, y dejaréis de seguiros.'**
  String profileBlockConfirm(String name);

  /// No description provided for @profileNotAvailable.
  ///
  /// In es, this message translates to:
  /// **'Este perfil no está disponible.'**
  String get profileNotAvailable;

  /// No description provided for @fieldName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get fieldName;

  /// No description provided for @fieldRole.
  ///
  /// In es, this message translates to:
  /// **'Cargo'**
  String get fieldRole;

  /// No description provided for @fieldCompany.
  ///
  /// In es, this message translates to:
  /// **'Empresa'**
  String get fieldCompany;

  /// No description provided for @fieldPhase.
  ///
  /// In es, this message translates to:
  /// **'Fase'**
  String get fieldPhase;

  /// No description provided for @fieldCountry.
  ///
  /// In es, this message translates to:
  /// **'País'**
  String get fieldCountry;

  /// No description provided for @fieldCity.
  ///
  /// In es, this message translates to:
  /// **'Ciudad'**
  String get fieldCity;

  /// No description provided for @fieldSector.
  ///
  /// In es, this message translates to:
  /// **'Sector'**
  String get fieldSector;

  /// No description provided for @fieldBio.
  ///
  /// In es, this message translates to:
  /// **'Sobre mí'**
  String get fieldBio;

  /// No description provided for @fieldFrom.
  ///
  /// In es, this message translates to:
  /// **'Desde'**
  String get fieldFrom;

  /// No description provided for @fieldTo.
  ///
  /// In es, this message translates to:
  /// **'Hasta'**
  String get fieldTo;

  /// No description provided for @addExperience.
  ///
  /// In es, this message translates to:
  /// **'Añadir experiencia'**
  String get addExperience;

  /// No description provided for @changePhoto.
  ///
  /// In es, this message translates to:
  /// **'Cambiar foto'**
  String get changePhoto;

  /// No description provided for @save.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In es, this message translates to:
  /// **'Cambios guardados'**
  String get saved;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In es, this message translates to:
  /// **'Confirmar'**
  String get confirm;

  /// No description provided for @delete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get delete;

  /// No description provided for @requiredField.
  ///
  /// In es, this message translates to:
  /// **'Campo obligatorio'**
  String get requiredField;

  /// No description provided for @notificationsTitle.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get notificationsTitle;

  /// No description provided for @notificationsEmpty.
  ///
  /// In es, this message translates to:
  /// **'No tienes notificaciones.'**
  String get notificationsEmpty;

  /// No description provided for @markAllRead.
  ///
  /// In es, this message translates to:
  /// **'Marcar todo como leído'**
  String get markAllRead;

  /// No description provided for @notifFollow.
  ///
  /// In es, this message translates to:
  /// **'{name} empezó a seguirte'**
  String notifFollow(String name);

  /// No description provided for @notifFollowMany.
  ///
  /// In es, this message translates to:
  /// **'{name} y {others} más empezaron a seguirte'**
  String notifFollowMany(String name, int others);

  /// No description provided for @notifRecommendation.
  ///
  /// In es, this message translates to:
  /// **'{name} recomendó tu publicación'**
  String notifRecommendation(String name);

  /// No description provided for @notifRecommendationMany.
  ///
  /// In es, this message translates to:
  /// **'{name} y {others} más recomendaron tu publicación'**
  String notifRecommendationMany(String name, int others);

  /// No description provided for @notifComment.
  ///
  /// In es, this message translates to:
  /// **'{name} comentó tu publicación'**
  String notifComment(String name);

  /// No description provided for @notifCommentMany.
  ///
  /// In es, this message translates to:
  /// **'{name} y {others} más comentaron tu publicación'**
  String notifCommentMany(String name, int others);

  /// No description provided for @notifNews.
  ///
  /// In es, this message translates to:
  /// **'Novedad: {title}'**
  String notifNews(String title);

  /// No description provided for @notifGeneric.
  ///
  /// In es, this message translates to:
  /// **'Tienes novedades'**
  String get notifGeneric;

  /// No description provided for @settingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settingsTitle;

  /// No description provided for @settingsNotifications.
  ///
  /// In es, this message translates to:
  /// **'Preferencias de notificación'**
  String get settingsNotifications;

  /// No description provided for @settingsPrivacy.
  ///
  /// In es, this message translates to:
  /// **'Privacidad'**
  String get settingsPrivacy;

  /// No description provided for @settingsExport.
  ///
  /// In es, this message translates to:
  /// **'Exportar mis datos'**
  String get settingsExport;

  /// No description provided for @settingsExportDone.
  ///
  /// In es, this message translates to:
  /// **'Tus datos están listos para compartir o guardar.'**
  String get settingsExportDone;

  /// No description provided for @settingsDelete.
  ///
  /// In es, this message translates to:
  /// **'Borrar mi cuenta'**
  String get settingsDelete;

  /// No description provided for @settingsDeleteBody.
  ///
  /// In es, this message translates to:
  /// **'Se borrarán tu perfil, publicaciones, comentarios, mensajes enviados, imágenes y preferencias. No se puede deshacer. Escribe BORRAR MI CUENTA para confirmar.'**
  String get settingsDeleteBody;

  /// No description provided for @settingsDeleteConfirmWord.
  ///
  /// In es, this message translates to:
  /// **'BORRAR MI CUENTA'**
  String get settingsDeleteConfirmWord;

  /// No description provided for @settingsSignOut.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get settingsSignOut;

  /// No description provided for @settingsBlocked.
  ///
  /// In es, this message translates to:
  /// **'Personas bloqueadas'**
  String get settingsBlocked;

  /// No description provided for @settingsVersion.
  ///
  /// In es, this message translates to:
  /// **'Versión {version}'**
  String settingsVersion(String version);

  /// No description provided for @prefPushMessages.
  ///
  /// In es, this message translates to:
  /// **'Mensajes'**
  String get prefPushMessages;

  /// No description provided for @prefPushSocial.
  ///
  /// In es, this message translates to:
  /// **'Seguidores, recomendaciones y comentarios'**
  String get prefPushSocial;

  /// No description provided for @prefPushEvents.
  ///
  /// In es, this message translates to:
  /// **'Eventos de mis clubs'**
  String get prefPushEvents;

  /// No description provided for @prefPushNews.
  ///
  /// In es, this message translates to:
  /// **'Novedades de la asociación'**
  String get prefPushNews;

  /// No description provided for @prefEmailConsent.
  ///
  /// In es, this message translates to:
  /// **'Acepto recibir comunicaciones por email de ICEX Alumni'**
  String get prefEmailConsent;

  /// No description provided for @prefEmailNews.
  ///
  /// In es, this message translates to:
  /// **'Novedades por email'**
  String get prefEmailNews;

  /// No description provided for @prefEmailDigest.
  ///
  /// In es, this message translates to:
  /// **'Resumen semanal por email'**
  String get prefEmailDigest;

  /// No description provided for @prefPushSection.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones push'**
  String get prefPushSection;

  /// No description provided for @prefEmailSection.
  ///
  /// In es, this message translates to:
  /// **'Email'**
  String get prefEmailSection;

  /// No description provided for @privacyIntro.
  ///
  /// In es, this message translates to:
  /// **'Elige quién ve cada dato de tu perfil.'**
  String get privacyIntro;

  /// No description provided for @privacyEveryone.
  ///
  /// In es, this message translates to:
  /// **'Todos los socios'**
  String get privacyEveryone;

  /// No description provided for @privacyFollowers.
  ///
  /// In es, this message translates to:
  /// **'Solo mis seguidores'**
  String get privacyFollowers;

  /// No description provided for @privacyOnlyMe.
  ///
  /// In es, this message translates to:
  /// **'Solo yo'**
  String get privacyOnlyMe;

  /// No description provided for @privacyLocation.
  ///
  /// In es, this message translates to:
  /// **'Ubicación en el mapa'**
  String get privacyLocation;

  /// No description provided for @privacySuggestions.
  ///
  /// In es, this message translates to:
  /// **'Aparecer en sugerencias y en el Orientador'**
  String get privacySuggestions;

  /// No description provided for @errorGeneric.
  ///
  /// In es, this message translates to:
  /// **'Algo ha fallado. Inténtalo de nuevo.'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión. Mostramos lo último guardado.'**
  String get errorNetwork;

  /// No description provided for @errorForbidden.
  ///
  /// In es, this message translates to:
  /// **'No tienes permiso para hacer esto.'**
  String get errorForbidden;

  /// No description provided for @errorNotFound.
  ///
  /// In es, this message translates to:
  /// **'No encontrado.'**
  String get errorNotFound;

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In es, this message translates to:
  /// **'Cargando…'**
  String get loading;

  /// No description provided for @emptyFeed.
  ///
  /// In es, this message translates to:
  /// **'Sigue a otros alumni para ver aquí sus publicaciones.'**
  String get emptyFeed;

  /// No description provided for @timeNow.
  ///
  /// In es, this message translates to:
  /// **'ahora'**
  String get timeNow;

  /// No description provided for @timeMinutes.
  ///
  /// In es, this message translates to:
  /// **'hace {n} min'**
  String timeMinutes(int n);

  /// No description provided for @timeHours.
  ///
  /// In es, this message translates to:
  /// **'hace {n} h'**
  String timeHours(int n);

  /// No description provided for @timeYesterday.
  ///
  /// In es, this message translates to:
  /// **'ayer'**
  String get timeYesterday;

  /// No description provided for @timeDays.
  ///
  /// In es, this message translates to:
  /// **'hace {n} días'**
  String timeDays(int n);

  /// No description provided for @reportTitle.
  ///
  /// In es, this message translates to:
  /// **'Denunciar contenido'**
  String get reportTitle;

  /// No description provided for @reportSpam.
  ///
  /// In es, this message translates to:
  /// **'Spam'**
  String get reportSpam;

  /// No description provided for @reportHarassment.
  ///
  /// In es, this message translates to:
  /// **'Acoso'**
  String get reportHarassment;

  /// No description provided for @reportInappropriate.
  ///
  /// In es, this message translates to:
  /// **'Contenido inapropiado'**
  String get reportInappropriate;

  /// No description provided for @reportPersonalData.
  ///
  /// In es, this message translates to:
  /// **'Datos personales'**
  String get reportPersonalData;

  /// No description provided for @reportImpersonation.
  ///
  /// In es, this message translates to:
  /// **'Suplantación'**
  String get reportImpersonation;

  /// No description provided for @reportOther.
  ///
  /// In es, this message translates to:
  /// **'Otro motivo'**
  String get reportOther;

  /// No description provided for @reportThanks.
  ///
  /// In es, this message translates to:
  /// **'Gracias. El equipo de moderación lo revisará.'**
  String get reportThanks;

  /// No description provided for @close.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get close;

  /// No description provided for @moreOptions.
  ///
  /// In es, this message translates to:
  /// **'Más opciones'**
  String get moreOptions;

  /// No description provided for @copyText.
  ///
  /// In es, this message translates to:
  /// **'Copiar texto'**
  String get copyText;

  /// No description provided for @copied.
  ///
  /// In es, this message translates to:
  /// **'Copiado'**
  String get copied;

  /// No description provided for @viewProfileOf.
  ///
  /// In es, this message translates to:
  /// **'Ver el perfil de {name}'**
  String viewProfileOf(String name);

  /// No description provided for @deletePostBody.
  ///
  /// In es, this message translates to:
  /// **'La publicación desaparecerá de tu perfil y del feed. No se puede deshacer.'**
  String get deletePostBody;

  /// No description provided for @shareInNetworkHint.
  ///
  /// In es, this message translates to:
  /// **'Añade tu opinión (opcional)'**
  String get shareInNetworkHint;

  /// No description provided for @sharedDone.
  ///
  /// In es, this message translates to:
  /// **'Compartido en tu red'**
  String get sharedDone;

  /// No description provided for @shareDefaultText.
  ///
  /// In es, this message translates to:
  /// **'Comparto esta publicación'**
  String get shareDefaultText;

  /// No description provided for @composeTitle.
  ///
  /// In es, this message translates to:
  /// **'Crear publicación'**
  String get composeTitle;

  /// No description provided for @composeHint.
  ///
  /// In es, this message translates to:
  /// **'¿Qué quieres compartir con la comunidad ICEX Alumni?'**
  String get composeHint;

  /// No description provided for @composeDiscardTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Descartar la publicación?'**
  String get composeDiscardTitle;

  /// No description provided for @composeDiscardBody.
  ///
  /// In es, this message translates to:
  /// **'Perderás lo que has escrito.'**
  String get composeDiscardBody;

  /// No description provided for @keepEditing.
  ///
  /// In es, this message translates to:
  /// **'Seguir editando'**
  String get keepEditing;

  /// No description provided for @discard.
  ///
  /// In es, this message translates to:
  /// **'Descartar'**
  String get discard;

  /// No description provided for @removePhoto.
  ///
  /// In es, this message translates to:
  /// **'Quitar foto'**
  String get removePhoto;

  /// No description provided for @composerEvent.
  ///
  /// In es, this message translates to:
  /// **'Evento'**
  String get composerEvent;

  /// No description provided for @composerPublished.
  ///
  /// In es, this message translates to:
  /// **'Publicado'**
  String get composerPublished;

  /// No description provided for @exploreNetwork.
  ///
  /// In es, this message translates to:
  /// **'Explorar la red'**
  String get exploreNetwork;

  /// No description provided for @seeAll.
  ///
  /// In es, this message translates to:
  /// **'Ver todo'**
  String get seeAll;

  /// No description provided for @dismiss.
  ///
  /// In es, this message translates to:
  /// **'Descartar'**
  String get dismiss;

  /// No description provided for @postTitle.
  ///
  /// In es, this message translates to:
  /// **'Publicación'**
  String get postTitle;

  /// No description provided for @profileNoPosts.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay publicaciones.'**
  String get profileNoPosts;

  /// No description provided for @followsYou.
  ///
  /// In es, this message translates to:
  /// **'Te sigue'**
  String get followsYou;

  /// No description provided for @postsLabel.
  ///
  /// In es, this message translates to:
  /// **'publicaciones'**
  String get postsLabel;

  /// No description provided for @profileBlocked.
  ///
  /// In es, this message translates to:
  /// **'Has bloqueado a {name}'**
  String profileBlocked(String name);

  /// No description provided for @today.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In es, this message translates to:
  /// **'Ayer'**
  String get yesterday;

  /// No description provided for @messageFailedTapRetry.
  ///
  /// In es, this message translates to:
  /// **'No enviado · toca para reintentar'**
  String get messageFailedTapRetry;

  /// No description provided for @noConversationsFilter.
  ///
  /// In es, this message translates to:
  /// **'No hay conversaciones en esta categoría.'**
  String get noConversationsFilter;

  /// No description provided for @clearSearch.
  ///
  /// In es, this message translates to:
  /// **'Borrar búsqueda'**
  String get clearSearch;

  /// No description provided for @filters.
  ///
  /// In es, this message translates to:
  /// **'Filtros'**
  String get filters;

  /// No description provided for @directoryGroups.
  ///
  /// In es, this message translates to:
  /// **'Grupos de alumni'**
  String get directoryGroups;

  /// No description provided for @clearFilters.
  ///
  /// In es, this message translates to:
  /// **'Quitar filtros'**
  String get clearFilters;

  /// No description provided for @showResults.
  ///
  /// In es, this message translates to:
  /// **'Ver resultados'**
  String get showResults;

  /// No description provided for @notificationsNew.
  ///
  /// In es, this message translates to:
  /// **'Nuevas'**
  String get notificationsNew;

  /// No description provided for @notificationsEarlier.
  ///
  /// In es, this message translates to:
  /// **'Anteriores'**
  String get notificationsEarlier;

  /// No description provided for @change.
  ///
  /// In es, this message translates to:
  /// **'Cambiar'**
  String get change;

  /// No description provided for @unsavedChangesTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Descartar los cambios?'**
  String get unsavedChangesTitle;

  /// No description provided for @unsavedChangesBody.
  ///
  /// In es, this message translates to:
  /// **'Tienes cambios sin guardar en tu perfil.'**
  String get unsavedChangesBody;

  /// No description provided for @loginFeatureWorld.
  ///
  /// In es, this message translates to:
  /// **'Encuentra alumni en cualquier país'**
  String get loginFeatureWorld;

  /// No description provided for @loginFeaturePromo.
  ///
  /// In es, this message translates to:
  /// **'Conecta con tu promoción y tu club'**
  String get loginFeaturePromo;

  /// No description provided for @loginFeatureOpportunities.
  ///
  /// In es, this message translates to:
  /// **'Descubre ofertas, mentorías y eventos'**
  String get loginFeatureOpportunities;

  /// No description provided for @loginNotMember.
  ///
  /// In es, this message translates to:
  /// **'¿Aún no eres socio?'**
  String get loginNotMember;

  /// No description provided for @loginJoin.
  ///
  /// In es, this message translates to:
  /// **'Hazte socio'**
  String get loginJoin;

  /// No description provided for @accessDeniedOtherAccount.
  ///
  /// In es, this message translates to:
  /// **'Entrar con otra cuenta'**
  String get accessDeniedOtherAccount;

  /// No description provided for @linkOpenError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir {url}'**
  String linkOpenError(String url);

  /// No description provided for @devLoginTitle.
  ///
  /// In es, this message translates to:
  /// **'Modo desarrollo'**
  String get devLoginTitle;

  /// No description provided for @devLoginHint.
  ///
  /// In es, this message translates to:
  /// **'Entra directamente como una cuenta de prueba, sin navegador. No aparece en producción.'**
  String get devLoginHint;

  /// No description provided for @readMore.
  ///
  /// In es, this message translates to:
  /// **'Leer más'**
  String get readMore;

  /// No description provided for @showLess.
  ///
  /// In es, this message translates to:
  /// **'Mostrar menos'**
  String get showLess;

  /// No description provided for @homeGreeting.
  ///
  /// In es, this message translates to:
  /// **'Hola, {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Lo último de tu red ICEX Alumni'**
  String get homeSubtitle;

  /// No description provided for @orientadorIntro.
  ///
  /// In es, this message translates to:
  /// **'Cuéntanos qué necesitas. Te proponemos pasos concretos y alumni con quienes hablar.'**
  String get orientadorIntro;

  /// No description provided for @orientadorQuestion.
  ///
  /// In es, this message translates to:
  /// **'¿En qué te podemos orientar?'**
  String get orientadorQuestion;

  /// No description provided for @orientadorContext.
  ///
  /// In es, this message translates to:
  /// **'Tu situación'**
  String get orientadorContext;

  /// No description provided for @newsEmpty.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay comunicados de la asociación.'**
  String get newsEmpty;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
