import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/link.dart';

import '../../../app/theme/app_tokens.dart';
import '../data/partner_inquiry_client.dart';
import '../data/partner_inquiry_config.dart';

class HomePartnerCarousel extends ConsumerStatefulWidget {
  const HomePartnerCarousel({super.key});

  @override
  ConsumerState<HomePartnerCarousel> createState() =>
      _HomePartnerCarouselState();
}

class _HomePartnerCarouselState extends ConsumerState<HomePartnerCarousel> {
  late final PageController _controller;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final textWidth =
            (availableWidth * 0.92 - AppSpacing.s - (AppSpacing.m * 2))
                .clamp(120.0, 300.0)
                .toDouble();
        final height = _requiredCardHeight(context, textWidth);
        return Semantics(
          label: 'Servicios y aliados, tarjeta ${_index + 1} de 4',
          child: Column(
            key: const ValueKey('home-partner-carousel'),
            children: [
              SizedBox(
                height: height,
                child: PageView.builder(
                  key: const ValueKey('home-partner-page-view'),
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        right: index == _slides.length - 1 ? 0 : AppSpacing.s,
                      ),
                      child: _PartnerSlideCard(
                        slide: slide,
                        onTap: () => _openSlide(context, slide),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < _slides.length; index++)
                    AnimatedContainer(
                      key: ValueKey('home-partner-dot-$index'),
                      duration: const Duration(milliseconds: 180),
                      width: index == _index ? 18 : 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: index == _index
                            ? AppColors.teal
                            : AppColors.navy.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  const SizedBox(width: AppSpacing.s),
                  Text(
                    '${_index + 1} de ${_slides.length}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.navy.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  double _requiredCardHeight(BuildContext context, double textWidth) {
    final defaultStyle = DefaultTextStyle.of(context).style;
    final caption = defaultStyle.merge(AppTextStyles.caption);
    final captionStrong = caption.copyWith(fontWeight: FontWeight.w800);
    final heading = defaultStyle.merge(AppTextStyles.h2);
    var tallest = 0.0;
    for (final slide in _slides) {
      final contentHeight =
          _textHeight(context, slide.eyebrow, captionStrong, textWidth) +
          4 +
          _textHeight(context, slide.title, heading, textWidth) +
          4 +
          _textHeight(context, slide.subtitle, caption, textWidth) +
          AppSpacing.s +
          _textHeight(context, slide.cta, captionStrong, textWidth - 20);
      if (contentHeight > tallest) tallest = contentHeight;
    }
    // Reserve one icon line when a scaled CTA wraps before its trailing arrow.
    final required = tallest + (AppSpacing.m * 2) + 18;
    return required < 184 ? 184 : required;
  }

  double _textHeight(
    BuildContext context,
    String text,
    TextStyle style,
    double maxWidth,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);
    return painter.height;
  }

  Future<void> _openSlide(BuildContext context, _PartnerSlide slide) async {
    if (slide.id != 'recruitment') {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => _LocalDemoSheet(slide: slide),
      );
      return;
    }
    final config = ref.read(partnerInquiryConfigProvider);
    if (!config.isAvailable) {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => const _PartnerUnavailableSheet(),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: const PartnerInquiryForm(),
      ),
    );
  }
}

class _PartnerSlideCard extends StatelessWidget {
  const _PartnerSlideCard({required this.slide, required this.onTap});

  final _PartnerSlide slide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${slide.title}. ${slide.subtitle}. ${slide.cta}',
      child: Material(
        key: ValueKey('home-partner-slide-${slide.id}'),
        color: slide.fallbackColor,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                slide.asset,
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: slide.fallbackColor,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.l),
                      child: Icon(
                        slide.icon,
                        size: 64,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xF2132638),
                      Color(0xC7132638),
                      Color(0x33132638),
                    ],
                    stops: [0, 0.58, 1],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Column(
                      key: ValueKey('home-partner-content-${slide.id}'),
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slide.eyebrow,
                          key: ValueKey('home-partner-eyebrow-${slide.id}'),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.plateYellow,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          slide.title,
                          key: ValueKey('home-partner-title-${slide.id}'),
                          style: AppTextStyles.h2.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          slide.subtitle,
                          key: ValueKey('home-partner-subtitle-${slide.id}'),
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 4,
                          children: [
                            Text(
                              slide.cta,
                              key: ValueKey('home-partner-cta-${slide.id}'),
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalDemoSheet extends StatelessWidget {
  const _LocalDemoSheet({required this.slide});

  final _PartnerSlide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey('home-partner-demo-${slide.id}'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        0,
        AppSpacing.l,
        AppSpacing.l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(slide.icon, color: AppColors.teal),
              const SizedBox(width: AppSpacing.s),
              Expanded(child: Text(slide.title, style: AppTextStyles.h2)),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          Text(slide.explanation, style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.m),
          const Text(
            'No se recopilan ni envían datos.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.l),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class _PartnerUnavailableSheet extends StatelessWidget {
  const _PartnerUnavailableSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        0,
        AppSpacing.l,
        AppSpacing.l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Programa en preparación', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.s),
          const Text(
            'El formulario se habilitará cuando estén listos el canal seguro, el aviso de privacidad y la revisión administrativa.',
          ),
          const SizedBox(height: AppSpacing.l),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

class PartnerInquiryForm extends ConsumerStatefulWidget {
  const PartnerInquiryForm({super.key});

  @override
  ConsumerState<PartnerInquiryForm> createState() => _PartnerInquiryFormState();
}

class _PartnerInquiryFormState extends ConsumerState<PartnerInquiryForm> {
  final _formKey = GlobalKey<FormState>();
  final _business = TextEditingController();
  final _contact = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _message = TextEditingController();
  late final String _idempotencyKey;
  var _category = 'other';
  var _consent = false;
  var _submitting = false;
  PartnerInquiryReceipt? _receipt;
  String? _error;

  @override
  void initState() {
    super.initState();
    _idempotencyKey = newPartnerInquiryIdempotencyKey();
  }

  @override
  void dispose() {
    for (final controller in [
      _business,
      _contact,
      _email,
      _phone,
      _city,
      _message,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(partnerInquiryConfigProvider);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.92,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.l,
            0,
            AppSpacing.l,
            AppSpacing.l + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: _receipt == null
              ? Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Quiero ser aliado',
                              style: AppTextStyles.h1,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cerrar',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const Text(
                        'Cuéntanos sobre tu negocio. PicoRadar revisará la solicitud antes de cualquier contacto o publicación.',
                      ),
                      const SizedBox(height: AppSpacing.l),
                      _field(_business, 'Negocio', 'partner-inquiry-business'),
                      _field(
                        _contact,
                        'Persona de contacto',
                        'partner-inquiry-contact',
                      ),
                      _field(
                        _email,
                        'Correo',
                        'partner-inquiry-email',
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) =>
                            RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(value)
                            ? null
                            : 'Revisa el correo.',
                      ),
                      _field(
                        _phone,
                        'Teléfono',
                        'partner-inquiry-phone',
                        keyboardType: TextInputType.phone,
                      ),
                      _field(_city, 'Ciudad', 'partner-inquiry-city'),
                      DropdownButtonFormField<String>(
                        key: const ValueKey('partner-inquiry-category'),
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Categoría',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'automotor',
                            child: Text('Compra y venta'),
                          ),
                          DropdownMenuItem(
                            value: 'insurance',
                            child: Text('Seguros'),
                          ),
                          DropdownMenuItem(
                            value: 'appraisal',
                            child: Text('Peritajes'),
                          ),
                          DropdownMenuItem(
                            value: 'workshop',
                            child: Text('Taller'),
                          ),
                          DropdownMenuItem(value: 'cda', child: Text('CDA')),
                          DropdownMenuItem(value: 'other', child: Text('Otro')),
                        ],
                        onChanged: (value) =>
                            setState(() => _category = value ?? 'other'),
                      ),
                      const SizedBox(height: AppSpacing.m),
                      _field(
                        _message,
                        'Mensaje opcional',
                        'partner-inquiry-message',
                        required: false,
                        maxLines: 3,
                      ),
                      Text(
                        'Aviso de privacidad para aliados · versión ${config.privacyVersion}',
                        style: AppTextStyles.caption,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Link(
                          uri: config.privacyUri,
                          target: LinkTarget.blank,
                          builder: (context, followLink) => TextButton.icon(
                            key: const ValueKey('partner-inquiry-privacy-link'),
                            onPressed: followLink,
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: const Text('Ver aviso de privacidad'),
                          ),
                        ),
                      ),
                      CheckboxListTile(
                        key: const ValueKey('partner-inquiry-consent'),
                        contentPadding: EdgeInsets.zero,
                        value: _consent,
                        onChanged: _submitting
                            ? null
                            : (value) => setState(() {
                                _consent = value ?? false;
                                _error = null;
                              }),
                        title: const Text(
                          'Autorizo a PicoRadar a usar estos datos para revisar esta solicitud y contactarme sobre el programa de aliados.',
                        ),
                      ),
                      if (_error != null) ...[
                        Text(
                          _error!,
                          key: const ValueKey('partner-inquiry-error'),
                          style: const TextStyle(color: AppColors.red),
                        ),
                        const SizedBox(height: AppSpacing.s),
                      ],
                      FilledButton.icon(
                        key: const ValueKey('partner-inquiry-submit'),
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_outlined),
                        label: const Text('Enviar solicitud'),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.green,
                      size: 48,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    Text(
                      'Solicitud recibida',
                      style: AppTextStyles.h1,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Text(
                      'PicoRadar revisará la información antes de contactarte. Referencia: ${_receipt!.id}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.l),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String key, {
    TextInputType? keyboardType,
    String? Function(String value)? validator,
    bool required = true,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: TextFormField(
        key: ValueKey(key),
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLines > 1 ? 1000 : null,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (required && text.isEmpty) return 'Completa este dato.';
          if (text.isNotEmpty && validator != null) return validator(text);
          return null;
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_consent) {
      setState(() => _error = 'Debes autorizar el contacto.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final receipt = await ref
          .read(partnerInquiryClientProvider)
          .submit(
            PartnerInquiryDraft(
              idempotencyKey: _idempotencyKey,
              businessName: _business.text,
              contactName: _contact.text,
              email: _email.text,
              phone: _phone.text,
              city: _city.text,
              category: _category,
              message: _message.text,
              consentVersion: ref
                  .read(partnerInquiryConfigProvider)
                  .privacyVersion,
            ),
          );
      if (mounted) setState(() => _receipt = receipt);
    } on PartnerInquiryFailure catch (failure) {
      if (mounted) setState(() => _error = _safeMessage(failure.code));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _safeMessage(String code) => switch (code) {
    'rate_limited' => 'Hay demasiados intentos. Intenta más tarde.',
    'timeout' ||
    'network' => 'No pudimos conectar. Revisa tu conexión e intenta de nuevo.',
    'not_configured' => 'El canal para aliados aún no está disponible.',
    _ => 'No pudimos enviar la solicitud. Intenta de nuevo.',
  };
}

class _PartnerSlide {
  const _PartnerSlide({
    required this.id,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.explanation,
    required this.asset,
    required this.icon,
    required this.fallbackColor,
  });

  final String id;
  final String eyebrow;
  final String title;
  final String subtitle;
  final String cta;
  final String explanation;
  final String asset;
  final IconData icon;
  final Color fallbackColor;
}

const _slides = [
  _PartnerSlide(
    id: 'automotor',
    eyebrow: 'DEMO LOCAL',
    title: 'Automotor de demostración',
    subtitle: 'Conoce cómo podría funcionar una experiencia de compra y venta.',
    cta: 'Ver explicación',
    explanation: 'Esta vista explica una futura experiencia con aliados automotores. No ofrece inventario, valoración ni contacto comercial real.',
    asset: 'assets/home/partners/automotor_placeholder.png',
    icon: Icons.directions_car_filled_outlined,
    fallbackColor: Color(0xFF2D5C78),
  ),
  _PartnerSlide(
    id: 'insurance',
    eyebrow: 'DEMO LOCAL',
    title: 'Seguro de demostración',
    subtitle: 'Una vista informativa sin cotización ni envío de datos.',
    cta: 'Ver explicación',
    explanation: 'Esta demostración describe un posible acceso a seguros. No cotiza, no compara pólizas y no transmite información personal.',
    asset: 'assets/home/partners/insurance_placeholder.png',
    icon: Icons.shield_outlined,
    fallbackColor: Color(0xFF176A63),
  ),
  _PartnerSlide(
    id: 'appraisal',
    eyebrow: 'DEMO LOCAL',
    title: 'Peritaje de demostración',
    subtitle: 'Explora el concepto antes de integrar centros reales.',
    cta: 'Ver explicación',
    explanation: 'Esta explicación muestra el alcance previsto para peritajes. No agenda citas, no emite diagnósticos y no comparte datos.',
    asset: 'assets/home/partners/appraisal_placeholder.png',
    icon: Icons.fact_check_outlined,
    fallbackColor: Color(0xFF705633),
  ),
  _PartnerSlide(
    id: 'recruitment',
    eyebrow: 'PROGRAMA DE ALIADOS',
    title: 'Haz crecer tu negocio con PicoRadar',
    subtitle: 'Cuéntanos qué servicio prestas y revisaremos tu solicitud.',
    cta: 'Quiero ser aliado',
    explanation: '',
    asset: 'assets/home/partners/recruitment_placeholder.png',
    icon: Icons.handshake_outlined,
    fallbackColor: Color(0xFF4E3F72),
  ),
];
