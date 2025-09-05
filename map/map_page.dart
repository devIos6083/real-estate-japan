import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'map_filter.dart';
import 'map_filter_dialog.dart';

// 지도와 리스트를 보여주는 메인 페이지
class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MyPageState();
}

class _MyPageState extends State<MapPage> {
  // 하단 네비게이션 바의 현재 선택된 탭 인덱스 (0: 지도, 1: 리스트)
  int currentItem = 0;

  // 부동산 필터링을 위한 설정 객체
  MapFilter mapFilter = MapFilter();

  // 필터 다이얼로그가 열려있는 동안 로딩 상태를 표시하기 위한 변수
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 상단 앱바
      appBar: AppBar(
        title: const Text('Map Page'),
        actions: [
          // 검색/필터 버튼
          IconButton(
            // 로딩 중일 때는 버튼 비활성화
            onPressed: _isLoading ? null : _openFilterDialog,
            // 로딩 중이면 스피너 표시, 아니면 검색 아이콘 표시
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
          ),
        ],
      ),

      // 햄버거 메뉴 (좌측 드로어)
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // 사용자 정보를 표시하는 헤더
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '강홍규',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'khkyu9799@gmail.com',
                    style: TextStyle(fontSize: 16.0, color: Colors.white),
                  ),
                ],
              ),
            ),
            // 메뉴 항목들
            ListTile(title: const Text('내가 선택한 아파트'), onTap: () {}),
            ListTile(title: const Text('설정'), onTap: () {}),
          ],
        ),
      ),

      // 메인 콘텐츠 영역 - 탭에 따라 지도 또는 리스트 표시
      body: AnimatedSwitcher(
        // 탭 전환 시 부드러운 애니메이션 효과 (300ms)
        duration: const Duration(milliseconds: 300),
        child: currentItem == 0
            // 지도 탭이 선택된 경우 (현재는 빈 컨테이너로 placeholder)
            ? Container(key: const ValueKey('map'))
            // 리스트 탭이 선택된 경우
            : ListView(key: const ValueKey('list')),
      ),

      // 하단 네비게이션 바 (지도/리스트 탭 전환)
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentItem,
        onTap: (value) {
          // 탭이 클릭되면 상태 업데이트하여 화면 전환
          setState(() {
            currentItem = value;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'map'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'list'),
        ],
      ),

      // 플로팅 액션 버튼 (현재 위치 검색)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: 현재 위치 기반 검색 기능 구현
        },
        label: const Text('이 위치로 검색하기'),
        icon: const Icon(Icons.location_searching),
      ),
    );
  }

  // 필터 다이얼로그를 여는 비동기 함수
  Future<void> _openFilterDialog() async {
    // 로딩 상태 시작 - 버튼에 스피너 표시
    setState(() {
      _isLoading = true;
    });

    try {
      // 커스텀 페이지 트랜지션으로 부드러운 다이얼로그 열기
      var result = await Navigator.of(context).push(
        PageRouteBuilder(
          // 실제 표시할 페이지 (필터 다이얼로그)
          pageBuilder: (context, animation, secondaryAnimation) {
            return MapFilterDialog(mapFilter: mapFilter);
          },

          // 페이지 전환 애니메이션 정의
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // 페이드 인/아웃과 스케일 효과를 조합한 부드러운 애니메이션
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                // 0.8배에서 1.0배로 확대되면서 나타남
                scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    // 부드러운 곡선 애니메이션 (급격하지 않은 자연스러운 효과)
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: child,
              ),
            );
          },

          // 애니메이션 지속 시간 설정
          transitionDuration: const Duration(milliseconds: 300), // 열릴 때
          reverseTransitionDuration: const Duration(milliseconds: 250), // 닫힐 때
          // 다이얼로그 외부 터치로 닫기 가능
          barrierDismissible: true,
          // 배경 어둡게 처리
          barrierColor: Colors.black54,
        ),
      );

      // 필터 설정이 완료되고 결과가 반환된 경우
      if (result != null && mounted) {
        setState(() {
          // 새로운 필터 설정 적용
          mapFilter = result as MapFilter;
        });

        // 사용자에게 필터 적용 완료 알림 (스낵바)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('필터가 적용되었습니다'),
            duration: const Duration(seconds: 2),
            // 플로팅 스타일의 스낵바 (화면 하단에서 살짝 떠있는 형태)
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      // 오류 발생 시 에러 메시지 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      // 작업 완료 후 로딩 상태 해제 (try-catch 구문과 관계없이 항상 실행)
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
