import 'package:PiliPlus/common/widgets/glass/glass_surface.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:material_ui/material_ui.dart';

Future<bool> showConfirmDialog({
  required BuildContext context,
  required Widget title,
  Widget? content,
  // @Deprecated('use `bool result = await showConfirmDialog()` instead')
  VoidCallback? onConfirm,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          contentPadding: EdgeInsets.zero,
          titlePadding: EdgeInsets.zero,
          actionsPadding: EdgeInsets.zero,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(28)),
          ),
          clipBehavior: Clip.hardEdge,
          content: GlassSurface(
            cornerRadius: 28,
            shape: const LiquidGlassShape.roundedRectangle(
              cornerRadius: 28,
              borderWidth: 1.2,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DefaultTextStyle(
                    style: Theme.of(context).textTheme.titleLarge!,
                    child: title,
                  ),
                  if (content != null) ...[
                    const SizedBox(height: 16),
                    content,
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: Get.back,
                        child: Text(
                          '取消',
                          style: TextStyle(
                            color: ColorScheme.of(context).outline,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Get.back(result: true);
                          onConfirm?.call();
                        },
                        child: const Text('确认'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ) ??
      false;
}

Widget _statusItem({
  required bool enabled,
  required String text,
  required VoidCallback onTap,
}) {
  return ListTile(
    dense: true,
    enabled: enabled,
    title: Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Text(
        '标记为 $text',
        style: const TextStyle(fontSize: 14),
      ),
    ),
    trailing: !enabled ? const Icon(size: 22, Icons.check) : null,
    onTap: onTap,
  );
}

void showPgcFollowDialog({
  required BuildContext context,
  required String type,
  required int followStatus,
  required ValueChanged<int> onUpdateStatus,
}) {
  showDialog(
    context: context,
    builder: (context) => SimpleDialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.hardEdge,
      contentPadding: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
      children: [
        GlassSurface(
          cornerRadius: 28,
          shape: const LiquidGlassShape.roundedRectangle(
            cornerRadius: 28,
            borderWidth: 1.2,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...const [
                  (followStatus: 3, title: '看过'),
                  (followStatus: 2, title: '在看'),
                  (followStatus: 1, title: '想看'),
                ].map(
                  (item) => _statusItem(
                    enabled: followStatus != item.followStatus,
                    text: item.title,
                    onTap: () {
                      Get.back();
                      onUpdateStatus(item.followStatus);
                    },
                  ),
                ),
                ListTile(
                  dense: true,
                  title: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text(
                      '取消$type',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  onTap: () {
                    Get.back();
                    onUpdateStatus(-1);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
