import 'package:flutter/material.dart';

class CustomDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final Function(String?) onChanged;
  final String? hint;    // 👈 NEW

  const CustomDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,           // 👈 NEW
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      isExpanded: true,

      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        labelStyle: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade600,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFF0056FF),
            width: 1.4,
          ),
        ),
      ),

      hint: hint != null
          ? Text(
        hint!,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.grey,
        ),
      )
          : null,

      items: items
          .map(
            (item) => DropdownMenuItem(
          value: item,
          child: Text(
            item,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      )
          .toList(),
    );
  }
}
class RoundedTabIndicator extends Decoration {
  final Color color;
  final double height;
  final double radius;

  const RoundedTabIndicator({
    required this.color,
    this.height = 4,
    this.radius = 20,   // same as you wanted
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _RoundedBottomPainter(color, height, radius);
  }
}

class _RoundedBottomPainter extends BoxPainter {
  final Color color;
  final double height;
  final double radius;

  _RoundedBottomPainter(this.color, this.height, this.radius);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    final Paint paint = Paint()..color = color;

    final double width = cfg.size!.width;
    final double left = offset.dx;

    // Bottom indicator (small height = 4)
    final double top = offset.dy + cfg.size!.height - height;

    final Rect rect = Rect.fromLTWH(left, top, width, height);

    final RRect rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: Radius.circular(radius),     // 🔥 Rounded ONLY at top
      topRight: Radius.circular(radius),
    );

    canvas.drawRRect(rrect, paint);
  }
}

