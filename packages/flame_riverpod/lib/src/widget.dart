import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A [GameWidget] that provides access to [Component]s using
/// [RiverpodComponentMixin] attached to [FlameGame]s using [RiverpodGameMixin]
/// access to Riverpod [Provider]s.
///
/// The corresponding [State] object ([RiverpodAwareGameWidgetState]) assumes
/// responsibilities associated with [ConsumerStatefulElement] in
/// `flutter_riverpod`.
class RiverpodAwareGameWidget<T extends Game> extends GameWidget<T> {
  RiverpodAwareGameWidget({
    required super.game,
    required this.key,
    super.textDirection,
    super.loadingBuilder,
    super.errorBuilder,
    super.backgroundBuilder,
    super.overlayBuilderMap,
    super.initialActiveOverlays,
    super.focusNode,
    super.autofocus,
    super.mouseCursor,
    super.addRepaintBoundary,
  }) : super(key: key);

  @override
  final GlobalKey<RiverpodAwareGameWidgetState<T>> key;

  @override
  GameWidgetState<T> createState() => RiverpodAwareGameWidgetState<T>();
}

class RiverpodAwareGameWidgetState<T extends Game> extends GameWidgetState<T>
    implements WidgetRef {
  RiverpodGameMixin get game => widget.game! as RiverpodGameMixin;

  late ProviderContainer _container = ProviderScope.containerOf(context);
  var _dependencies =
      <ProviderListenable<Object?>, ProviderSubscription<Object?>>{};
  Map<ProviderListenable<Object?>, ProviderSubscription<Object?>>?
      _oldDependencies;
  final _listeners = <ProviderSubscription<Object?>>[];
  List<_ListenManual<Object?>>? _manualListeners;

  /// Rebuilds the [RiverpodAwareGameWidget] by calling [setState].
  void forceBuild() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    game.key = (widget as RiverpodAwareGameWidget<T>).key;
  }

  @override
  void didUpdateWidget(covariant GameWidget<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    game.key = (widget as RiverpodAwareGameWidget<T>).key;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newContainer = ProviderScope.containerOf(context);
    if (_container != newContainer) {
      _container = newContainer;
      for (final dependency in _dependencies.values) {
        dependency.close();
      }
      _dependencies.clear();
    }
  }

  @override
  void dispose() {
    // Below comments are from the implementation of ConsumerStatefulWidget:

    // Calling `super.unmount()` will call `dispose` on the state
    // And [ListenManual] subscriptions should be closed after `dispose`
    super.dispose();

    for (final dependency in _dependencies.values) {
      dependency.close();
    }
    for (var i = 0; i < _listeners.length; i++) {
      _listeners[i].close();
    }
    final manualListeners = _manualListeners?.toList();
    if (manualListeners != null) {
      for (final listener in manualListeners) {
        listener.close();
      }
      _manualListeners = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      _oldDependencies = _dependencies;
      for (var i = 0; i < _listeners.length; i++) {
        _listeners[i].close();
      }
      _listeners.clear();
      _dependencies = {};
      game.onBuild();
      return super.build(context);
    } finally {
      for (final dep in _oldDependencies!.values) {
        dep.close();
      }
      _oldDependencies = null;
    }
  }

  void _assertNotDisposed() {
    if (!context.mounted) {
      throw StateError('Cannot use "ref" after the widget was disposed.');
    }
  }

  @override
  Res watch<Res>(ProviderListenable<Res> target) {
    _assertNotDisposed();
    return _dependencies.putIfAbsent(target, () {
      final oldDependency = _oldDependencies?.remove(target);

      if (oldDependency != null) {
        return oldDependency;
      }

      return _container.listen<Res>(
        target,
        (_, __) => setState(() {}),
      );
    }).read() as Res;
  }

  @override
  void listen<U>(
    ProviderListenable<U> provider,
    void Function(U? previous, U value) listener, {
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    _assertNotDisposed();
    assert(
      context.debugDoingBuild,
      'ref.listen can only be used within the build method of a ConsumerWidget',
    );

    // We can't implement a fireImmediately flag because we wouldn't know
    // which listen call was preserved between widget rebuild, and we wouldn't
    // want to call the listener on every rebuild.
    final sub = _container.listen<U>(provider, listener, onError: onError);
    _listeners.add(sub);
  }

  @override
  bool exists(ProviderBase<Object?> provider) {
    _assertNotDisposed();
    return ProviderScope.containerOf(context, listen: false).exists(provider);
  }

  @override
  Res read<Res>(ProviderListenable<Res> provider) {
    _assertNotDisposed();
    return ProviderScope.containerOf(context, listen: false).read(provider);
  }

  @override
  State refresh<State>(Refreshable<State> provider) {
    _assertNotDisposed();
    return ProviderScope.containerOf(context, listen: false).refresh(provider);
  }

  @override
  void invalidate(ProviderOrFamily provider) {
    _assertNotDisposed();
    _container.invalidate(provider);
  }

  @override
  ProviderSubscription<Res> listenManual<Res>(
    ProviderListenable<Res> provider,
    void Function(Res? previous, Res next) listener, {
    void Function(Object error, StackTrace stackTrace)? onError,
    bool fireImmediately = false,
  }) {
    _assertNotDisposed();
    final listeners = _manualListeners ??= [];

    final sub = _ListenManual(
      ProviderScope.containerOf(context, listen: false).listen(
        provider,
        listener,
        onError: onError,
        fireImmediately: fireImmediately,
      ),
      this,
    );
    listeners.add(sub);

    return sub;
  }
}

class _ListenManual<T> implements ProviderSubscription<T> {
  _ListenManual(this._subscription, this._element);

  final ProviderSubscription<T> _subscription;
  final RiverpodAwareGameWidgetState _element;

  @override
  void close() {
    _subscription.close();
    _element._manualListeners?.remove(this);
  }

  @override
  T read() => _subscription.read();
}
