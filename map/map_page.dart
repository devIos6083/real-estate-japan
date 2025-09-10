// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'map_filter.dart';
import 'map_filter_dialog.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // 기본 상태 변수들
  int currentItem = 0;
  MapFilter mapFilter = MapFilter();
  bool _isLoading = false;

  // 지도 관련 변수들
  GoogleMapController? _mapController;
  final Completer<GoogleMapController> _controllerCompleter =
      Completer<GoogleMapController>();

  // 위치 관련 변수들
  Position? _currentPosition;
  bool _isLocationLoading = false;
  String _locationStatus = "위치 서비스 준비 중";

  // 마커 관리
  final Set<Marker> _markers = <Marker>{};

  // 광주 기본 위치
  static const LatLng _defaultCenter = LatLng(35.1595, 126.8526);

  // 초기 카메라 위치
  static const CameraPosition _initialCamera = CameraPosition(
    target: _defaultCenter,
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    debugPrint("MapPage 초기화 시작");

    // 안전한 위치 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _safeInitializeLocation();
      }
    });
  }

  @override
  void dispose() {
    debugPrint("MapPage dispose 시작");
    _mapController?.dispose();
    super.dispose();
  }

  // 안전한 setState 호출
  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  // 안전한 위치 초기화
  Future<void> _safeInitializeLocation() async {
    if (!mounted) return;

    debugPrint("위치 초기화 시작");

    _safeSetState(() {
      _isLocationLoading = true;
      _locationStatus = "위치 권한 확인 중";
    });

    try {
      // 위치 서비스 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _safeSetState(() {
          _locationStatus = "위치 서비스가 비활성화됨";
          _isLocationLoading = false;
        });
        _addDefaultMarker();
        return;
      }

      // 권한 확인
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
        _addDefaultMarker();
        return;
      }

      // 현재 위치 가져오기
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (!mounted) return;

      _safeSetState(() {
        _currentPosition = position;
        _isLocationLoading = false;
        _locationStatus =
            "현재 위치: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
      });

      _addCurrentLocationMarker(position);
      _moveToLocation(LatLng(position.latitude, position.longitude));
    } catch (e) {
      debugPrint("위치 가져오기 실패: $e");
      _safeSetState(() {
        _locationStatus = "위치를 가져올 수 없음";
        _isLocationLoading = false;
      });
      _addDefaultMarker();
    }
  }

  // 기본 마커 추가
  void _addDefaultMarker() {
    if (!mounted) return;

    _safeSetState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('default'),
          position: _defaultCenter,
          infoWindow: const InfoWindow(title: '광주광역시', snippet: '기본 위치'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    });
  }

  // 현재 위치 마커 추가
  void _addCurrentLocationMarker(Position position) {
    if (!mounted) return;

    _safeSetState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('current'),
          position: LatLng(position.latitude, position.longitude),
          infoWindow: const InfoWindow(title: '현재 위치', snippet: '내 위치'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    });
  }

  // 특정 위치로 카메라 이동
  Future<void> _moveToLocation(LatLng location) async {
    if (_mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: location, zoom: 16.0),
        ),
      );
    }
  }

  // 지도 생성 완료 콜백
  void _onMapCreated(GoogleMapController controller) {
    debugPrint("Google Map 생성 완료");
    if (!mounted) return;

    _mapController = controller;
    if (!_controllerCompleter.isCompleted) {
      _controllerCompleter.complete(controller);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Page'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // 위치 새로고침 버튼
          IconButton(
            onPressed: _isLocationLoading
                ? null
                : () {
                    debugPrint("위치 새로고침 요청");
                    _safeInitializeLocation();
                  },
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
            tooltip: '위치 새로고침',
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
            tooltip: '필터 설정',
          ),
        ],
      ),

      // 드로어
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.blue),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '강홍규',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'khkyu9799@gmail.com',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _locationStatus,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.apartment),
              title: const Text('내가 선택한 아파트'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('설정'),
              onTap: () => Navigator.pop(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info),
              title: Text('마커 수: ${_markers.length}'),
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: Text('지도 상태: ${_mapController != null ? "로드됨" : "로딩 중"}'),
            ),
          ],
        ),
      ),

      // 메인 콘텐츠
      body: Column(
        children: [
          // 상태 표시 바
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: _isLocationLoading
                ? Colors.orange.shade100
                : Colors.green.shade100,
            child: Row(
              children: [
                Icon(
                  _isLocationLoading
                      ? Icons.location_searching
                      : Icons.location_on,
                  size: 16,
                  color: _isLocationLoading ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _locationStatus,
                    style: TextStyle(
                      fontSize: 12,
                      color: _isLocationLoading
                          ? Colors.orange.shade800
                          : Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 지도/리스트 영역
          Expanded(
            child: IndexedStack(
              index: currentItem,
              children: [_buildMapView(), _buildListView()],
            ),
          ),
        ],
      ),

      // 하단 네비게이션
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentItem,
        onTap: (value) {
          debugPrint("탭 변경: $value");
          _safeSetState(() {
            currentItem = value;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: '지도'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: '목록'),
        ],
      ),

      // 플로팅 버튼
      floatingActionButton: currentItem == 0
          ? FloatingActionButton(
              onPressed: () {
                debugPrint("내 위치로 버튼 클릭");
                if (_currentPosition != null) {
                  _moveToLocation(
                    LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                  );
                } else {
                  _safeInitializeLocation();
                }
              },
              backgroundColor: Colors.blue,
              child: const Icon(Icons.my_location),
            )
          : null,
    );
  }

  // 지도 뷰
  Widget _buildMapView() {
    debugPrint("지도 뷰 빌드");

    return Container(
      child: GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: _initialCamera,
        onMapCreated: _onMapCreated,
        markers: _markers,
        myLocationEnabled: false, // 충돌 방지를 위해 비활성화
        myLocationButtonEnabled: false,
        compassEnabled: true,
        mapToolbarEnabled: false,
        zoomControlsEnabled: false,

        onTap: (LatLng position) {
          debugPrint("지도 클릭: ${position.latitude}, ${position.longitude}");
          _addTemporaryMarker(position);
        },
      ),
    );
  }

  // 임시 마커 추가
  void _addTemporaryMarker(LatLng position) {
    if (!mounted) return;

    debugPrint("임시 마커 추가: ${position.latitude}, ${position.longitude}");

    _safeSetState(() {
      _markers.removeWhere((marker) => marker.markerId.value == 'temp');
      _markers.add(
        Marker(
          markerId: const MarkerId('temp'),
          position: position,
          infoWindow: InfoWindow(
            title: '선택한 위치',
            snippet:
                '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
        ),
      );
    });
  }

  // 리스트 뷰
  Widget _buildListView() {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (context, index) {
        return ListTile(
          leading: const Icon(Icons.apartment),
          title: Text('부동산 ${index + 1}'),
          subtitle: Text('광주시 ${index + 1}번지'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            debugPrint("부동산 항목 클릭: $index");
          },
        );
      },
    );
  }

  // 필터 다이얼로그
  Future<void> _openFilterDialog() async {
    if (!mounted) return;

    debugPrint("필터 다이얼로그 열기");
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
        debugPrint("필터 적용: $result");
        _safeSetState(() {
          mapFilter = result as MapFilter;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('필터가 적용되었습니다'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("필터 다이얼로그 오류: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }
}
