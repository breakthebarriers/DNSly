import 'package:flutter/cupertino.dart';
import '../../../models/dns_record_type.dart';
import '../../../theme/app_theme.dart';

class RecordTypePicker extends StatelessWidget {
  final DnsRecordType selected;
  final ValueChanged<DnsRecordType> onChanged;

  const RecordTypePicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(CupertinoIcons.doc_text, size: 14, color: AppColors.muted),
              SizedBox(width: 6),
              Text('Response Record Type',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DnsRecordType.values.map((rt) {
              final isActive = rt == selected;
              return GestureDetector(
                onTap: () => onChanged(rt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isActive ? AppColors.connectGradient : null,
                    color: isActive ? null : AppColors.bg,
                    borderRadius: BorderRadius.circular(8),
                    border: isActive
                        ? null
                        : Border.all(color: AppColors.cardBorder),
                  ),
                  child: Text(
                    rt.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'SF Mono',
                      fontWeight:
                      isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive
                          ? CupertinoColors.white
                          : AppColors.muted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
