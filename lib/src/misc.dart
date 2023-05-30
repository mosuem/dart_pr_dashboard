import 'package:github/github.dart';

final noTime = DateTime.fromMillisecondsSinceEpoch(0);

const gWithCircle = 'googler'; // todo: char \u24BC is to tall

String daysSince(DateTime? dt) {
  if (dt == null) return '';
  final d = DateTime.now().difference(dt);
  return d.inDays.toString();
}

String formatUsername(User? user, List<User> googlers) {
  final googlerMark = googlers.any((googler) => googler.login == user?.login)
      ? ' ($gWithCircle)'
      : '';
  return '@${user?.login ?? ''}$googlerMark';
}
