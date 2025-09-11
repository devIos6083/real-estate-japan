class MapFilter {
  // === 기존 필터들 ===
  String? buildingString = '0';
  String? peopleString = '0';
  String? carString = '0';

  // === 가격 필터 ===
  double? minPrice;
  double? maxPrice;

  // === 방 개수 필터 ===
  int? minRooms;
  int? maxRooms;

  // === 면적 필터 (평방미터) ===
  double? minArea;
  double? maxArea;

  // === 건물 유형 필터 ===
  List<String> buildingTypes = []; // 아파트, 빌라, 원룸, 오피스텔 등

  // === 거래 유형 필터 ===
  List<String> dealTypes = []; // 매매, 전세, 월세

  // === 기타 필터들 ===
  bool? hasElevator;
  bool? hasParking;
  bool? isPetFriendly;
  bool? hasBalcony;

  // === 건물 연도 필터 ===
  int? minBuildYear;
  int? maxBuildYear;

  // === 층수 필터 ===
  int? minFloor;
  int? maxFloor;

  // === 관리비 필터 ===
  double? maxMaintenanceFee;

  // === 지하철역 거리 필터 (미터) ===
  double? maxDistanceToSubway;

  // === 학교 거리 필터 (미터) ===
  double? maxDistanceToSchool;

  // === 편의시설 필터 ===
  bool? nearMart;
  bool? nearHospital;
  bool? nearPark;

  // === 생성자 ===
  MapFilter({
    this.buildingString = '0',
    this.peopleString = '0',
    this.carString = '0',
    this.minPrice,
    this.maxPrice,
    this.minRooms,
    this.maxRooms,
    this.minArea,
    this.maxArea,
    this.buildingTypes = const [],
    this.dealTypes = const [],
    this.hasElevator,
    this.hasParking,
    this.isPetFriendly,
    this.hasBalcony,
    this.minBuildYear,
    this.maxBuildYear,
    this.minFloor,
    this.maxFloor,
    this.maxMaintenanceFee,
    this.maxDistanceToSubway,
    this.maxDistanceToSchool,
    this.nearMart,
    this.nearHospital,
    this.nearPark,
  });

  // === 복사 생성자 ===
  MapFilter copyWith({
    String? buildingString,
    String? peopleString,
    String? carString,
    double? minPrice,
    double? maxPrice,
    int? minRooms,
    int? maxRooms,
    double? minArea,
    double? maxArea,
    List<String>? buildingTypes,
    List<String>? dealTypes,
    bool? hasElevator,
    bool? hasParking,
    bool? isPetFriendly,
    bool? hasBalcony,
    int? minBuildYear,
    int? maxBuildYear,
    int? minFloor,
    int? maxFloor,
    double? maxMaintenanceFee,
    double? maxDistanceToSubway,
    double? maxDistanceToSchool,
    bool? nearMart,
    bool? nearHospital,
    bool? nearPark,
  }) {
    return MapFilter(
      buildingString: buildingString ?? this.buildingString,
      peopleString: peopleString ?? this.peopleString,
      carString: carString ?? this.carString,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      minRooms: minRooms ?? this.minRooms,
      maxRooms: maxRooms ?? this.maxRooms,
      minArea: minArea ?? this.minArea,
      maxArea: maxArea ?? this.maxArea,
      buildingTypes: buildingTypes ?? this.buildingTypes,
      dealTypes: dealTypes ?? this.dealTypes,
      hasElevator: hasElevator ?? this.hasElevator,
      hasParking: hasParking ?? this.hasParking,
      isPetFriendly: isPetFriendly ?? this.isPetFriendly,
      hasBalcony: hasBalcony ?? this.hasBalcony,
      minBuildYear: minBuildYear ?? this.minBuildYear,
      maxBuildYear: maxBuildYear ?? this.maxBuildYear,
      minFloor: minFloor ?? this.minFloor,
      maxFloor: maxFloor ?? this.maxFloor,
      maxMaintenanceFee: maxMaintenanceFee ?? this.maxMaintenanceFee,
      maxDistanceToSubway: maxDistanceToSubway ?? this.maxDistanceToSubway,
      maxDistanceToSchool: maxDistanceToSchool ?? this.maxDistanceToSchool,
      nearMart: nearMart ?? this.nearMart,
      nearHospital: nearHospital ?? this.nearHospital,
      nearPark: nearPark ?? this.nearPark,
    );
  }

  // === 필터 초기화 ===
  void reset() {
    buildingString = '0';
    peopleString = '0';
    carString = '0';
    minPrice = null;
    maxPrice = null;
    minRooms = null;
    maxRooms = null;
    minArea = null;
    maxArea = null;
    buildingTypes.clear();
    dealTypes.clear();
    hasElevator = null;
    hasParking = null;
    isPetFriendly = null;
    hasBalcony = null;
    minBuildYear = null;
    maxBuildYear = null;
    minFloor = null;
    maxFloor = null;
    maxMaintenanceFee = null;
    maxDistanceToSubway = null;
    maxDistanceToSchool = null;
    nearMart = null;
    nearHospital = null;
    nearPark = null;
  }

  // === 활성화된 필터 개수 ===
  int get activeFilterCount {
    int count = 0;

    if (minPrice != null) count++;
    if (maxPrice != null) count++;
    if (minRooms != null) count++;
    if (maxRooms != null) count++;
    if (minArea != null) count++;
    if (maxArea != null) count++;
    if (buildingTypes.isNotEmpty) count++;
    if (dealTypes.isNotEmpty) count++;
    if (hasElevator != null) count++;
    if (hasParking != null) count++;
    if (isPetFriendly != null) count++;
    if (hasBalcony != null) count++;
    if (minBuildYear != null) count++;
    if (maxBuildYear != null) count++;
    if (minFloor != null) count++;
    if (maxFloor != null) count++;
    if (maxMaintenanceFee != null) count++;
    if (maxDistanceToSubway != null) count++;
    if (maxDistanceToSchool != null) count++;
    if (nearMart != null) count++;
    if (nearHospital != null) count++;
    if (nearPark != null) count++;

    return count;
  }

  // === 필터가 적용되었는지 확인 ===
  bool get hasActiveFilters => activeFilterCount > 0;

  // === JSON 변환 (저장/로드용) ===
  Map<String, dynamic> toJson() {
    return {
      'buildingString': buildingString,
      'peopleString': peopleString,
      'carString': carString,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'minRooms': minRooms,
      'maxRooms': maxRooms,
      'minArea': minArea,
      'maxArea': maxArea,
      'buildingTypes': buildingTypes,
      'dealTypes': dealTypes,
      'hasElevator': hasElevator,
      'hasParking': hasParking,
      'isPetFriendly': isPetFriendly,
      'hasBalcony': hasBalcony,
      'minBuildYear': minBuildYear,
      'maxBuildYear': maxBuildYear,
      'minFloor': minFloor,
      'maxFloor': maxFloor,
      'maxMaintenanceFee': maxMaintenanceFee,
      'maxDistanceToSubway': maxDistanceToSubway,
      'maxDistanceToSchool': maxDistanceToSchool,
      'nearMart': nearMart,
      'nearHospital': nearHospital,
      'nearPark': nearPark,
    };
  }

  // === JSON에서 생성 ===
  factory MapFilter.fromJson(Map<String, dynamic> json) {
    return MapFilter(
      buildingString: json['buildingString'] ?? '0',
      peopleString: json['peopleString'] ?? '0',
      carString: json['carString'] ?? '0',
      minPrice: json['minPrice']?.toDouble(),
      maxPrice: json['maxPrice']?.toDouble(),
      minRooms: json['minRooms']?.toInt(),
      maxRooms: json['maxRooms']?.toInt(),
      minArea: json['minArea']?.toDouble(),
      maxArea: json['maxArea']?.toDouble(),
      buildingTypes: List<String>.from(json['buildingTypes'] ?? []),
      dealTypes: List<String>.from(json['dealTypes'] ?? []),
      hasElevator: json['hasElevator'],
      hasParking: json['hasParking'],
      isPetFriendly: json['isPetFriendly'],
      hasBalcony: json['hasBalcony'],
      minBuildYear: json['minBuildYear']?.toInt(),
      maxBuildYear: json['maxBuildYear']?.toInt(),
      minFloor: json['minFloor']?.toInt(),
      maxFloor: json['maxFloor']?.toInt(),
      maxMaintenanceFee: json['maxMaintenanceFee']?.toDouble(),
      maxDistanceToSubway: json['maxDistanceToSubway']?.toDouble(),
      maxDistanceToSchool: json['maxDistanceToSchool']?.toDouble(),
      nearMart: json['nearMart'],
      nearHospital: json['nearHospital'],
      nearPark: json['nearPark'],
    );
  }

  // === 디버그용 문자열 ===
  @override
  String toString() {
    List<String> activeFilters = [];

    if (minPrice != null || maxPrice != null) {
      activeFilters.add(
        '가격: ${minPrice?.toString() ?? '0'}~${maxPrice?.toString() ?? '∞'}',
      );
    }
    if (minRooms != null || maxRooms != null) {
      activeFilters.add(
        '방: ${minRooms?.toString() ?? '0'}~${maxRooms?.toString() ?? '∞'}개',
      );
    }
    if (buildingTypes.isNotEmpty) {
      activeFilters.add('건물유형: ${buildingTypes.join(', ')}');
    }
    if (dealTypes.isNotEmpty) {
      activeFilters.add('거래유형: ${dealTypes.join(', ')}');
    }

    return activeFilters.isEmpty ? '필터 없음' : activeFilters.join(' | ');
  }
}
