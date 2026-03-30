// lib/screens/settings/sos_contacts_screen.dart
// SOS紧急联系人页

import 'package:flutter/material.dart';
import '../../constants/colors.dart';

class SOSContactsScreen extends StatefulWidget {
  const SOSContactsScreen({super.key});

  @override
  State<SOSContactsScreen> createState() => _SOSContactsScreenState();
}

class _SOSContactsScreenState extends State<SOSContactsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // 顶部导航栏
          _buildHeader(),
          
          const SizedBox(height: 20),
          
          // 联系人列表
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildContactList(),
                ],
              ),
            ),
          ),
          
          // 添加联系人按钮
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildAddButton(),
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
                'SOS紧急联系人',
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

  // 联系人列表
  Widget _buildContactList() {
    final List<Map<String, String>> contacts = [
      {
        'name': '爸爸',
        'phone': '139****0001',
        'relation': '父亲',
      },
      {
        'name': '妈妈',
        'phone': '138****0002',
        'relation': '母亲',
      },
      {
        'name': '哥哥',
        'phone': '137****0003',
        'relation': '兄长',
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        children: List.generate(contacts.length, (index) {
          final contact = contacts[index];
          final isLast = index == contacts.length - 1;
          
          return _buildContactItem(
            name: contact['name']!,
            phone: contact['phone']!,
            relation: contact['relation']!,
            showDivider: !isLast,
          );
        }),
      ),
    );
  }

  // 联系人项
  Widget _buildContactItem({
    required String name,
    required String phone,
    required String relation,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  size: 24,
                  color: Color(0xFFF44336),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            relation,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('拨打电话')),
                      );
                    },
                    icon: const Icon(
                      Icons.phone,
                      color: Color(0xFF4CAF50),
                      size: 24,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('编辑联系人')),
                      );
                    },
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.textSecondary,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showDivider)
          Container(
            height: 1,
            color: Colors.grey[100],
            margin: const EdgeInsets.only(left: 80),
          ),
      ],
    );
  }

  // 添加联系人按钮
  Widget _buildAddButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('添加紧急联系人')),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF44336),
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: const Color(0xFFF44336).withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          '添加紧急联系人',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
