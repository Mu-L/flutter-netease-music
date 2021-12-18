import 'dart:io';

import 'package:async/async.dart';
import 'package:netease_api/netease_api.dart' as api;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:quiet/component/cache/cache.dart';
import 'package:quiet/repository.dart';

export 'package:netease_api/netease_api.dart'
    show
        SearchType,
        PlaylistOperation,
        CommentThreadId,
        CommentType,
        MusicCount,
        CellphoneExistenceCheck,
        PlayRecordType;

class NetworkRepository {
  NetworkRepository(String cookiePath, this.cachePath)
      : _repository = api.Repository(cookiePath),
        _lyricCache = _LyricCache(p.join(cachePath, 'lyrics'));

  static Future<void> initialize() async {
    var documentDir = (await getApplicationDocumentsDirectory()).path;
    if (Platform.isWindows || Platform.isLinux) {
      documentDir = p.join(documentDir, 'quiet');
    }
    final cookiePath = p.join(documentDir, 'cookie');
    final cachePath = p.join(documentDir, 'cache');
    neteaseRepository = NetworkRepository(cookiePath, cachePath);
  }

  final api.Repository _repository;

  final String cachePath;

  final _LyricCache _lyricCache;

  /// Fetch lyric by track id
  Future<String?> lyric(int id) async {
    final key = CacheKey.fromString(id.toString());
    final lyric = await _lyricCache.get(key);
    if (lyric != null) {
      return lyric;
    }
    final lyricString = await _repository.lyric(id);
    if (lyricString != null) {
      await _lyricCache.update(key, lyricString);
    }
    return lyricString;
  }

  Future<Result<List<String>>> searchHotWords() {
    return _repository.searchHotWords();
  }

  ///search by keyword
  Future<Result<Map>> search(
    String? keyword,
    api.SearchType type, {
    int limit = 20,
    int offset = 0,
  }) =>
      _repository.search(keyword, type, limit: limit, offset: offset);

  Future<Result<List<String>>> searchSuggest(String? keyword) =>
      _repository.searchSuggest(keyword);

  ///edit playlist tracks
  ///true : succeed
  Future<bool> playlistTracksEdit(
    api.PlaylistOperation operation,
    int playlistId,
    List<int?> musicIds,
  ) =>
      _repository.playlistTracksEdit(
        operation,
        playlistId,
        musicIds,
      );

  Future<bool> playlistSubscribe(int? id, {required bool subscribe}) =>
      _repository.playlistSubscribe(id, subscribe: subscribe);

  Future<Result<Map>> getComments(
    api.CommentThreadId commentThread, {
    int limit = 20,
    int offset = 0,
  }) =>
      _repository.getComments(
        commentThread,
        limit: limit,
        offset: offset,
      );

  // like track.
  Future<bool> like(int? musicId, {required bool like}) =>
      _repository.like(musicId, like: like);

  // get user licked tracks.
  Future<Result<List<int>>> likedList(int? userId) =>
      _repository.likedList(userId);

  Future<Result<api.MusicCount>> subCount() => _repository.subCount();

  Future<Result<api.CellphoneExistenceCheck>> checkPhoneExist(
    String phone,
    String countryCode,
  ) =>
      _repository.checkPhoneExist(
        phone,
        countryCode,
      );

  Future<Result<List<PlaylistDetail>>> userPlaylist(
    int? userId, {
    int offset = 0,
    int limit = 1000,
  }) async {
    final ret = await _repository.userPlaylist(
      userId,
      offset: offset,
      limit: limit,
    );
    if (ret.isError) {
      return ret.asError!;
    }
    final userPlayList = ret.asValue!.value;
    return Result.value(
      userPlayList.playlist.map((e) => e.toPlaylistDetail()).toList(),
    );
  }

  Future<Result<PlaylistDetail>> playlistDetail(
    int id, {
    int s = 5,
  }) async {
    final ret = await _repository.playlistDetail(id, s: s);
    if (ret.isError) {
      return ret.asError!;
    }
    final playlist = ret.asValue!.value.playlist;
    return Result.value(playlist.toPlaylistDetail());
  }

  Future<Result<AlbumDetail>> albumDetail(int id) async {
    final ret = await _repository.albumDetail(id);
    if (ret.isError) {
      return ret.asError!;
    }
    final albumDetail = ret.asValue!.value;
    return Result.value(AlbumDetail(
      album: albumDetail.album.toAlbum(),
      tracks: albumDetail.songs.map((e) => e.toTrack()).toList(),
    ));
  }

  Future<Result<api.MusicVideoDetailResult>> mvDetail(int mvId) =>
      _repository.mvDetail(mvId);

  Future<Result<ArtistDetail>> artistDetail(int id) async {
    final ret = await _repository.artistDetail(id);
    if (ret.isError) {
      return ret.asError!;
    }
    final artistDetail = ret.asValue!.value;
    return Result.value(ArtistDetail(
      artist: artistDetail.artist.toArtist(),
      hotSongs: artistDetail.hotSongs.map((e) => e.toTrack()).toList(),
      more: artistDetail.more,
    ));
  }

  // FIXME
  Future<Result<Map>> artistAlbums(int artistId,
          {int limit = 10, int offset = 0}) =>
      _repository.artistAlbums(
        artistId,
        limit: limit,
        offset: offset,
      );

  // FIXME
  Future<Result<Map>> artistMvs(int artistId,
          {int limit = 20, int offset = 0}) =>
      _repository.artistMvs(
        artistId,
        limit: limit,
        offset: offset,
      );

  // FIXME
  Future<Result<Map>> artistDesc(int artistId) =>
      _repository.artistDesc(artistId);

  // FIXME
  Future<Result<Map>> topListDetail() async => Result.error('not implement');

  Future<Result<List<PlayRecord>>> getRecord(
      int userId, api.PlayRecordType type) async {
    final records = await _repository.getRecord(userId, type);
    if (records.isError) {
      return records.asError!;
    }
    final record = records.asValue!.value;
    return Result.value(record
        .map((e) => PlayRecord(
              playCount: e.playCount,
              score: e.score,
              song: e.song.toTrack(),
            ))
        .toList());
  }

  // FIXME
  Future<Result<List<Map>>> djSubList() => _repository.djSubList();

  Future<Result<List<Map>>> userDj(int? userId) async =>
      Result.error('not implement');

  Future<Result<List<Track>>> personalizedNewSong() async {
    final ret = await _repository.personalizedNewSong();
    if (ret.isError) {
      return ret.asError!;
    }
    final personalizedNewSong = ret.asValue!.value.result;
    return Result.value(
      personalizedNewSong.map((e) => e.song.toTrack()).toList(),
    );
  }

  Future<Result<List<RecommendedPlaylist>>> personalizedPlaylist({
    int limit = 30,
    int offset = 0,
  }) async {
    final ret = await _repository.personalizedPlaylist(
      limit: limit,
      offset: offset,
    );
    if (ret.isError) {
      return ret.asError!;
    }
    final personalizedPlaylist = ret.asValue!.value.result;
    return Result.value(
      personalizedPlaylist
          .map((e) => RecommendedPlaylist(
                id: e.id,
                name: e.name,
                copywriter: e.copywriter,
                picUrl: e.picUrl,
                playCount: e.playCount,
                trackCount: e.trackCount,
                alg: e.alg,
              ))
          .toList(),
    );
  }

  Future<Result<List<Track>>> songDetails(List<int> ids) async {
    final ret = await _repository.songDetails(ids);
    if (ret.isError) {
      return ret.asError!;
    }
    final songDetails = ret.asValue!.value.songs;
    return Result.value(
      songDetails.map((e) => e.toTrack()).toList(),
    );
  }

  Future<bool> mvSubscribe(int? mvId, {required bool subscribe}) =>
      _repository.mvSubscribe(mvId, subscribe: subscribe);

  Future<bool> refreshLogin() => _repository.refreshLogin();

  Future<void> logout() => _repository.logout();

  // FIXME
  Future<Result<Map>> login(String? phone, String password) =>
      _repository.login(phone, password);

  Future<Result<User>> getUserDetail(int uid) async {
    final ret = await _repository.getUserDetail(uid);
    if (ret.isError) {
      return ret.asError!;
    }
    final userDetail = ret.asValue!.value;
    return Result.value(userDetail.toUser());
  }

  Future<Result<List<Track>>> recommendSongs() async {
    final ret = await _repository.recommendSongs();
    if (ret.isError) {
      return ret.asError!;
    }
    final recommendSongs = ret.asValue!.value.dailySongs;
    return Result.value(
      recommendSongs.map((e) => e.toTrack()).toList(),
    );
  }

  Future<Result<String>> getPlayUrl(int id, [int br = 320000]) =>
      _repository.getPlayUrl(id, br);

  Future<Result<List<Track>>> getPersonalFmMusics() async {
    final ret = await _repository.getPersonalFmMusics();
    if (ret.isError) {
      return ret.asError!;
    }
    final personalFm = ret.asValue!.value.data;
    return Result.value(personalFm.map((e) => e.toTrack()).toList());
  }
}

extension _FmTrackMapper on api.FmTrackItem {
  Track toTrack() => Track(
        id: id,
        name: name,
        artists: artists.map((e) => e.toArtist()).toList(),
        album: album.toAlbum(),
        imageUrl: album.picUrl,
        uri: 'http://music.163.com/song/media/outer/url?id=$id.mp3',
        duration: Duration(milliseconds: duration),
      );
}

extension _FmArtistMapper on api.FmArtist {
  ArtistMini toArtist() => ArtistMini(
        id: id.toString(),
        name: name,
        imageUrl: picUrl,
      );
}

extension _FmAlbumMapper on api.FmAlbum {
  AlbumMini toAlbum() => AlbumMini(
        id: id.toString(),
        name: name,
        picUri: picUrl,
      );
}

extension _PlayListMapper on api.Playlist {
  PlaylistDetail toPlaylistDetail() {
    assert(coverImgUrl.isNotEmpty, 'coverImgUrl is empty');
    return PlaylistDetail(
      id: id,
      name: name,
      coverUrl: coverImgUrl,
      trackCount: trackCount,
      playCount: playCount,
      subscribedCount: subscribedCount,
      creator: creator.toUser(),
      description: description,
      subscribed: subscribed,
      tracks: tracks.map((e) => e.toTrack()).toList(),
      commentCount: commentCount,
      shareCount: shareCount,
      trackUpdateTime: trackUpdateTime,
      trackIds: trackIds.map((e) => e.id).toList(),
    );
  }
}

extension _TrackMapper on api.TracksItem {
  Track toTrack() {
    return Track(
      id: id,
      name: name,
      artists: ar.map((e) => e.toArtist()).toList(),
      album: al.toAlbum(),
      imageUrl: al.picUrl,
      uri: 'http://music.163.com/song/media/outer/url?id=$id.mp3',
      duration: Duration(milliseconds: dt),
    );
  }
}

extension _ArtistItemMapper on api.ArtistItem {
  ArtistMini toArtist() {
    return ArtistMini(
      id: id.toString(),
      name: name,
      imageUrl: null,
    );
  }
}

extension _ArtistMapper on api.Artist {
  Artist toArtist() {
    return Artist(
      id: id,
      name: name,
      picUrl: picUrl,
      briefDesc: briefDesc,
      mvSize: mvSize,
      albumSize: albumSize,
      followed: followed,
      musicSize: musicSize,
      publishTime: publishTime,
      image1v1Url: img1v1Url,
      alias: alias,
    );
  }
}

extension _AlbumItemMapper on api.AlbumItem {
  AlbumMini toAlbum() {
    return AlbumMini(
      id: id.toString(),
      name: name,
      picUri: picUrl,
    );
  }
}

extension _AlbumMapper on api.Album {
  Album toAlbum() {
    return Album(
      id: id,
      name: name,
      description: description,
      briefDesc: briefDesc,
      publishTime: publishTime,
      paid: paid,
      artist: ArtistMini(
        id: artist.id.toString(),
        name: artist.name,
        imageUrl: artist.picUrl,
      ),
      shareCount: info.shareCount,
      commentCount: info.commentCount,
      likedCount: info.likedCount,
      liked: info.liked,
      onSale: onSale,
      company: company,
      picUrl: picUrl,
      size: size,
    );
  }
}

extension _UserMapper on api.Creator {
  User toUser() {
    return User(
      userId: userId,
      nickname: nickname,
      avatarUrl: avatarUrl,
      followers: 0,
      followed: followed,
      backgroundUrl: backgroundUrl,
      createTime: 0,
      description: description,
      detailDescription: detailDescription,
      playlistBeSubscribedCount: 0,
      playlistCount: 0,
      allSubscribedCount: 0,
      followedUsers: 0,
      vipType: vipType,
      level: 0,
      eventCount: 0,
    );
  }
}

extension _UserDetailMapper on api.UserDetail {
  User toUser() {
    return User(
      userId: profile.userId,
      nickname: profile.nickname,
      avatarUrl: profile.avatarUrl,
      followers: profile.follows,
      followed: profile.followed,
      backgroundUrl: profile.backgroundUrl,
      createTime: createTime,
      description: profile.description,
      detailDescription: profile.detailDescription,
      playlistBeSubscribedCount: profile.playlistBeSubscribedCount,
      playlistCount: profile.playlistCount,
      allSubscribedCount: profile.allSubscribedCount,
      followedUsers: profile.followeds,
      vipType: profile.vipType,
      level: level,
      eventCount: profile.eventCount,
    );
  }
}

class _LyricCache implements Cache<String?> {
  _LyricCache(String dir)
      : provider =
            FileCacheProvider(dir, maxSize: 20 * 1024 * 1024 /* 20 Mb */);

  final FileCacheProvider provider;

  @override
  Future<String?> get(CacheKey key) async {
    final file = provider.getFile(key);
    if (await file.exists()) {
      return file.readAsStringSync();
    }
    provider.touchFile(file);
    return null;
  }

  @override
  Future<bool> update(CacheKey key, String? t) async {
    var file = provider.getFile(key);
    if (await file.exists()) {
      file.delete();
    }
    file = await file.create(recursive: true);
    await file.writeAsString(t!);
    try {
      return await file.exists();
    } finally {
      provider.checkSize();
    }
  }
}