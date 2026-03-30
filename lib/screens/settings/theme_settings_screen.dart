// lib/screens/settings/theme_settings_screen.dart
// 首页风格设置页

import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../routes.dart';
import '../../services/storage_service.dart';

class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  int _selectedTheme = 0; // 0: 经典版, 1: 沉浸式
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentStyle();
  }

  Future<void> _loadCurrentStyle() async {
    final isClassic = await StorageService.isClassicStyle();
    setState(() {
      _selectedTheme = isClassic ? 0 : 1;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildThemeOption(
                        title: '经典版',
                        description: '地图+列表布局，适合管理多个伙伴',
                        icon: Icons.view_list,
                        index: 0,
                      ),
                      const SizedBox(height: 16),
                      _buildThemeOption(
                        title: '互动版',
                        description: '沉浸式大地图，深度关注一个伙伴',
                        icon: Icons.fullscreen,
                        index: 1,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: AppColors.primary.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '保存设置',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _saveSettings() async {
    if (_selectedTheme == 0) {
      await StorageService.setClassicStyle();
    } else {
      await StorageService.setImmersiveStyle();
    }

    if (mounted) {
      // 立即跳转到对应风格的首页
      Navigator.pushNamedAndRemoveUntil(
        context,
        _selectedTheme == 0 ? AppRoutes.home : AppRoutes.homeImmersive,
        (route) => false,
      );
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, size: 24, color: AppColors.textSecondary),
          ),
          const Expanded(
            child: Center(
              child: Text(
                '界面风格',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required String title,
    required String description,
    required IconData icon,
    required int index,
  }) {
    final isSelected = _selectedTheme == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedTheme = index),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFFE8EB) : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 24,
                color: isSelected ? AppColors.primary : Colors.grey[600],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: AppColors.primary, size: 24),
          ],
        ),
      ),
    );
  }
}
