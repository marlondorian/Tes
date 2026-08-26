import 'dart:async';
import 'dart:io';

import 'package:audio_service_platform_interface/audio_service_platform_interface.dart';
import 'package:dbus/dbus.dart';

class CustomMprisMetadata {
  final String title;
  final String? trackId;
  final Duration? length;
  final List<String>? artist;
  final String? artUrl;
  final String? album;
  final List<String>? genre;

  CustomMprisMetadata({
    required this.title,
    this.trackId,
    this.length,
    this.artist,
    this.artUrl,
    this.album,
    this.genre,
  });

  // mpris:trackid debe ser una DBusObjectPath válida
  String get _safeTrackId {
    final id = trackId ?? 'notrack';
    // Convertir el id a una ruta de objeto D-Bus válida (solo alfanumérico y _)
    final sanitized = id.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return '/org/mpris/MediaPlayer2/track/$sanitized';
  }

  DBusValue toValue() {
    final result = DBusDict.stringVariant({
      // mpris:trackid es requerido por MPRIS 2 para que SetPosition funcione
      "mpris:trackid": DBusObjectPath(_safeTrackId),
      "xesam:title": DBusString(title),
      if (length != null) "mpris:length": DBusInt64(length!.inMicroseconds),
      if (artist != null) "xesam:artist": DBusArray.string(artist!),
      if (artUrl != null) "mpris:artUrl": DBusString(artUrl!),
      if (album != null) "xesam:album": DBusString(album!),
      if (genre != null) "xesam:genre": DBusArray.string(genre!),
    });
    return result;
  }
}

class OrgMprisMediaPlayer2Tes extends DBusObject {
  final String identity;
  final _stateStreamController = StreamController<String>.broadcast();
  Stream<String> get controlStream => _stateStreamController.stream;

  final _positionStreamController = StreamController<Duration>.broadcast();
  Stream<Duration> get positionStream => _positionStreamController.stream;

  final _openUriStreamController = StreamController<Uri>.broadcast();
  Stream<Uri> get openUriStream => _openUriStreamController.stream;

  final _volumeStreamController = StreamController<double>.broadcast();
  Stream<double> get volumeStream => _volumeStreamController.stream;

  Duration position = Duration.zero;
  String _playbackState = 'Stopped';

  OrgMprisMediaPlayer2Tes({
    DBusObjectPath path = const DBusObjectPath.unchecked(
      '/org/mpris/MediaPlayer2',
    ),
    required this.identity,
  }) : super(path);

  DBusBoolean getCanQuit() => const DBusBoolean(false);
  DBusBoolean getFullscreen() => const DBusBoolean(false);
  Future<DBusMethodResponse> setFullscreen(bool value) async =>
      DBusMethodSuccessResponse([const DBusBoolean(false)]);
  DBusBoolean getCanSetFullscreen() => const DBusBoolean(false);

  // CanRaise = true le indica a Linux (GNOME/KDE) que al dar clic en el widget debe invocar Raise()
  DBusBoolean getCanRaise() => const DBusBoolean(true);
  DBusBoolean getHasTrackList() => const DBusBoolean(false);
  DBusString getIdentity() => DBusString(identity);
  DBusString getDesktopEntry() => const DBusString('macos_native_widgets');
  DBusArray getSupportedUriSchemes() => DBusArray.string([]);
  DBusArray getSupportedMimeTypes() => DBusArray.string([]);

  // Al invocarse Raise() desde D-Bus, emitimos 'raise' al controlStream
  Future<DBusMethodResponse> doRaise() async {
    _stateStreamController.add('raise');
    return DBusMethodSuccessResponse([]);
  }

  Future<DBusMethodResponse> doQuit() async => DBusMethodSuccessResponse([]);

  String get playbackState => _playbackState;
  set playbackState(String state) {
    if (state == _playbackState) return;
    emitPropertiesChanged(
      "org.mpris.MediaPlayer2.Player",
      changedProperties: {"PlaybackStatus": DBusString(state)},
    );
    _playbackState = state;
  }

  DBusString _getPlaybackStatus() => DBusString(_playbackState);
  DBusString getLoopStatus() => const DBusString('None');
  Future<DBusMethodResponse> setLoopStatus(String value) async =>
      DBusMethodSuccessResponse([]);
  DBusDouble getRate() => const DBusDouble(1.0);
  Future<DBusMethodResponse> setRate(double value) async =>
      DBusMethodSuccessResponse([]);

  CustomMprisMetadata _metadata = CustomMprisMetadata(title: "No title");
  CustomMprisMetadata get metadata => _metadata;
  set metadata(CustomMprisMetadata meta) {
    emitPropertiesChanged(
      "org.mpris.MediaPlayer2.Player",
      changedProperties: {"Metadata": meta.toValue()},
    );
    _metadata = meta;
  }

  DBusValue getMetadata() => _metadata.toValue();
  DBusDouble getVolume() => const DBusDouble(1.0);
  Future<DBusMethodResponse> setVolume(double value) async {
    _volumeStreamController.add(value);
    return DBusMethodSuccessResponse([]);
  }

  DBusInt64 getPosition() => DBusInt64(position.inMicroseconds);
  DBusDouble getMinimumRate() => const DBusDouble(1.0);
  DBusDouble getMaximumRate() => const DBusDouble(1.0);
  DBusBoolean getCanGoNext() => const DBusBoolean(true);
  DBusBoolean getCanGoPrevious() => const DBusBoolean(true);
  DBusBoolean getCanPlay() => const DBusBoolean(true);
  DBusBoolean getCanPause() => const DBusBoolean(true);
  DBusBoolean getCanSeek() => const DBusBoolean(true);
  DBusBoolean getCanControl() => const DBusBoolean(true);

  Future<DBusMethodResponse> doNext() async {
    _stateStreamController.add('next');
    return DBusMethodSuccessResponse([]);
  }

  Future<DBusMethodResponse> doPrevious() async {
    _stateStreamController.add('previous');
    return DBusMethodSuccessResponse([]);
  }

  Future<DBusMethodResponse> doPause() async {
    _stateStreamController.add('pause');
    return DBusMethodSuccessResponse([]);
  }

  Future<DBusMethodResponse> doPlayPause() async {
    _stateStreamController.add('playPause');
    return DBusMethodSuccessResponse([]);
  }

  Future<DBusMethodResponse> doStop() async {
    _stateStreamController.add('stop');
    return DBusMethodSuccessResponse([]);
  }

  Future<DBusMethodResponse> doPlay() async {
    _stateStreamController.add('play');
    return DBusMethodSuccessResponse([]);
  }

  // Manejo de Seek y SetPosition
  Future<DBusMethodResponse> doSeek(int offset) async {
    final newPos = position + Duration(microseconds: offset);
    position = newPos;
    _positionStreamController.add(newPos);
    await emitSeeked(newPos);
    return DBusMethodSuccessResponse([]);
  }

  Future<DBusMethodResponse> doSetPosition(String trackId, int pos) async {
    final newPos = Duration(microseconds: pos);
    position = newPos;
    _positionStreamController.add(newPos);
    await emitSeeked(newPos);
    return DBusMethodSuccessResponse([]);
  }

  Future<DBusMethodResponse> doOpenUri(String uri) async {
    _openUriStreamController.add(Uri.parse(uri));
    return DBusMethodSuccessResponse([]);
  }

  Future<void> emitSeeked(Duration pos) async {
    await emitSignal('org.mpris.MediaPlayer2.Player', 'Seeked', [
      DBusInt64(pos.inMicroseconds),
    ]);
  }

  @override
  List<DBusIntrospectInterface> introspect() {
    return [
      DBusIntrospectInterface(
        'org.mpris.MediaPlayer2',
        methods: [DBusIntrospectMethod('Raise'), DBusIntrospectMethod('Quit')],
        properties: [
          DBusIntrospectProperty(
            'CanQuit',
            DBusSignature('b'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'CanRaise',
            DBusSignature('b'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'HasTrackList',
            DBusSignature('b'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'Identity',
            DBusSignature('s'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'DesktopEntry',
            DBusSignature('s'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'SupportedUriSchemes',
            DBusSignature('as'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'SupportedMimeTypes',
            DBusSignature('as'),
            access: DBusPropertyAccess.read,
          ),
        ],
      ),
      DBusIntrospectInterface(
        'org.mpris.MediaPlayer2.Player',
        methods: [
          DBusIntrospectMethod('Next'),
          DBusIntrospectMethod('Previous'),
          DBusIntrospectMethod('Pause'),
          DBusIntrospectMethod('PlayPause'),
          DBusIntrospectMethod('Stop'),
          DBusIntrospectMethod('Play'),
          DBusIntrospectMethod(
            'Seek',
            args: [
              DBusIntrospectArgument(
                DBusSignature('x'),
                DBusArgumentDirection.in_,
                name: 'Offset',
              ),
            ],
          ),
          DBusIntrospectMethod(
            'SetPosition',
            args: [
              DBusIntrospectArgument(
                DBusSignature('o'),
                DBusArgumentDirection.in_,
                name: 'TrackId',
              ),
              DBusIntrospectArgument(
                DBusSignature('x'),
                DBusArgumentDirection.in_,
                name: 'Position',
              ),
            ],
          ),
          DBusIntrospectMethod(
            'OpenUri',
            args: [
              DBusIntrospectArgument(
                DBusSignature('s'),
                DBusArgumentDirection.in_,
                name: 'Uri',
              ),
            ],
          ),
        ],
        signals: [
          DBusIntrospectSignal(
            'Seeked',
            args: [
              DBusIntrospectArgument(
                DBusSignature('x'),
                DBusArgumentDirection.out,
                name: 'Position',
              ),
            ],
          ),
        ],
        properties: [
          DBusIntrospectProperty(
            'PlaybackStatus',
            DBusSignature('s'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'LoopStatus',
            DBusSignature('s'),
            access: DBusPropertyAccess.readwrite,
          ),
          DBusIntrospectProperty(
            'Rate',
            DBusSignature('d'),
            access: DBusPropertyAccess.readwrite,
          ),
          DBusIntrospectProperty(
            'Metadata',
            DBusSignature('a{sv}'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'Volume',
            DBusSignature('d'),
            access: DBusPropertyAccess.readwrite,
          ),
          DBusIntrospectProperty(
            'Position',
            DBusSignature('x'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'MinimumRate',
            DBusSignature('d'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'MaximumRate',
            DBusSignature('d'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'CanGoNext',
            DBusSignature('b'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'CanGoPrevious',
            DBusSignature('b'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'CanPlay',
            DBusSignature('b'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'CanPause',
            DBusSignature('b'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'CanSeek',
            DBusSignature('b'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'CanControl',
            DBusSignature('b'),
            access: DBusPropertyAccess.read,
          ),
        ],
      ),
    ];
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface == 'org.mpris.MediaPlayer2') {
      if (methodCall.name == 'Raise') {
        return doRaise();
      } else if (methodCall.name == 'Quit') {
        return doQuit();
      } else {
        return DBusMethodErrorResponse.unknownMethod();
      }
    } else if (methodCall.interface == 'org.mpris.MediaPlayer2.Player') {
      if (methodCall.name == 'Next') return doNext();
      if (methodCall.name == 'Previous') return doPrevious();
      if (methodCall.name == 'Pause') return doPause();
      if (methodCall.name == 'PlayPause') return doPlayPause();
      if (methodCall.name == 'Stop') return doStop();
      if (methodCall.name == 'Play') return doPlay();
      if (methodCall.name == 'Seek') {
        return doSeek(methodCall.values[0].asInt64());
      }
      if (methodCall.name == 'SetPosition') {
        return doSetPosition(
          methodCall.values[0].asObjectPath().toString(),
          methodCall.values[1].asInt64(),
        );
      }
      if (methodCall.name == 'OpenUri') {
        return doOpenUri(methodCall.values[0].asString());
      }
      return DBusMethodErrorResponse.unknownMethod();
    }
    return DBusMethodErrorResponse.unknownInterface();
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    if (interface == 'org.mpris.MediaPlayer2') {
      DBusValue? value;
      if (name == 'CanQuit') value = getCanQuit();
      if (name == 'CanRaise') value = getCanRaise();
      if (name == 'HasTrackList') value = getHasTrackList();
      if (name == 'Identity') value = getIdentity();
      if (name == 'DesktopEntry') value = getDesktopEntry();
      if (name == 'SupportedUriSchemes') value = getSupportedUriSchemes();
      if (name == 'SupportedMimeTypes') value = getSupportedMimeTypes();
      if (value != null) return DBusMethodSuccessResponse([DBusVariant(value)]);
      return DBusMethodErrorResponse.unknownProperty();
    } else if (interface == 'org.mpris.MediaPlayer2.Player') {
      DBusValue? value;
      if (name == 'PlaybackStatus') value = _getPlaybackStatus();
      if (name == 'LoopStatus') value = getLoopStatus();
      if (name == 'Rate') value = getRate();
      if (name == 'Metadata') value = getMetadata();
      if (name == 'Volume') value = getVolume();
      if (name == 'Position') value = getPosition();
      if (name == 'MinimumRate') value = getMinimumRate();
      if (name == 'MaximumRate') value = getMaximumRate();
      if (name == 'CanGoNext') value = getCanGoNext();
      if (name == 'CanGoPrevious') value = getCanGoPrevious();
      if (name == 'CanPlay') value = getCanPlay();
      if (name == 'CanPause') value = getCanPause();
      if (name == 'CanSeek') value = getCanSeek();
      if (name == 'CanControl') value = getCanControl();
      if (value != null) return DBusMethodSuccessResponse([DBusVariant(value)]);
      return DBusMethodErrorResponse.unknownProperty();
    }
    return DBusMethodErrorResponse.unknownProperty();
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    var properties = <String, DBusValue>{};
    if (interface == 'org.mpris.MediaPlayer2') {
      properties = {
        'CanQuit': getCanQuit(),
        'CanRaise': getCanRaise(),
        'HasTrackList': getHasTrackList(),
        'Identity': getIdentity(),
        'DesktopEntry': getDesktopEntry(),
        'SupportedUriSchemes': getSupportedUriSchemes(),
        'SupportedMimeTypes': getSupportedMimeTypes(),
      };
    } else if (interface == 'org.mpris.MediaPlayer2.Player') {
      properties = {
        'PlaybackStatus': _getPlaybackStatus(),
        'LoopStatus': getLoopStatus(),
        'Rate': getRate(),
        'Metadata': getMetadata(),
        'Volume': getVolume(),
        'Position': getPosition(),
        'MinimumRate': getMinimumRate(),
        'MaximumRate': getMaximumRate(),
        'CanGoNext': getCanGoNext(),
        'CanGoPrevious': getCanGoPrevious(),
        'CanPlay': getCanPlay(),
        'CanPause': getCanPause(),
        'CanSeek': getCanSeek(),
        'CanControl': getCanControl(),
      };
    }
    return DBusMethodSuccessResponse([DBusDict.stringVariant(properties)]);
  }
}

class CustomAudioServiceMpris extends AudioServicePlatform {
  late final DBusClient _dBusClient;
  late final OrgMprisMediaPlayer2Tes _mpris;
  AudioHandlerCallbacks? _handlerCallbacks;
  bool _isPlaying = false;

  static void registerWith() {
    if (Platform.isLinux) {
      AudioServicePlatform.instance = CustomAudioServiceMpris();
    }
  }

  void _listenToStreams() {
    _mpris.openUriStream.listen((uri) {
      _handlerCallbacks?.playFromUri(PlayFromUriRequest(uri: uri));
    });

    _mpris.positionStream.listen((position) {
      _handlerCallbacks?.seek(SeekRequest(position: position));
    });

    _mpris.controlStream.listen((event) {
      if (_handlerCallbacks == null) return;
      switch (event) {
        case 'play':
          _handlerCallbacks!.play(const PlayRequest());
        case 'pause':
          _handlerCallbacks!.pause(const PauseRequest());
        case 'next':
          _handlerCallbacks!.skipToNext(const SkipToNextRequest());
        case 'previous':
          _handlerCallbacks!.skipToPrevious(const SkipToPreviousRequest());
        case 'playPause':
          _isPlaying
              ? _handlerCallbacks!.pause(const PauseRequest())
              : _handlerCallbacks!.play(const PlayRequest());
        case 'raise':
          _handlerCallbacks!.customAction(
            const CustomActionRequest(name: 'raise', extras: {}),
          );
      }
    });

    _mpris.volumeStream.listen((value) {
      _handlerCallbacks?.customAction(
        CustomActionRequest(name: 'dbusVolume', extras: {'value': value}),
      );
    });
  }

  @override
  Future<void> configure(ConfigureRequest request) async {
    _dBusClient = DBusClient.session();
    _mpris = OrgMprisMediaPlayer2Tes(
      identity: request.config.androidNotificationChannelName,
    );

    _listenToStreams();

    await _dBusClient.registerObject(_mpris);
    final serviceName =
        'org.mpris.MediaPlayer2.${request.config.androidNotificationChannelId}.instance$pid';
    await _dBusClient.requestName(
      serviceName,
      flags: {DBusRequestNameFlag.doNotQueue},
    );
  }

  @override
  Future<void> setState(SetStateRequest request) async {
    _mpris.position = request.state.updatePosition;
    _isPlaying = request.state.playing;
    _mpris.playbackState = _isPlaying ? 'Playing' : 'Paused';
  }

  @override
  Future<void> setQueue(SetQueueRequest request) async {}

  @override
  Future<void> setMediaItem(SetMediaItemRequest request) async {
    List<String>? artist;
    if (request.mediaItem.artist != null) artist = [request.mediaItem.artist!];

    List<String>? genre;
    if (request.mediaItem.genre != null) genre = [request.mediaItem.genre!];

    _mpris.metadata = CustomMprisMetadata(
      title: request.mediaItem.title,
      trackId: request.mediaItem.id,
      length: request.mediaItem.duration,
      artist: artist,
      artUrl: request.mediaItem.artUri?.toString(),
      album: request.mediaItem.album,
      genre: genre,
    );
  }

  @override
  Future<void> stopService(StopServiceRequest request) async {
    _mpris.playbackState = 'Stopped';
  }

  @override
  Future<void> notifyChildrenChanged(
    NotifyChildrenChangedRequest request,
  ) async {}

  @override
  void setHandlerCallbacks(AudioHandlerCallbacks callbacks) {
    _handlerCallbacks = callbacks;
  }
}
