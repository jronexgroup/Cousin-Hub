import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF7C3AED);
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color bg = Color(0xFFFDF6EC);
  static const Color night = Color(0xFF1A1208);
  static const Color ink = Color(0xFF3B1F0A);
  static const Color muted = Color(0xFF8B6F5E);
  static const Color soft = Color(0xFFB0927E);
  static const Color card = Color(0xFFF5EDE4);
  static const Color rust = Color(0xFFC4522A);

  static const LinearGradient mainGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Widget gradientButton({required String label, required VoidCallback? onTap,
    bool loading = false, double height = 52}) {
    return SizedBox(width: double.infinity, height: height,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          padding: EdgeInsets.zero),
        child: Ink(decoration: BoxDecoration(
          gradient: loading ? null : mainGradient,
          color: loading ? Colors.grey.shade300 : null,
          borderRadius: BorderRadius.circular(100)),
          child: SizedBox(height: height, child: Center(
            child: loading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: primary, strokeWidth: 2.5))
              : Text(label, style: const TextStyle(fontSize: 15,
                  fontWeight: FontWeight.w700, color: Colors.white)))))));
  }

  static InputDecoration inputDeco(String hint, String icon) => InputDecoration(
    prefixIcon: Padding(padding: const EdgeInsets.only(left: 14, right: 8),
      child: Text(icon, style: const TextStyle(fontSize: 20))),
    prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    hintText: hint, hintStyle: const TextStyle(color: Color(0xFFBBAA99), fontSize: 13),
    filled: true, fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14));

  static Widget errorBox(String msg) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFFFE8E8), borderRadius: BorderRadius.circular(12)),
    child: Row(children: [const Text('❌', style: TextStyle(fontSize: 14)), const SizedBox(width: 8),
      Expanded(child: Text(msg, style: const TextStyle(color: Color(0xFFCC0000), fontSize: 13)))]));

  static Widget sectionTitle(String title) => Text(title,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink));

  static Widget label(String t) => Padding(padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ink)));
}
