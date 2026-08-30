part of 'home_screen.dart';

class HomeBannerSlot extends ConsumerWidget {
  const HomeBannerSlot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaign = ref.watch(homeBannerCampaignProvider);
    return campaign.when(
      data: (item) {
        if (item == null) {
          return const SizedBox.shrink(
            key: ValueKey('home-bottom-banner-slot'),
          );
        }
        return _HomeBottomBanner(campaign: item);
      },
      loading: () =>
          const SizedBox.shrink(key: ValueKey('home-bottom-banner-slot')),
      error: (error, stackTrace) =>
          const SizedBox.shrink(key: ValueKey('home-bottom-banner-slot')),
    );
  }
}

class _HomeBottomBanner extends StatelessWidget {
  const _HomeBottomBanner({required this.campaign});

  final HomeBannerCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final target = safeHomeBannerUri(campaign);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final minHeight = scale >= 1.8 ? 140.0 : (scale >= 1.4 ? 124.0 : 96.0);
    return Semantics(
      button: target != null,
      label: '${campaign.label}, ${campaign.title}',
      child: Material(
        key: const ValueKey('home-bottom-banner-slot'),
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('home-bottom-banner'),
          onTap: target == null ? null : () => launchUrl(target),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.navy,
                          AppColors.navy,
                          AppColors.teal.withValues(alpha: 0.42),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -8,
                  bottom: -4,
                  child: SizedBox(
                    width: 132,
                    height: 96,
                    child: CustomPaint(
                      key: const ValueKey('home-banner-visual'),
                      painter: const _HomeBannerPainter(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.m,
                    AppSpacing.s,
                    104,
                    AppSpacing.s,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        campaign.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.plateYellow,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        campaign.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h2.copyWith(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        campaign.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                          height: 1.12,
                        ),
                      ),
                      if (target != null) ...[
                        const SizedBox(height: 6),
                        ConstrainedBox(
                          key: const ValueKey('home-bottom-banner-cta'),
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 28,
                            maxWidth: 148,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                AppRadius.button,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s,
                                vertical: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Flexible(
                                    child: Text(
                                      campaign.ctaText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.navy,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  if (scale < 1.8) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.arrow_outward_rounded,
                                      color: AppColors.navy,
                                      size: 14,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeBannerPainter extends CustomPainter {
  const _HomeBannerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final shield = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    final accent = Paint()
      ..color = AppColors.teal.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final yellow = Paint()..color = AppColors.plateYellow;
    final whiteStroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final shieldPath = Path()
      ..moveTo(size.width * 0.53, size.height * 0.1)
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.16,
        size.width * 0.84,
        size.height * 0.22,
      )
      ..lineTo(size.width * 0.78, size.height * 0.66)
      ..quadraticBezierTo(
        size.width * 0.68,
        size.height * 0.84,
        size.width * 0.53,
        size.height * 0.92,
      )
      ..quadraticBezierTo(
        size.width * 0.38,
        size.height * 0.84,
        size.width * 0.28,
        size.height * 0.66,
      )
      ..lineTo(size.width * 0.22, size.height * 0.22)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.16,
        size.width * 0.53,
        size.height * 0.1,
      )
      ..close();
    canvas.drawPath(shieldPath, shield);
    canvas.drawPath(shieldPath, whiteStroke);

    final carBody = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.16,
        size.height * 0.56,
        size.width * 0.72,
        size.height * 0.2,
      ),
      const Radius.circular(12),
    );
    canvas.drawRRect(carBody, yellow);
    canvas.drawCircle(
      Offset(size.width * 0.32, size.height * 0.77),
      7,
      Paint()..color = const Color(0xFF10283F),
    );
    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.77),
      7,
      Paint()..color = const Color(0xFF10283F),
    );
    canvas.drawLine(
      Offset(size.width * 0.43, size.height * 0.39),
      Offset(size.width * 0.34, size.height * 0.56),
      accent,
    );
    canvas.drawLine(
      Offset(size.width * 0.51, size.height * 0.36),
      Offset(size.width * 0.57, size.height * 0.56),
      accent,
    );
    canvas.drawLine(
      Offset(size.width * 0.61, size.height * 0.42),
      Offset(size.width * 0.74, size.height * 0.56),
      accent,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
