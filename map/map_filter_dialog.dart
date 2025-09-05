// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'map_filter.dart';

// 부동산 필터링 옵션을 설정하는 다이얼로그 위젯
class MapFilterDialog extends StatefulWidget {
  // 부모에서 전달받은 기존 필터 설정
  final MapFilter mapFilter;
  
  const MapFilterDialog({super.key, required this.mapFilter});

  @override
  State<MapFilterDialog> createState() => _MapFilterDialogState();
}

class _MapFilterDialogState extends State<MapFilterDialog> {
  // 다이얼로그 내부에서 사용할 필터 객체 (수정 가능한 복사본)
  late MapFilter _mapFilter;

  // 건물 동수 선택을 위한 드롭다운 아이템들 (정적 상수로 정의)
  static const List<DropdownMenuItem<String>> _buildingDropdownItems = [
    DropdownMenuItem(value: '0', child: Text('1동')),
    DropdownMenuItem(value: '1', child: Text('2동')),
    DropdownMenuItem(value: '2', child: Text('3동 이상')),
  ];

  // 세대수 선택을 위한 드롭다운 아이템들
  static const List<DropdownMenuItem<String>> _peopleDropdownItems = [
    DropdownMenuItem(value: '0', child: Text('전부')),
    DropdownMenuItem(value: '1', child: Text('100세대 이상')),
    DropdownMenuItem(value: '2', child: Text('300세대 이상')),
    DropdownMenuItem(value: '3', child: Text('500세대 이상')),
  ];

  // 주차대수 선택을 위한 드롭다운 아이템들
  static const List<DropdownMenuItem<String>> _carDropdownItems = [
    DropdownMenuItem(value: '0', child: Text('세대별 1대 미만')),
    DropdownMenuItem(value: '1', child: Text('세대별 1대 이상')),
  ];

  @override
  void initState() {
    super.initState();
    // 부모에서 받은 필터 설정을 복사하여 내부에서 수정 가능하도록 설정
    _mapFilter = MapFilter()
      ..buildingString = widget.mapFilter.buildingString ?? '0'
      ..peopleString = widget.mapFilter.peopleString ?? '0'
      ..carString = widget.mapFilter.carString ?? '0';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // 다이얼로그 제목
      title: const Row(
        children: [
          Icon(Icons.apartment, color: Colors.blue),
          SizedBox(width: 8),
          Text('My 부동산 필터'),
        ],
      ),
      
      // 다이얼로그 내용 영역
      content: SizedBox(
        width: double.maxFinite, // 가로폭을 최대한 활용
        child: Column(
          mainAxisSize: MainAxisSize.min, // 세로 크기를 내용에 맞게 조정
          children: [
            // 안내 텍스트
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '원하는 조건을 선택하여 부동산을 필터링하세요',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 건물 동수 선택 드롭다운
            _buildDropdown(
              items: _buildingDropdownItems,
              value: _mapFilter.buildingString,
              labelText: '건물 동수',
              icon: Icons.apartment,
              onChanged: (value) {
                setState(() {
                  _mapFilter.buildingString = value!;
                });
              },
            ),
            
            const SizedBox(height: 12),
            
            // 세대수 선택 드롭다운
            _buildDropdown(
              items: _peopleDropdownItems,
              value: _mapFilter.peopleString,
              labelText: '세대수',
              icon: Icons.people,
              onChanged: (value) {
                setState(() {
                  _mapFilter.peopleString = value!;
                });
              },
            ),
            
            const SizedBox(height: 12),
            
            // 주차대수 선택 드롭다운
            _buildDropdown(
              items: _carDropdownItems,
              value: _mapFilter.carString,
              labelText: '주차대수',
              icon: Icons.local_parking,
              onChanged: (value) {
                setState(() {
                  _mapFilter.carString = value!;
                });
              },
            ),
          ],
        ),
      ),
      
      // 다이얼로그 하단 버튼들
      actions: [
        // 취소 버튼
        TextButton.icon(
          onPressed: () {
            // 변경사항 없이 다이얼로그 닫기
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('취소'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey.shade600,
          ),
        ),
        
        // 확인 버튼
        ElevatedButton.icon(
          onPressed: () {
            // 설정된 필터를 부모 페이지로 반환하며 다이얼로그 닫기
            Navigator.of(context).pop(_mapFilter);
          },
          icon: const Icon(Icons.check),
          label: const Text('적용'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  // 재사용 가능한 드롭다운 위젯을 생성하는 헬퍼 메서드
  Widget _buildDropdown({
    required List<DropdownMenuItem<String>> items,  // 드롭다운에 표시할 항목들
    required String? value,                         // 현재 선택된 값
    required String labelText,                      // 라벨 텍스트
    required IconData icon,                         // 아이콘
    required ValueChanged<String?> onChanged,       // 값 변경 시 호출될 콜백 함수
  }) {
    // 현재 값이 항목 리스트에 있는지 확인하고, 없으면 첫 번째 항목으로 설정
    String? validValue = value;
    if (validValue != null && !items.any((item) => item.value == validValue)) {
      validValue = items.first.value;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: labelText,
          // 라벨 앞에 아이콘 추가
          prefixIcon: Icon(icon, color: Colors.blue),
          border: InputBorder.none, // 기본 테두리 제거 (Container의 테두리 사용)
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: onChanged,
        value: validValue,
        items: items,
        isExpanded: true, // 긴 텍스트의 오버플로우 방지
        dropdownColor: Colors.white, // 드롭다운 배경색
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
        ),
      ),
    );
  }
}