import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/features/feed/domain/post.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'post_interactions.g.dart';

/// Cambios locales sobre publicaciones (recomendar, comentar, borrar) que deben verse igual
/// en todas las pantallas donde aparece la misma publicación: Inicio, perfil y detalle.
///
/// Antes cada lista tenía su copia y solo el feed se actualizaba: recomendar desde el perfil
/// o desde el detalle no cambiaba nada en pantalla, y una publicación borrada seguía en el
/// perfil. Ahora las tarjetas leen la versión más reciente de aquí.
class PostOverridesState {
  const PostOverridesState({this.updated = const {}, this.deleted = const {}});

  final Map<String, Post> updated;
  final Set<String> deleted;

  /// La versión más reciente conocida de [p], o `null` si se ha borrado.
  Post? resolve(Post p) => deleted.contains(p.id) ? null : (updated[p.id] ?? p);
}

@Riverpod(keepAlive: true)
class PostOverrides extends _$PostOverrides {
  final _inFlight = <String>{};

  @override
  PostOverridesState build() {
    // Al cambiar de usuario no se arrastra nada de la sesión anterior.
    ref.watch(sessionUserIdProvider);
    return const PostOverridesState();
  }

  /// Al recargar listas desde el servidor, sus datos ya son los buenos.
  void clear() => state = PostOverridesState(deleted: state.deleted);

  void _put(Post p) =>
      state = PostOverridesState(updated: {...state.updated, p.id: p}, deleted: state.deleted);

  /// Recomendar / quitar recomendación, optimista. Ignora toques repetidos mientras hay una
  /// petición en curso para la misma publicación (evita respuestas desordenadas).
  Future<void> toggleRecommend(Post post) async {
    final current = state.updated[post.id] ?? post;
    if (!_inFlight.add(post.id)) return;
    final optimistic = current.toggleRecommendation();
    _put(optimistic);
    try {
      final r = await ref
          .read(feedRepositoryProvider)
          .setRecommended(post.id, value: optimistic.recomendado);
      if (!ref.mounted) return;
      _put(optimistic.copyWith(recomendado: r.recomendado, recomendacionesCount: r.count));
    } on Object {
      if (ref.mounted) _put(current);
      rethrow;
    } finally {
      _inFlight.remove(post.id);
    }
  }

  void commentAdded(Post post) {
    final current = state.updated[post.id] ?? post;
    _put(current.copyWith(comentariosCount: current.comentariosCount + 1));
  }

  Future<void> delete(Post post) async {
    await ref.read(feedRepositoryProvider).delete(post.id);
    if (!ref.mounted) return;
    state = PostOverridesState(updated: state.updated, deleted: {...state.deleted, post.id});
  }
}
