import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'map_filter.dart';
import 'map_filter_dialog.dart';
// Geoflutterfire 관련 import 추가
import '../utils/geoflutterfire.dart';
import 'package:map_trade/models/point.dart';

// 부동산 검색을 위한 메인 지도 페이지
class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  // === 기본 상태 관리 변수들 ===
  int currentItem = 0; // 하단 탭 인덱스 (0: 지도, 1: 리스트)
  MapFilter mapFilter = MapFilter(); // 필터 설정
  bool _isLoading = false; // 필터 다이얼로그 로딩 상태
  bool _isSearching = false; // 부동산 검색 중 상태

  // === 지도 관련 변수들 ===
  GoogleMapController? _mapController;
  final Completer<GoogleMapController> _controllerCompleter =
      Completer<GoogleMapController>();

  // === 위치 관련 변수들 ===
  Position? _currentPosition;
  bool _isLocationLoading = false;
  String _locationStatus = "위치 서비스 준비 중";

  // === 마커 및 데이터 관리 ===
  final Map<MarkerId, Marker> _markers = <MarkerId, Marker>{};
  List<DocumentSnapshot> _apartmentList = [];
  BitmapDescriptor? _apartmentIcon; // 커스텀 아파트 아이콘

  // === Geoflutterfire 인스턴스 ===
  late Geoflutterfire geo;

  // === 애니메이션 ===
  late AnimationController _searchAnimationController;
  late Animation<double> _searchAnimation;

  // === 상수 값들 ===
  static const LatLng _defaultCenter = LatLng(35.1595, 126.8526); // 광주 중심
  static const CameraPosition _initialCamera = CameraPosition(
    target: _defaultCenter,
    zoom: 14.0,
  );

  // === 검색 반경 (km) ===
  double _searchRadius = 2.0;

  @override
  void initState() {
    super.initState();
    debugPrint("🏠 부동산 지도 앱 초기화 시작");

    // Geoflutterfire 초기화
    geo = Geoflutterfire();

    // 검색 애니메이션 초기화
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _searchAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _searchAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // 위젯이 완전히 빌드된 후 초기화 작업 수행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeApp();
      }
    });
  }

  @override
  void dispose() {
    debugPrint("🔄 MapPage dispose");
    _searchAnimationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // === 앱 초기화 (위치 + 커스텀 아이콘) ===
  Future<void> _initializeApp() async {
    debugPrint("📱 앱 초기화 시작");
    await _loadCustomIcon();
    await _initializeLocation();
  }

  // === 커스텀 아파트 아이콘 로드 ===
  Future<void> _loadCustomIcon() async {
    try {
      final icon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/apartment.png', // assets 경로 수정
      );
      if (mounted) {
        setState(() {
          _apartmentIcon = icon;
        });
      }
      debugPrint("🏢 커스텀 아이콘 로드 완료");
    } catch (e) {
      debugPrint("❌ 커스텀 아이콘 로드 실패: $e");
      // 기본 아이콘 사용
      _apartmentIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueOrange,
      );
    }
  }

  // === 안전한 setState 호출 ===
  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  // === 위치 서비스 초기화 ===
  Future<void> _initializeLocation() async {
    if (!mounted) return;

    debugPrint("📍 위치 초기화 시작");

    _safeSetState(() {
      _isLocationLoading = true;
      _locationStatus = "위치 권한 확인 중";
    });

    try {
      // 위치 서비스 활성화 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _safeSetState(() {
          _locationStatus = "위치 서비스가 비활성화됨";
          _isLocationLoading = false;
        });
        _setDefaultLocation();
        return;
      }

      // 위치 권한 확인 및 요청
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _safeSetState(() {
          _locationStatus = "위치 권한이 거부됨";
          _isLocationLoading = false;
        });
        _setDefaultLocation();
        return;
      }

      // 현재 위치 획득
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (!mounted) return;

      _safeSetState(() {
        _currentPosition = position;
        _isLocationLoading = false;
        _locationStatus =
            "위치 획득 완료: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
      });

      _addCurrentLocationMarker(position);
      await _moveToLocation(LatLng(position.latitude, position.longitude));
    } catch (e) {
      debugPrint("❌ 위치 가져오기 실패: $e");
      _safeSetState(() {
        _locationStatus = "위치를 가져올 수 없음";
        _isLocationLoading = false;
      });
      _setDefaultLocation();
    }
  }

  // === 기본 위치(광주)로 설정 ===
  void _setDefaultLocation() {
    debugPrint("📍 기본 위치(광주)로 설정");
    _addMarker(
      id: 'default_location',
      position: _defaultCenter,
      title: '광주광역시',
      snippet: '기본 위치',
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );
  }

  // === 현재 위치 마커 추가 ===
  void _addCurrentLocationMarker(Position position) {
    debugPrint("📍 현재 위치 마커 추가");
    _addMarker(
      id: 'current_location',
      position: LatLng(position.latitude, position.longitude),
      title: '현재 위치',
      snippet: '내가 있는 곳',
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
    );
  }

  // === 마커 추가 헬퍼 함수 ===
  void _addMarker({
    required String id,
    required LatLng position,
    required String title,
    required String snippet,
    BitmapDescriptor? icon,
    VoidCallback? onTap,
  }) {
    final markerId = MarkerId(id);
    final marker = Marker(
      markerId: markerId,
      position: position,
      infoWindow: InfoWindow(title: title, snippet: snippet),
      icon: icon ?? BitmapDescriptor.defaultMarker,
      onTap: onTap,
    );

    _safeSetState(() {
      _markers[markerId] = marker;
    });
  }

  // === 카메라 이동 ===
  Future<void> _moveToLocation(LatLng location) async {
    if (_mapController != null) {
      debugPrint("📷 카메라 이동: $location");
      try {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: location, zoom: 16.0),
          ),
        );
      } catch (e) {
        debugPrint("❌ 카메라 이동 실패: $e");
      }
    }
  }

  // === 지도 생성 완료 콜백 ===
  void _onMapCreated(GoogleMapController controller) {
    debugPrint("🗺️ Google Map 생성 완료");
    if (!mounted) return;

    _mapController = controller;
    if (!_controllerCompleter.isCompleted) {
      _controllerCompleter.complete(controller);
    }

    // 현재 위치가 있으면 해당 위치로 이동
    if (_currentPosition != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _moveToLocation(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        );
      });
    }
  }

  // === 현재 화면 영역에서 부동산 검색 (Geoflutterfire 활용) ===
  Future<void> _searchApartmentsInArea() async {
    if (_mapController == null) {
      _showSnackBar("지도가 아직 준비되지 않았습니다", isError: true);
      return;
    }

    _safeSetState(() {
      _isSearching = true;
    });

    _searchAnimationController.forward();

    try {
      // 현재 지도의 보이는 영역 가져오기
      final bounds = await _mapController!.getVisibleRegion();
      final center = LatLng(
        (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
        (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
      );

      debugPrint("🔍 검색 중심점: $center, 반경: ${_searchRadius}km");

      // Geoflutterfire를 사용한 지리적 검색
      await _searchWithGeoflutterfire(center.latitude, center.longitude);
    } catch (e) {
      debugPrint("❌ 부동산 검색 실패: $e");
      _showSnackBar("검색 중 오류가 발생했습니다", isError: true);
    } finally {
      _safeSetState(() {
        _isSearching = false;
      });
      _searchAnimationController.reverse();
    }
  }

  // === Geoflutterfire를 활용한 지리적 검색 ===
  Future<void> _searchWithGeoflutterfire(
    double latitude,
    double longitude,
  ) async {
    try {
      // GeoFirePoint 생성
      GeoFirePoint center = geo.point(latitude: latitude, longitude: longitude);

      // Firestore 컬렉션 참조
      final collectionRef = FirebaseFirestore.instance.collection('apartments');

      // Geoflutterfire 컬렉션 래퍼 생성
      final geoCollection = geo.collection(collectionRef: collectionRef);

      debugPrint("🔍 GeoHash 검색 시작 - 중심점: ${center.hash}");
      debugPrint("🔍 검색 반경: ${_searchRadius}km");

      // 반경 내 부동산 검색 (스트림으로 실시간 검색)
      final stream = geoCollection.within(
        center: center,
        radius: _searchRadius,
        field: 'location', // Firestore 문서에서 지리 정보가 저장된 필드명
        strictMode: true, // 정확한 거리 계산 사용
      );

      // 스트림을 한 번만 수신하여 결과 가져오기
      final List<DocumentSnapshot> results = await stream.first;

      // 거리 계산 및 정렬
      final List<Map<String, dynamic>> apartmentsWithDistance = [];

      for (DocumentSnapshot doc in results) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('location')) {
          final locationData = data['location'];
          if (locationData is Map<String, dynamic> &&
              locationData.containsKey('geopoint')) {
            final geoPoint = locationData['geopoint'] as GeoPoint;

            // 실제 거리 계산
            final distance = GeoFirePoint.kmDistanceBetween(
              from: Coordinates(latitude, longitude),
              to: Coordinates(geoPoint.latitude, geoPoint.longitude),
            );

            // 필터 조건 적용
            if (_applyMapFilter(data, distance)) {
              apartmentsWithDistance.add({
                'document': doc,
                'data': data,
                'distance': distance,
                'latitude': geoPoint.latitude,
                'longitude': geoPoint.longitude,
              });
            }
          }
        }
      }

      // 거리순으로 정렬
      apartmentsWithDistance.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
      );

      // 결과를 _apartmentList에 저장
      _apartmentList = apartmentsWithDistance
          .map((item) => item['document'] as DocumentSnapshot)
          .toList();

      debugPrint("🏠 검색된 부동산: ${_apartmentList.length}개");

      // 검색된 부동산들을 지도에 마커로 표시
      _displayApartmentMarkersWithDistance(apartmentsWithDistance);

      _showSnackBar(
        "${_apartmentList.length}개의 부동산을 찾았습니다 (${_searchRadius}km 반경)",
      );
    } catch (e) {
      debugPrint("❌ Geoflutterfire 검색 실패: $e");
      _showSnackBar("지리적 검색 중 오류가 발생했습니다", isError: true);
    }
  }

  // === 맵 필터 적용 ===
  bool _applyMapFilter(Map<String, dynamic> data, double distance) {
    // 거리 필터
    if (distance > _searchRadius) return false;

    // 가격 필터 (mapFilter에서 설정된 조건들)
    if (mapFilter.minPrice != null) {
      final price = data['price'] as num?;
      if (price == null || price < mapFilter.minPrice!) return false;
    }

    if (mapFilter.maxPrice != null) {
      final price = data['price'] as num?;
      if (price == null || price > mapFilter.maxPrice!) return false;
    }

    // 방 개수 필터
    if (mapFilter.minRooms != null) {
      final rooms = data['rooms'] as num?;
      if (rooms == null || rooms < mapFilter.minRooms!) return false;
    }

    // 기타 필터 조건들...

    return true;
  }

  // === 거리 정보를 포함한 부동산 마커들을 지도에 표시 ===
  void _displayApartmentMarkersWithDistance(
    List<Map<String, dynamic>> apartmentsWithDistance,
  ) {
    // 기존 부동산 마커들 제거 (현재 위치 마커는 유지)
    _markers.removeWhere((key, value) => key.value.startsWith('apartment_'));

    // 새로운 부동산 마커들 추가
    for (int i = 0; i < apartmentsWithDistance.length; i++) {
      final item = apartmentsWithDistance[i];
      final doc = item['document'] as DocumentSnapshot;
      final data = item['data'] as Map<String, dynamic>;
      final distance = item['distance'] as double;
      final lat = item['latitude'] as double;
      final lng = item['longitude'] as double;

      _addMarker(
        id: 'apartment_${doc.id}',
        position: LatLng(lat, lng),
        title: data['name'] ?? '부동산 ${i + 1}',
        snippet:
            '${data['address'] ?? '주소 정보 없음'} (${distance.toStringAsFixed(1)}km)',
        icon: _apartmentIcon,
        onTap: () => _showApartmentDetailsWithDistance(doc, distance),
      );
    }
  }

  // === 거리 정보를 포함한 부동산 상세 정보 표시 ===
  void _showApartmentDetailsWithDistance(
    DocumentSnapshot apartment,
    double distance,
  ) {
    final data = apartment.data() as Map<String, dynamic>;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    data['name'] ?? '이름 없음',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${distance.toStringAsFixed(1)}km',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('주소: ${data['address'] ?? '주소 정보 없음'}'),
            Text('세대수: ${data['households'] ?? '정보 없음'}'),
            Text('주차대수: ${data['parking'] ?? '정보 없음'}'),
            if (data['price'] != null)
              Text('가격: ${_formatPrice(data['price'])}'),
            if (data['rooms'] != null) Text('방 개수: ${data['rooms']}개'),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // 해당 부동산 위치로 이동
                      final locationData = data['location'];
                      if (locationData is Map<String, dynamic> &&
                          locationData.containsKey('geopoint')) {
                        final geoPoint = locationData['geopoint'] as GeoPoint;
                        _moveToLocation(
                          LatLng(geoPoint.latitude, geoPoint.longitude),
                        );
                      }
                    },
                    child: const Text('지도에서 보기'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('닫기'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // === 가격 포맷팅 ===
  String _formatPrice(dynamic price) {
    if (price is num) {
      if (price >= 100000000) {
        return '${(price / 100000000).toStringAsFixed(1)}억원';
      } else if (price >= 10000) {
        return '${(price / 10000).toStringAsFixed(0)}만원';
      } else {
        return '$price원';
      }
    }
    return price.toString();
  }

  // === 부동산 상세 정보 표시 (기존 메서드 - 호환성 유지) ===
  void _showApartmentDetails(DocumentSnapshot apartment) {
    _showApartmentDetailsWithDistance(apartment, 0.0);
  }

  // === 검색 반경 변경 ===
  void _changeSearchRadius() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('검색 반경 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('현재 반경: ${_searchRadius}km'),
            Slider(
              value: _searchRadius,
              min: 0.5,
              max: 10.0,
              divisions: 19,
              label: '${_searchRadius}km',
              onChanged: (value) {
                setState(() {
                  _searchRadius = value;
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (_apartmentList.isNotEmpty) {
                _searchApartmentsInArea(); // 새로운 반경으로 재검색
              }
            },
            child: const Text('적용'),
          ),
        ],
      ),
    );
  }

  // === 스낵바 표시 ===
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // === 필터 다이얼로그 열기 ===
  Future<void> _openFilterDialog() async {
    _safeSetState(() {
      _isLoading = true;
    });

    try {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MapFilterDialog(mapFilter: mapFilter),
        ),
      );

      if (result != null && mounted) {
        _safeSetState(() {
          mapFilter = result as MapFilter;
        });
        _showSnackBar("필터가 적용되었습니다");

        // 필터 적용 후 재검색
        if (_apartmentList.isNotEmpty) {
          _searchApartmentsInArea();
        }
      }
    } catch (e) {
      debugPrint("❌ 필터 다이얼로그 오류: $e");
      _showSnackBar("필터 설정 중 오류가 발생했습니다", isError: true);
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // === 상단 앱바 ===
      appBar: AppBar(
        title: Text(
          _isSearching ? '검색 중...' : '부동산 지도',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // 검색 반경 설정 버튼
          IconButton(
            onPressed: _changeSearchRadius,
            icon: const Icon(Icons.tune),
            tooltip: '검색 반경: ${_searchRadius}km',
          ),
          // 위치 새로고침 버튼
          IconButton(
            onPressed: _isLocationLoading ? null : _initializeLocation,
            icon: _isLocationLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.my_location),
          ),
          // 필터 버튼
          IconButton(
            onPressed: _isLoading ? null : _openFilterDialog,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.filter_list),
          ),
        ],
      ),

      // === 햄버거 메뉴 ===
      drawer: _buildDrawer(),

      // === 메인 콘텐츠 ===
      body: Column(
        children: [
          // 상태 표시 바
          _buildStatusBar(),

          // 지도/리스트 영역
          Expanded(
            child: IndexedStack(
              index: currentItem,
              children: [_buildMapView(), _buildListView()],
            ),
          ),
        ],
      ),

      // === 하단 네비게이션 ===
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentItem,
        onTap: (value) {
          _safeSetState(() {
            currentItem = value;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: '지도'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: '목록'),
        ],
      ),

      // === 플로팅 액션 버튼 ===
      floatingActionButton: currentItem == 0
          ? _buildFloatingActionButton()
          : null,
    );
  }

  // === 상태 표시 바 위젯 ===
  Widget _buildStatusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _isSearching ? Colors.orange.shade100 : Colors.green.shade100,
      child: Row(
        children: [
          Icon(
            _isSearching ? Icons.search : Icons.location_on,
            size: 16,
            color: _isSearching ? Colors.orange : Colors.green,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isSearching
                  ? "반경 ${_searchRadius}km 내 부동산 검색 중..."
                  : _locationStatus,
              style: TextStyle(
                fontSize: 12,
                color: _isSearching
                    ? Colors.orange.shade800
                    : Colors.green.shade800,
              ),
            ),
          ),
          if (_apartmentList.isNotEmpty)
            Text(
              "${_apartmentList.length}개 발견",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
        ],
      ),
    );
  }

  // === 햄버거 메뉴 위젯 ===
  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue, Colors.blueAccent],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '부동산 지도',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '마커 수: ${_markers.length} | 검색 반경: ${_searchRadius}km',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('검색 반경 설정'),
            subtitle: Text('현재: ${_searchRadius}km'),
            onTap: () {
              Navigator.pop(context);
              _changeSearchRadius();
            },
          ),
          ListTile(
            leading: const Icon(Icons.apartment),
            title: const Text('즐겨찾는 부동산'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('설정'),
            onTap: () => Navigator.pop(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Geoflutterfire 정보'),
            subtitle: Text('지리적 검색 라이브러리 활용'),
            onTap: () {
              Navigator.pop(context);
              _showGeoflutterfireInfo();
            },
          ),
        ],
      ),
    );
  }

  // === Geoflutterfire 정보 다이얼로그 ===
  void _showGeoflutterfireInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Geoflutterfire'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🔍 지리적 위치 기반 검색'),
            SizedBox(height: 8),
            Text('• GeoHash를 활용한 효율적인 검색'),
            Text('• 정확한 거리 계산'),
            Text('• 실시간 위치 기반 필터링'),
            Text('• Haversine 공식 사용'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // === 지도 뷰 위젯 ===
  Widget _buildMapView() {
    return Stack(
      children: [
        GoogleMap(
          mapType: MapType.normal,
          initialCameraPosition: _initialCamera,
          onMapCreated: _onMapCreated,
          markers: Set<Marker>.of(_markers.values),
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          compassEnabled: true,
          mapToolbarEnabled: false,
          zoomControlsEnabled: false,
          onTap: (LatLng position) {
            debugPrint("🗺️ 지도 클릭: $position");
          },
        ),
        // 검색 반경 표시 (선택사항)
        if (_currentPosition != null && _isSearching)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: RadiusPainter(
                  center: LatLng(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                  ),
                  radiusKm: _searchRadius,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // === 리스트 뷰 위젯 (거리 정보 포함) ===
  Widget _buildListView() {
    if (_apartmentList.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('검색된 부동산이 없습니다'),
            SizedBox(height: 8),
            Text('지도에서 "이 위치로 검색" 버튼을 눌러보세요'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _apartmentList.length,
      itemBuilder: (context, index) {
        final doc = _apartmentList[index];
        final data = doc.data() as Map<String, dynamic>;

        // 거리 계산 (현재 위치 또는 검색 중심점 기준)
        double? distance;
        if (_currentPosition != null && data.containsKey('location')) {
          final locationData = data['location'];
          if (locationData is Map<String, dynamic> &&
              locationData.containsKey('geopoint')) {
            final geoPoint = locationData['geopoint'] as GeoPoint;
            distance = GeoFirePoint.kmDistanceBetween(
              from: Coordinates(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              ),
              to: Coordinates(geoPoint.latitude, geoPoint.longitude),
            );
          }
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: const Icon(Icons.apartment, color: Colors.blue),
            title: Row(
              children: [
                Expanded(child: Text(data['name'] ?? '이름 없음')),
                if (distance != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${distance.toStringAsFixed(1)}km',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['address'] ?? '주소 정보 없음'),
                if (data['price'] != null)
                  Text(
                    '가격: ${_formatPrice(data['price'])}',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () =>
                _showApartmentDetailsWithDistance(doc, distance ?? 0.0),
          ),
        );
      },
    );
  }

  // === 플로팅 액션 버튼 위젯 ===
  Widget _buildFloatingActionButton() {
    return AnimatedBuilder(
      animation: _searchAnimation,
      builder: (context, child) {
        return FloatingActionButton.extended(
          onPressed: _isSearching ? null : _searchApartmentsInArea,
          backgroundColor: _isSearching ? Colors.grey : Colors.blue,
          icon: _isSearching
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                    value: _searchAnimation.value,
                  ),
                )
              : const Icon(Icons.search),
          label: Text(
            _isSearching ? '검색 중...' : '이 위치로 검색 (${_searchRadius}km)',
          ),
        );
      },
    );
  }
}

// === 검색 반경 표시를 위한 커스텀 페인터 ===
class RadiusPainter extends CustomPainter {
  final LatLng center;
  final double radiusKm;

  RadiusPainter({required this.center, required this.radiusKm});

  @override
  void paint(Canvas canvas, Size size) {
    // 실제 구현에서는 지도의 현재 줌 레벨과 중심점을 고려하여
    // 정확한 반경을 화면에 그려야 합니다.
    // 여기서는 간단한 원을 그리는 예시입니다.

    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.blue.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // 화면 중심에 원 그리기 (실제로는 더 복잡한 계산 필요)
    final centerPoint = Offset(size.width / 2, size.height / 2);
    const radius = 100.0; // 픽셀 단위 (실제로는 radiusKm을 픽셀로 변환해야 함)

    canvas.drawCircle(centerPoint, radius, paint);
    canvas.drawCircle(centerPoint, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AnimatedProgressBar extends StatelessWidget {
  final double progress;
  final Color color;
  final String label;

  const _AnimatedProgressBar({
    required this.progress,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                height: 8,
                width: MediaQuery.of(context).size.width * progress,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
