import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/utils/search_parser.dart';

void main() {
  group('SearchParser', () {
    test('keeps id search behavior', () {
      final parser = SearchParser('id:12345 tag:日本 sort:rank');

      expect(parser.parseId(), '12345');
      expect(parser.toFilterState().isIdSearch, isTrue);
      expect(SearchParser.fromFilterState(parser.toFilterState()), 'id:12345');
    });

    test('parses multiple tags and removes them from keywords', () {
      final parser = SearchParser('葬送的芙莉莲 tag:奇幻 tag:漫画改 sort:rank');

      expect(parser.parseKeywords(), '葬送的芙莉莲');
      expect(parser.parseTags(), ['奇幻', '漫画改']);
      expect(parser.parseSort(), 'rank');
    });

    test('parses adjacent tag and sort syntax', () {
      final parser = SearchParser('tag:Re：从零开始的异世界生活sort:rank');

      expect(parser.parseTags(), ['Re：从零开始的异世界生活']);
      expect(parser.parseSort(), 'rank');
      expect(parser.parseKeywords(), isEmpty);
    });

    test('parses season and maps it to date range', () {
      final parser = SearchParser('season:2026Q1');
      final state = parser.toFilterState();

      expect(state.season, '2026Q1');
      expect(state.effectiveDateRange,
          const SearchDateRange(start: '2025-12-01', end: '2026-03-01'));
    });

    test('parses custom date range', () {
      final parser = SearchParser('date:2026-01-01..2026-04-01');

      expect(
        parser.parseDateRange(),
        const SearchDateRange(start: '2026-01-01', end: '2026-04-01'),
      );
    });

    test('parses rank and score ranges', () {
      final parser = SearchParser('rank:1..5000 score:7.5..10');

      expect(parser.parseRankRange(), const SearchIntRange(min: 1, max: 5000));
      expect(parser.parseScoreRange(),
          const SearchDoubleRange(min: 7.5, max: 10.0));
    });

    test('parses weekday and ignores nsfw tokens', () {
      final parser = SearchParser('weekday:1,3,5 nsfw:true');

      expect(parser.parseWeekdays(), [1, 3, 5]);
      expect(parser.parseKeywords(), isEmpty);
      expect(SearchParser.fromFilterState(parser.toFilterState()),
          'weekday:1,3,5');
    });

    test('serializes filter state back to query syntax', () {
      const state = SearchFilterState(
        keyword: '孤独摇滚',
        tags: ['音乐', '漫画改'],
        sort: 'score',
        season: '2022Q4',
        rankRange: SearchIntRange(min: 1, max: 1000),
        scoreRange: SearchDoubleRange(min: 8.0, max: 10.0),
        weekdays: [6, 1],
      );

      expect(
        SearchParser.fromFilterState(state),
        '孤独摇滚 tag:音乐 tag:漫画改 sort:score season:2022Q4 rank:1..1000 score:8..10 weekday:1,6',
      );
    });

    test('parses and serializes subject types including tokusatsu (type 6)', () {
      final realOnly = SearchParser('假面骑士 type:6');
      expect(realOnly.parseKeywords(), '假面骑士');
      expect(realOnly.parseTypes(), [6]);
      expect(
        SearchParser.fromFilterState(realOnly.toFilterState()),
        '假面骑士 type:6',
      );

      final combined = SearchParser('假面骑士 type:6,2');
      expect(combined.parseTypes(), [2, 6]);
      expect(
        SearchParser.fromFilterState(combined.toFilterState()),
        '假面骑士 type:2,6',
      );

      final adjacent = SearchParser('tag:特摄type:6');
      expect(adjacent.parseTags(), ['特摄']);
      expect(adjacent.parseTypes(), [6]);
      expect(adjacent.parseKeywords(), isEmpty);

      final invalid = SearchParser('假面骑士 type:999');
      expect(invalid.parseTypes(), isEmpty);
      expect(invalid.parseKeywords(), '假面骑士');
    });

    test('resolves effective types from settings and explicit overrides', () {
      const defaultState = SearchFilterState(keyword: '假面骑士');
      expect(defaultState.hasAdvancedFilters, isFalse);
      expect(defaultState.effectiveTypes(includeReal: true), [2, 6]);
      expect(defaultState.effectiveTypes(includeReal: false), [2]);

      const explicitReal = SearchFilterState(keyword: '假面骑士', types: [6]);
      expect(explicitReal.hasAdvancedFilters, isTrue);
      expect(explicitReal.effectiveTypes(includeReal: false), [6]);

      const explicitAnime = SearchFilterState(keyword: '风都侦探', types: [2]);
      expect(explicitAnime.hasAdvancedFilters, isTrue);
      expect(explicitAnime.effectiveTypes(includeReal: true), [2]);
    });
  });
}
