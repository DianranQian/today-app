/// 通用季节（核心层，供各子应用复用）
enum Season { spring, summer, autumn, winter }

Season get currentSeason {
  final m = DateTime.now().month;
  if (m >= 3 && m <= 5) return Season.spring;
  if (m >= 6 && m <= 8) return Season.summer;
  if (m >= 9 && m <= 11) return Season.autumn;
  return Season.winter;
}

extension SeasonExt on Season {
  String get label {
    switch (this) {
      case Season.spring: return '春';
      case Season.summer: return '夏';
      case Season.autumn: return '秋';
      case Season.winter: return '冬';
    }
  }

  static Season fromString(String s) {
    switch (s) {
      case 'spring': return Season.spring;
      case 'summer': return Season.summer;
      case 'autumn': return Season.autumn;
      default: return Season.winter;
    }
  }
}
