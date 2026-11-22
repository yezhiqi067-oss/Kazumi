import 'package:hive_ce/hive.dart';
import 'package:kazumi/modules/bangumi/bangumi_tag.dart';
import 'package:kazumi/utils/date_time.dart';
import 'bangumi_interest.dart';

part 'bangumi_item.g.dart';

@HiveType(typeId: 0)
class BangumiItem {
  @HiveField(0)
  int id;
  @HiveField(1)
  int type;
  @HiveField(2)
  String name;
  @HiveField(3)
  String nameCn;
  @HiveField(4)
  String summary;
  @HiveField(5)
  String airDate;
  @HiveField(6)
  int airWeekday;
  @HiveField(7)
  int rank;
  @HiveField(8)
  Map<String, String> images;
  @HiveField(9, defaultValue: [])
  List<BangumiTag> tags;
  @HiveField(10, defaultValue: [])
  List<String> alias;
  @HiveField(11, defaultValue: 0.0)
  double ratingScore;
  @HiveField(12, defaultValue: 0)
  int votes;
  @HiveField(13, defaultValue: [])
  List<int> votesCount;
  @HiveField(14, defaultValue: '')
  String info;
  // Calendar metadata is separate from counted user tags and is not persisted.
  final List<String> metaTags;
  BangumiInterest? interest;

  BangumiItem({
    required this.id,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.summary,
    required this.airDate,
    required this.airWeekday,
    required this.rank,
    required this.images,
    required this.tags,
    required this.alias,
    required this.ratingScore,
    required this.votes,
    required this.votesCount,
    required this.info,
    this.metaTags = const [],
    this.interest,
  });

  factory BangumiItem.fromJson(Map<String, dynamic> json) {
    List<String> parseBangumiAliases(Map<String, dynamic> jsonData) {
      if (jsonData.containsKey('infobox') && jsonData['infobox'] is List) {
        final List<dynamic> infobox = jsonData['infobox'];
        for (var item in infobox) {
          if (item is Map && item['key'] == '别名') {
            // api.bgm.tv /v0 uses `value`; next.bgm.tv /p1 uses `values`
            final dynamic raw = item['values'] ?? item['value'];
            if (raw == null) {
              return [];
            }
            if (raw is List) {
              return raw
                  .map<String>((element) {
                    if (element is Map && element.containsKey('v')) {
                      return element['v'].toString();
                    }
                    return element.toString().trim();
                  })
                  .where((alias) => alias.isNotEmpty)
                  .toList();
            }
            final text = raw.toString().trim();
            return text.isEmpty ? [] : [text];
          }
        }
      }
      return [];
    }

    int parseIntValue(dynamic raw) {
      return raw is num
          ? raw.toInt()
          : int.tryParse(raw?.toString() ?? '') ?? 0;
    }

    List<int> parseBangumiVoteCount(Map<String, dynamic> jsonData) {
      final rating = jsonData['rating'];
      if (rating is! Map) {
        return [];
      }
      final json = rating['count'];
      if (json is Map) {
        return List<int>.generate(10, (i) => parseIntValue(json['${i + 1}']));
      }
      if (json is List) {
        return json.map(parseIntValue).toList();
      }
      return [];
    }

    Map<String, String> resolveImages(Map<String, dynamic> jsonData) {
      final rawImages = jsonData['images'];
      if (rawImages is Map) {
        return rawImages.map(
          (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
        );
      }
      return {
        'large': jsonData['image']?.toString() ?? '',
        'common': '',
        'medium': '',
        'small': '',
        'grid': '',
      };
    }

    String resolveAirDateString(Map<String, dynamic> jsonData) {
      String? nonEmpty(dynamic v) {
        if (v == null) return null;
        final s = v.toString().trim();
        return s.isEmpty ? null : s;
      }

      final fromTop = nonEmpty(jsonData['date']);
      if (fromTop != null) return fromTop;
      final airtime = jsonData['airtime'];
      if (airtime is Map) {
        final fromAir = nonEmpty(airtime['date']);
        if (fromAir != null) return fromAir;
      }
      return '';
    }

    final String airDateStr = resolveAirDateString(json);

    final rawTags = json['tags'] as List? ?? [];
    final tagList = rawTags.map((tag) => BangumiTag.fromJson(tag)).toList();
    final rawMetaTags = json['metaTags'];
    BangumiInterest? interest;
    final interestRaw = json['interest'];
    if (interestRaw is Map<String, dynamic>) {
      interest = BangumiInterest.fromJson(interestRaw);
    } else if (interestRaw is Map) {
      interest =
          BangumiInterest.fromJson(Map<String, dynamic>.from(interestRaw));
    }
    final rawRating = json['rating'];
    final ratingMap =
        rawRating is Map ? rawRating : const <String, dynamic>{};
    final rawRank = ratingMap['rank'];
    final rawScore = ratingMap['score'];
    final rawTotal = ratingMap['total'];
    final rawName = (json['name'] ?? '').toString();
    final rawNameCn = (json['name_cn'] ?? '').toString();
    final rawNameCN = (json['nameCN'] ?? '').toString();
    return BangumiItem(
      id: json['id'],
      type: json['type'] ?? 2,
      name: rawName,
      nameCn: rawNameCn.isEmpty
          ? (rawNameCN.isEmpty ? rawName : rawNameCN)
          : rawNameCn,
      summary: json['summary'] ?? '',
      airDate: airDateStr,
      airWeekday:
          dateStringToWeekday(airDateStr.isEmpty ? '2000-11-11' : airDateStr),
      rank: parseIntValue(rawRank),
      images: resolveImages(json),
      tags: tagList,
      alias: parseBangumiAliases(json),
      ratingScore: double.parse(
        (rawScore is num
                ? rawScore.toDouble()
                : double.tryParse(rawScore?.toString() ?? '') ?? 0.0)
            .toStringAsFixed(1),
      ),
      votes: parseIntValue(rawTotal),
      votesCount: parseBangumiVoteCount(json),
      info: json['info'] ?? '',
      metaTags: rawMetaTags is List
          ? rawMetaTags
              .whereType<String>()
              .map((name) => name.trim())
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList()
          : const [],
      interest: interest,
    );
  }
}
