import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:netease_api/netease_api.dart' as api;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../repository.dart';
import 'data/login_qr_key_status.dart';
import 'data/search_result.dart';

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
  NetworkRepository(String cookiePath, this.cachePath) {
    _repository = api.Repository(
      cookiePath,
      onError: (error) {
        if (error.error is api.RequestError) {
          final requestError = error.error as api.RequestError;
          if (requestError.code == api.kCodeNeedLogin) {
            _onApiUnAuthorized.add(null);
            return;
          }
        }
      },
    );
  }

  static Future<void> initialize() async {
    var documentDir = (await getApplicationDocumentsDirectory()).path;
    if (Platform.isWindows || Platform.isLinux) {
      documentDir = p.join(documentDir, 'quiet');
    }
    final cookiePath = p.join(documentDir, 'cookie');
    final cachePath = p.join(documentDir, 'cache');
    neteaseRepository = NetworkRepository(cookiePath, cachePath);
  }

  late api.Repository _repository;

  final String cachePath;

  final _onApiUnAuthorized = StreamController<void>.broadcast();

  Stream<void> get onApiUnAuthorized => _onApiUnAuthorized.stream;

  /// Fetch lyric by track id
  Future<String?> lyric(int id) async {
    final lyricString = await _repository.lyric(id);
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

  Future<SearchResult<List<Track>>> searchMusics(
    String keyword, {
    int limit = 20,
    int offset = 0,
  }) async {
    final ret = await _repository.searchSongs(
      keyword,
      limit: limit,
      offset: offset,
    );
    final result = await ret.asFuture;
    return SearchResult<List<Track>>(
      result: result.songs.map((e) => e.toTrack(e.privilege)).toList(),
      hasMore: result.hasMore,
      totalCount: result.songCount,
    );
  }

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
      userPlayList.playlist.map((e) => e.toPlaylistDetail(const [])).toList(),
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
    final value = ret.asValue!.value;
    return Result.value(value.playlist.toPlaylistDetail(value.privileges));
  }

  Future<Result<AlbumDetail>> albumDetail(int id) async {
    final ret = await _repository.albumDetail(id);
    if (ret.isError) {
      return ret.asError!;
    }
    final albumDetail = ret.asValue!.value;
    return Result.value(
      AlbumDetail(
        album: albumDetail.album.toAlbum(),
        tracks: albumDetail.songs.map((e) => e.toTrack(null)).toList(),
      ),
    );
  }

  Future<Result<api.MusicVideoDetailResult>> mvDetail(int mvId) =>
      _repository.mvDetail(mvId);

  Future<Result<ArtistDetail>> artist(int id) async {
    final ret = await _repository.artist(id);
    if (ret.isError) {
      return ret.asError!;
    }
    final artistDetail = ret.asValue!.value;
    return Result.value(
      ArtistDetail(
        artist: artistDetail.artist.toArtist(),
        hotSongs: artistDetail.hotSongs.map((e) => e.toTrack(null)).toList(),
        more: artistDetail.more,
      ),
    );
  }

  Future<Result<List<Album>>> artistAlbums(
    int artistId, {
    int limit = 10,
    int offset = 0,
  }) async {
    final ret = await _repository.artistAlbums(
      artistId,
      limit: limit,
      offset: offset,
    );
    if (ret.isError) {
      return ret.asError!;
    }
    final albumList = ret.asValue!.value;
    return Result.value(albumList.map((e) => e.toAlbum()).toList());
  }

  // FIXME
  Future<Result<Map>> artistMvs(
    int artistId, {
    int limit = 20,
    int offset = 0,
  }) =>
      _repository.artistMvs(
        artistId,
        limit: limit,
        offset: offset,
      );

  // FIXME
  Future<Result<Map>> artistDesc(int artistId) =>
      _repository.artistDesc(artistId);

  Future<Result<api.TopListDetail>> topListDetail() =>
      _repository.topListDetail();

  Future<Result<List<PlayRecord>>> getRecord(
    int userId,
    api.PlayRecordType type,
  ) async {
    final records = await _repository.getRecord(userId, type);
    if (records.isError) {
      return records.asError!;
    }
    final record = records.asValue!.value;
    return Result.value(
      record
          .map(
            (e) => PlayRecord(
              playCount: e.playCount,
              score: e.score,
              song: e.song.toTrack(null),
            ),
          )
          .toList(),
    );
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
      personalizedNewSong.map((e) => e.song.toTrack(e.song.privilege)).toList(),
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
          .map(
            (e) => RecommendedPlaylist(
              id: e.id,
              name: e.name,
              copywriter: e.copywriter,
              picUrl: e.picUrl,
              playCount: e.playCount,
              trackCount: e.trackCount,
              alg: e.alg,
            ),
          )
          .toList(),
    );
  }

  Future<Result<List<Track>>> songDetails(List<int> ids) async {
    final ret = await _repository.songDetails(ids);
    if (ret.isError) {
      return ret.asError!;
    }
    final songDetails = ret.asValue!.value.songs;
    final privilegesMap = Map<int, api.PrivilegesItem>.fromEntries(
      ret.asValue!.value.privileges.map((e) => MapEntry(e.id, e)),
    );
    return Result.value(
      songDetails.map((e) => e.toTrack(privilegesMap[e.id])).toList(),
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
      recommendSongs.map((e) => e.toTrack(e.privilege)).toList(),
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
    return Result.value(personalFm.map((e) => e.toTrack(e.privilege)).toList());
  }

  Future<CloudTracksDetail> getUserCloudTracks() async {
    final ret = await _repository.getUserCloudMusic();
    final value = await ret.asFuture;
    return CloudTracksDetail(
      maxSize: int.tryParse(value.maxSize) ?? 0,
      size: int.tryParse(value.size) ?? 0,
      trackCount: value.count,
      tracks: value.data.map((e) => e.toTrack()).toList(),
    );
  }

  Future<String> loginQrKey() async {
    final ret = await _repository.loginQrKey();
    final data = ret.asValue!.value;
    return data['unikey'];
  }

  Future<LoginQrKeyStatus> checkLoginQrKey(String key) async {
    final code = await _repository.loginQrCheck(key);
    switch (code) {
      case 800:
        return LoginQrKeyStatus.expired;
      case 801:
        return LoginQrKeyStatus.waitingScan;
      case 802:
        return LoginQrKeyStatus.waitingConfirm;
      case 803:
        return LoginQrKeyStatus.confirmed;
    }
    throw Exception('unknown error');
  }

  Future<Map> getLoginStatus() => _repository.loginStatus();

  Future<List<Track>> playModeIntelligenceList({
    required int id,
    required int playlistId,
  }) async {
    final ret = await _repository.playModeIntelligenceList(
      id: id,
      playlistId: playlistId,
    );
    final list = await ret.asFuture;
    return list
        .map(
          (e) => e.songInfo.toTrack(
            null,
            isRecommend: e.recommended,
          ),
        )
        .toList();
  }
}

// https://github.com/Binaryify/NeteaseCloudMusicApi/issues/899#issuecomment-680002883
TrackType _trackType({
  required int fee,
  required bool cs,
  required int st,
}) {
  if (st == -200) {
    return TrackType.noCopyright;
  }
  if (cs) {
    return TrackType.cloud;
  }
  switch (fee) {
    case 0:
    case 8:
      return TrackType.free;
    case 4:
      return TrackType.payAlbum;
    case 1:
      return TrackType.vip;
  }
  debugPrint('unknown fee: $fee');
  return TrackType.free;
}

extension _CloudTrackMapper on api.CloudSongItem {
  Track toTrack() {
    final album = AlbumMini(
      id: simpleSong.al.id,
      picUri: simpleSong.al.picUrl,
      name: simpleSong.al.name ?? this.album,
    );
    ArtistMini mapArtist(api.SimpleSongArtistItem item) {
      return ArtistMini(
        id: item.id,
        name: item.name ?? artist,
        imageUrl: '',
      );
    }

    return Track(
      id: songId,
      name: songName,
      album: album,
      duration: Duration(milliseconds: simpleSong.dt),
      type: _trackType(fee: simpleSong.fee, cs: true, st: simpleSong.st),
      artists: simpleSong.ar.map(mapArtist).toList(),
      uri: '',
      imageUrl: album.picUri,
    );
  }
}

extension _FmTrackMapper on api.FmTrackItem {
  Track toTrack(api.Privilege privilege) => Track(
        id: id,
        name: name,
        artists: artists.map((e) => e.toArtist()).toList(),
        album: album.toAlbum(),
        imageUrl: album.picUrl,
        uri: 'http://music.163.com/song/media/outer/url?id=$id.mp3',
        duration: Duration(milliseconds: duration),
        type:
            _trackType(fee: privilege.fee, st: privilege.st, cs: privilege.cs),
      );
}

extension _FmArtistMapper on api.FmArtist {
  ArtistMini toArtist() => ArtistMini(
        id: id,
        name: name,
        imageUrl: picUrl,
      );
}

extension _FmAlbumMapper on api.FmAlbum {
  AlbumMini toAlbum() => AlbumMini(
        id: id,
        name: name,
        picUri: picUrl,
      );
}

extension _PlayListMapper on api.Playlist {
  PlaylistDetail toPlaylistDetail(List<api.PrivilegesItem> privileges) {
    assert(coverImgUrl.isNotEmpty, 'coverImgUrl is empty');
    final privilegesMap = Map<int, api.PrivilegesItem>.fromEntries(
      privileges.map((e) => MapEntry(e.id, e)),
    );
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
      tracks: tracks.map((e) => e.toTrack(privilegesMap[e.id])).toList(),
      commentCount: commentCount,
      shareCount: shareCount,
      trackUpdateTime: trackUpdateTime,
      trackIds: trackIds.map((e) => e.id).toList(),
      createTime: DateTime.fromMillisecondsSinceEpoch(createTime),
      isMyFavorite: specialType == 5,
    );
  }
}

extension _TrackMapper on api.TracksItem {
  Track toTrack(
    api.PrivilegesItem? privilege, {
    bool isRecommend = false,
  }) {
    final p = privilege ?? this.privilege;
    final album = al.id == 0
        ? AlbumMini(id: 0, name: pc?.album ?? '-', picUri: al.picUrl)
        : al.toAlbum();
    final artists = ar.map((e) => e.toArtist()).toList();
    if (artists.isEmpty || artists.first.id == 0) {
      artists.clear();
      artists.add(
        ArtistMini(
          id: 0,
          name: pc?.artist ?? '-',
          imageUrl: artists.firstOrNull?.imageUrl,
        ),
      );
    }
    return Track(
      id: id,
      name: name,
      artists: artists,
      album: album,
      imageUrl: al.picUrl,
      uri: 'http://music.163.com/song/media/outer/url?id=$id.mp3',
      duration: Duration(milliseconds: dt),
      type: _trackType(
        fee: p?.fee ?? fee,
        cs: p?.cs ?? false,
        st: p?.st ?? st,
      ),
      isRecommend: isRecommend,
    );
  }
}

extension _ArtistItemMapper on api.ArtistItem {
  ArtistMini toArtist() {
    return ArtistMini(
      id: id,
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
      id: id,
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
      publishTime: DateTime.fromMillisecondsSinceEpoch(publishTime),
      paid: paid,
      artist: ArtistMini(
        id: artist.id,
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
