import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:map_trade/map/map_page.dart';

// 앱 시작 시 보여지는 인트로 페이지 (스플래시 스크린)
// 인터넷 연결 상태를 확인하고 연결되면 메인 페이지로 이동
class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> with TickerProviderStateMixin {
  // 인터넷 연결 상태를 모니터링하는 객체
  final Connectivity _connectivity = Connectivity();

  // 연결 상태 변화를 실시간으로 감지하는 스트림 구독
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  // 오프라인 다이얼로그가 현재 열려있는지 확인하는 플래그
  bool _isDialogOpen = false;

  // 현재 인터넷에 연결되어 있는지 상태를 나타내는 변수
  bool _isConnected = false;

  // 로딩 애니메이션을 위한 컨트롤러
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    // 애니메이션 컨트롤러 초기화
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // 회전 애니메이션 설정 (0도에서 360도까지 반복)
    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );

    // 애니메이션 무한 반복 시작
    _animationController.repeat();

    // 인터넷 연결 상태 모니터링 시작
    _initConnectivity();
  }

  @override
  void dispose() {
    // 메모리 누수 방지를 위해 스트림 구독과 애니메이션 컨트롤러 해제
    _connectivitySubscription.cancel();
    _animationController.dispose();
    super.dispose();
  }

  // 인터넷 연결 상태 모니터링을 초기화하는 비동기 함수
  Future<void> _initConnectivity() async {
    try {
      // 현재 연결 상태를 한 번 확인
      List<ConnectivityResult> results = await _connectivity
          .checkConnectivity();
      _updateConnectionStatus(results);

      // 연결 상태 변화를 실시간으로 감지하는 리스너 등록
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _updateConnectionStatus,
        // 에러 발생 시 처리
        onError: (error) {
          debugPrint('연결 상태 모니터링 오류: $error');
          // 에러 발생 시 오프라인으로 처리
          _updateConnectionStatus([ConnectivityResult.none]);
        },
      );
    } catch (e) {
      // 초기 연결 확인 실패 시 오프라인으로 처리
      debugPrint('연결 상태 초기화 오류: $e');
      _updateConnectionStatus([ConnectivityResult.none]);
    }
  }

  // 연결 상태가 변경될 때마다 호출되는 함수
  void _updateConnectionStatus(List<ConnectivityResult> result) {
    bool hasConnection = false;

    // 연결 결과 리스트를 순회하여 유효한 연결이 있는지 확인
    for (var element in result) {
      if (element == ConnectivityResult.mobile || // 모바일 데이터
          element == ConnectivityResult.wifi || // WiFi
          element == ConnectivityResult.ethernet) {
        // 이더넷
        hasConnection = true;
        break;
      }
    }

    // UI 상태 업데이트
    if (mounted) {
      setState(() {
        _isConnected = hasConnection;
      });
    }

    // 연결 상태에 따른 액션 수행
    if (_isConnected) {
      _handleOnlineState();
    } else {
      _handleOfflineState();
    }
  }

  // 온라인 상태일 때의 처리
  void _handleOnlineState() {
    // 오프라인 다이얼로그가 열려있으면 닫기
    if (_isDialogOpen && mounted) {
      Navigator.of(context).pop();
      _isDialogOpen = false;
    }

    // 2초 후 메인 페이지로 이동 (스플래시 효과)
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          // 부드러운 페이지 전환 애니메이션 적용
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MapPage(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  // 오프라인 상태일 때의 처리
  void _handleOfflineState() {
    _showOfflineDialog();
  }

  // 오프라인 알림 다이얼로그를 표시하는 함수
  void _showOfflineDialog() {
    // 다이얼로그가 이미 열려있거나 위젯이 dispose된 경우 실행하지 않음
    if (_isDialogOpen || !mounted) return;

    _isDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false, // 배경 터치로 닫기 비활성화
      builder: (BuildContext context) {
        return AlertDialog(
          // 다이얼로그 아이콘과 제목
          title: const Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.red),
              SizedBox(width: 8),
              Text('연결 오류'),
            ],
          ),

          // 다이얼로그 내용
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('인터넷에 연결되지 않았습니다.', style: TextStyle(fontSize: 16)),
              SizedBox(height: 8),
              Text(
                'WiFi 또는 모바일 데이터 연결을 확인해주세요.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),

          // 다이얼로그 액션 버튼들
          actions: [
            // 재시도 버튼
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _isDialogOpen = false;
                // 연결 상태 다시 확인
                _initConnectivity();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('재시도'),
            ),

            // 확인 버튼
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _isDialogOpen = false;
              },
              icon: const Icon(Icons.check),
              label: const Text('확인'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // 그라데이션 배경 적용
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF667eea), // 상단 색상
              Color(0xFF764ba2), // 하단 색상
            ],
          ),
        ),
        // 중앙 정렬된 로딩 화면 구성
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 회전하는 앱 아이콘
              AnimatedBuilder(
                animation: _rotationAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationAnimation.value * 2 * 3.14159, // 360도 회전
                    child: const Icon(
                      Icons.apartment_rounded,
                      size: 120,
                      color: Colors.white,
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),

              // 앱 이름
              const Text(
                'My 부동산',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 16),

              // 로딩 인디케이터
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),

              const SizedBox(height: 20),

              // 상태 메시지
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _isConnected ? '앱을 시작하는 중...' : '연결 상태 확인 중...',
                  key: ValueKey(_isConnected),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // 연결 상태 표시
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _isConnected
                      ? Colors.green.withOpacity(0.2)
                      : Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isConnected ? Colors.green : Colors.orange,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isConnected ? Icons.wifi : Icons.wifi_off,
                      color: _isConnected ? Colors.green : Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isConnected ? '온라인' : '오프라인',
                      style: TextStyle(
                        color: _isConnected ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
