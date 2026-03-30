// lib/screens/settings/help_screen.dart
// 帮助中心页

import 'package:flutter/material.dart';
import '../../constants/colors.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // 顶部导航栏
          _buildHeader(),
          
          const SizedBox(height: 20),
          
          // 帮助内容
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 16),
                  _buildFAQList(),
                ],
              ),
            ),
          ),
          
          // 联系客服
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildContactButton(),
          ),
        ],
      ),
    );
  }

  // 顶部导航栏
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
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: const Icon(
              Icons.arrow_back,
              size: 24,
              color: AppColors.textSecondary,
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                '帮助中心',
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

  // 搜索栏
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: const TextField(
        decoration: InputDecoration(
          hintText: '搜索常见问题',
          border: InputBorder.none,
          icon: Icon(Icons.search, color: AppColors.textHint),
        ),
      ),
    );
  }

  // FAQ列表
  Widget _buildFAQList() {
    final List<Map<String, String>> faqItems = [
      {
        'question': '如何绑定伙伴？',
        'answer': '进入"我的"页面，点击"添加伙伴"，输入伙伴编号和密码即可绑定伙伴。',
      },
      {
        'question': '如何设置电子围栏？',
        'answer': '进入伙伴详情页，点击"电子围栏"，选择位置并设置半径即可创建围栏。',
      },
      {
        'question': '伙伴离线怎么办？',
        'answer': '请检查伙伴是否开机，是否有网络信号，或者联系客服获取帮助。',
      },
      {
        'question': '如何共享伙伴给家人？',
        'answer': '进入伙伴设置，点击"共享伙伴"，输入家人的手机号即可共享。',
      },
      {
        'question': '历史轨迹可以保存多久？',
        'answer': '我们会保存最近30天的历史轨迹数据，您可以随时查看和导出。',
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        children: List.generate(faqItems.length, (index) {
          final item = faqItems[index];
          final isLast = index == faqItems.length - 1;
          
          return _buildFAQItem(
            question: item['question']!,
            answer: item['answer']!,
            showDivider: !isLast,
          );
        }),
      ),
    );
  }

  // FAQ项
  Widget _buildFAQItem({
    required String question,
    required String answer,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Theme(
          data: ThemeData().copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text(
              question,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  answer,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Container(
            height: 1,
            color: Colors.grey[100],
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
      ],
    );
  }

  // 联系客服按钮
  Widget _buildContactButton() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('在线客服')),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.chat_outlined, size: 20),
              label: const Text(
                '在线客服',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('电话客服')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: AppColors.primary.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.phone_outlined, size: 20),
              label: const Text(
                '电话客服',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
