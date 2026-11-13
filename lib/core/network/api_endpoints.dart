class ApiEndpoints {
  static const appInit = '/v1/app/init';
  static const pushToken = '/v1/app/push-token';
  static const heartbeat = '/v1/app/heartbeat';
  static const home = '/v1/home';
  static const recommend = '/v1/dramas/recommend';
  static const filters = '/v1/dramas/filters';
  static const dramas = '/v1/dramas';
  static const dramasNew = '/v1/dramas/new';
  static const dramasTrending = '/v1/dramas/trending';
  static const search = '/v1/search';
  static const searchHot = '/v1/search/hot';
  static const categories = '/v1/categories';
  static const languages = '/v1/languages';
  static const feedForYou = '/v1/feed/for-you';
  static const feedEvents = '/v1/feed/events';
  static String dramaDetail(String id) => '/v1/dramas/$id';
  static String dramaEpisodes(String id) => '/v1/dramas/$id/episodes';
  static String episodePlay(String id, int ep) => '/v1/dramas/$id/episodes/$ep/play';
  static const episodesUnlock = '/v1/episodes/unlock';
  static const myList = '/v1/me/my-list';
  static String myListRemove(String id) => '/v1/me/my-list/$id';
  static const history = '/v1/me/history';
  static const rewardsOverview = '/v1/rewards/overview';
  static const rewardsCheckIn = '/v1/rewards/check-in';
  static String rewardsTaskClaim(String code) => '/v1/rewards/tasks/$code/claim';
  static const profile = '/v1/me/profile';
  static const settings = '/v1/me/settings';
  static const iapCatalog = '/v1/iap/catalog';
  static const iapVerify = '/v1/iap/verify';
  static const socialLogin = '/v1/auth/social-login';
  static const deleteAccount = '/v1/me/account';

  // v4.5 endpoints
  static const ranking = '/v1/dramas/ranking';
  static const eventsTrack = '/v1/events/track';
  static String dramaLike(String id) => '/v1/dramas/$id/like';
  static String dramaShare(String id) => '/v1/dramas/$id/share';
  static const favorites = '/v1/me/favorites';
  static String favoritesRemove(String id) => '/v1/me/favorites/$id';
  static const watchLater = '/v1/me/watch-later';
  static String watchLaterRemove(String id) => '/v1/me/watch-later/$id';
  static const authRegister = '/v1/auth/register';
  static const authLogin = '/v1/auth/login';
  static const authLogout = '/v1/auth/logout';
  static const profileUpdate = '/v1/me/profile';
}
