part of 'pico_detail_screen.dart';

String _cityRuleText(RestrictionRule rule) {
  final days = (rule.weekdays?.toList() ?? <int>[])..sort();
  final digits = (rule.digits?.toList() ?? <int>[])..sort();
  final basis = switch (rule.digitPosition) {
    RestrictionDigitPosition.firstNumeric => 'Primer número',
    RestrictionDigitPosition.lastNumeric => 'Último dígito',
    null => 'Dígitos',
  };
  final conditions = <String>[
    rule.effect == RestrictionEffect.allow ? 'Excepción' : 'Restricción',
    if (days.isNotEmpty)
      days.map((day) => _weekday(DateTime(2026, 8, 31 + day - 1))).join(' · '),
    if (rule.dateParity != null)
      rule.dateParity == RestrictionDateParity.even
          ? 'Fechas pares'
          : 'Fechas impares',
    if (digits.isNotEmpty) '$basis: ${digits.join(' · ')}',
    if (rule.registrationOrigins?.isNotEmpty == true)
      'Matrícula: ${rule.registrationOrigins!.map((origin) => switch (origin) {
        RegistrationOrigin.local => 'local',
        RegistrationOrigin.foreign => 'foránea',
        RegistrationOrigin.unknown => 'por verificar',
      }).join(', ')}',
    if (rule.timeWindows.isNotEmpty)
      rule.timeWindows
          .map(
            (window) =>
                _cityWindowText(window, safeFullDay: rule.conditions.isEmpty),
          )
          .join('; '),
    if (rule.conditions.isNotEmpty)
      'Condiciones: ${rule.conditions.map(_cityConditionText).join(' + ')}',
  ];
  return conditions.join('\n');
}

String _cityConditionText(RestrictionCondition condition) =>
    switch (condition) {
      PillionPresentCondition(:final value) =>
        value ? 'Con parrillero' : 'Sin parrillero',
      OccupantsAtLeastCondition(:final value) =>
        'Al menos $value ocupantes (incluye conductor)',
      OccupantsBelowCondition(:final value) =>
        'Menos de $value ocupantes (incluye conductor)',
      GrossWeightKgGreaterThanCondition(:final value) =>
        'Peso bruto mayor que $value kg',
      AxlesAtLeastCondition(:final value) => 'Al menos $value ejes',
      InsideScopeRefCondition(:final value) => 'Dentro del ámbito $value',
    };

String _cityMinute(int minute) {
  final hour = minute ~/ 60;
  return '${hour % 12 == 0 ? 12 : hour % 12}:${(minute % 60).toString().padLeft(2, '0')} ${hour < 12 ? 'a. m.' : 'p. m.'}';
}

String _cityWindowText(
  RestrictionTimeWindow window, {
  required bool safeFullDay,
}) {
  if (!window.fullDay) {
    return '${_cityMinute(window.startMinute)} – ${_cityMinute(window.endMinute)}';
  }
  if (!safeFullDay) return 'Horario por verificar';
  final start = _cityMinute24(window.startMinute);
  return '24 h, de $start a $start siguiente';
}

String _cityMinute24(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:'
    '${(minute % 60).toString().padLeft(2, '0')}';

// Presentation-only projection of the seven dated engine results.
class _CityWeekData {
  _CityWeekData(this.days) {
    final byWindow = <String, List<CityRestrictionDaySummary>>{};
    for (final day in days) {
      if (day.status != RestrictionDayStatus.restricted &&
          !day.publishedScheduleInformational) {
        continue;
      }
      final key = day.effectiveWindows.isEmpty
          ? 'Horario por verificar'
          : _windows(day.effectiveWindows);
      byWindow.putIfAbsent(key, () => []).add(day);
    }
    schedules = [
      for (final entry in byWindow.entries)
        (days: _cityDaysLabel(entry.value), hours: entry.key),
    ];
  }
  final List<CityRestrictionDaySummary> days;
  late final List<({String days, String hours})> schedules;
}

String _cityDaysLabel(List<CityRestrictionDaySummary> days) {
  final consecutive =
      days.length > 2 &&
      days.last.date.difference(days.first.date).inDays == days.length - 1;
  return consecutive
      ? '${_weekday(days.first.date)} – ${_weekday(days.last.date)}'
      : days.map((day) => _weekday(day.date)).join(' · ');
}

String _cityDayText(CityRestrictionDaySummary day, {bool weekend = false}) {
  if (day.publishedScheduleInformational) return _digitsOrRule(day);
  return switch (day.status) {
    RestrictionDayStatus.restricted => _digitsOrRule(day),
    RestrictionDayStatus.allowed => weekend ? 'Sin restricción' : 'Libre',
    RestrictionDayStatus.unknown => 'Por verificar',
    RestrictionDayStatus.stale => 'Datos vencidos',
  };
}

String _cityStatus(RestrictionDayStatus status) => switch (status) {
  RestrictionDayStatus.restricted => 'Pico y placa hoy',
  RestrictionDayStatus.allowed => 'Sin restricción hoy',
  RestrictionDayStatus.unknown => 'Por verificar',
  RestrictionDayStatus.stale => 'Datos vencidos',
};

String _cityBasis(CityRestrictionRuleSummary rule) {
  if (rule.isConditional && !rule.publishedScheduleInformational) {
    return 'Consulta condicionada';
  }
  return switch (rule.digitBasis) {
    CityRestrictionDigitBasis.none => 'Consultar regla',
    CityRestrictionDigitBasis.firstNumeric => 'Primer número',
    CityRestrictionDigitBasis.lastNumeric => 'Último dígito',
    CityRestrictionDigitBasis.dateParity => 'Paridad de fecha',
    CityRestrictionDigitBasis.custom => 'Regla especial',
    CityRestrictionDigitBasis.varies => 'Varía por regla',
  };
}

class _CityPage extends StatelessWidget {
  const _CityPage({
    required this.jurisdiction,
    required this.configured,
    required this.now,
    required this.coverages,
    required this.coverage,
    required this.summary,
    required this.ruleSummary,
    required this.week,
    required this.showDates,
    required this.loading,
    required this.failed,
    required this.onSelectCity,
    required this.onCategory,
    required this.onRetry,
    required this.onRules,
    required this.onSources,
    required this.onVehicles,
  });
  final RestrictionJurisdiction jurisdiction;
  final bool configured, showDates, loading, failed;
  final DateTime now;
  final List<_CategoryCoverage> coverages;
  final _CategoryCoverage coverage;
  final CityRestrictionDaySummary summary;
  final CityRestrictionRuleSummary ruleSummary;
  final _CityWeekData week;
  final VoidCallback onSelectCity, onRetry, onRules, onSources, onVehicles;
  final ValueChanged<PicoVehicleCategory> onCategory;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, bounds) {
        final sceneHeight = (bounds.maxHeight * .16).clamp(84.0, 120.0);
        return SingleChildScrollView(
          key: const ValueKey('pico-city-screen'),
          physics: const ClampingScrollPhysics(),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ColoredBox(
                    color: AppColors.navy,
                    child: Column(
                      children: [
                        const _CityHeader(),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _CityIdentity(
                            jurisdiction: jurisdiction,
                            configured: configured,
                            now: now,
                            ruleSet: coverage.ruleSet,
                            loading: loading,
                            onSelect: onSelectCity,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                          child: _CityCategories(
                            coverages: coverages,
                            selected: coverage.category,
                            loading: loading,
                            onChanged: onCategory,
                          ),
                        ),
                        _CityScene(
                          category: coverage.category,
                          cityName: _shortCityLabel(jurisdiction),
                          summary: summary,
                          loading: loading,
                          failed: failed,
                          height: sceneHeight,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (failed) ...[
                          const Text(
                            'No pudimos cargar la cobertura. Estado sin confirmar.',
                          ),
                          TextButton.icon(
                            key: const ValueKey('pico-city-retry'),
                            onPressed: onRetry,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                        _CityWeek(
                          week: week,
                          now: now,
                          showDates: showDates,
                          basis:
                              '${coverage.category.label} · ${_cityBasis(ruleSummary)}',
                          onRules: onRules,
                        ),
                        const SizedBox(height: 8),
                        _CitySchedule(week: week),
                        const SizedBox(height: 8),
                        _CityAction(
                          key: const ValueKey('pico-city-rule-open'),
                          icon: Icons.description_outlined,
                          label: 'Ver regla y vigencia',
                          primary: true,
                          onTap: onRules,
                        ),
                        const SizedBox(height: 8),
                        _CityAction(
                          key: const ValueKey('pico-city-vehicles-open'),
                          icon: Icons.directions_car_outlined,
                          label: 'Mis vehículos',
                          onTap: onVehicles,
                        ),
                        const SizedBox(height: 4),
                        _CitySourceRow(
                          ruleSet: coverage.ruleSet,
                          onTap: onSources,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CityHeader extends StatelessWidget {
  const _CityHeader();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Volver',
          onPressed: () => _goBack(context),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: .10),
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 48),
          ),
          icon: const Icon(Icons.arrow_back_rounded, size: 24),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Pico y placa de la ciudad',
            key: const ValueKey('pico-city-header'),
            style: AppTextStyles.h2.copyWith(fontSize: 18, color: Colors.white),
          ),
        ),
        IconButton(
          key: const ValueKey('pico-city-info'),
          tooltip: 'Información',
          onPressed: () => _showCityInfo(context),
          style: IconButton.styleFrom(
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 48),
          ),
          icon: const Icon(Icons.info_outline_rounded),
        ),
      ],
    ),
  );
}

class _CityIdentity extends StatelessWidget {
  const _CityIdentity({
    required this.jurisdiction,
    required this.configured,
    required this.now,
    required this.ruleSet,
    required this.loading,
    required this.onSelect,
  });
  final RestrictionJurisdiction jurisdiction;
  final bool configured, loading;
  final DateTime now;
  final RestrictionRuleSet ruleSet;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.55;
    final style = AppTextStyles.display.copyWith(
      fontSize: largeText ? 24 : 28,
      color: Colors.white,
    );
    final label = _shortCityLabel(jurisdiction);
    final verified = ruleSet.verifiedAt;
    final selector = Semantics(
      label: 'Cambiar ciudad de consulta. Ciudad actual: $label',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        key: const ValueKey('pico-city-change'),
        onTap: onSelect,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: largeText
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFFD9E7EF),
                            size: 24,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Ciudad de consulta',
                              style: TextStyle(color: Color(0xFFCCDEE8)),
                            ),
                          ),
                          Icon(
                            Icons.expand_more,
                            color: Color(0xFFCCDEE8),
                            size: 22,
                          ),
                        ],
                      ),
                      Text(
                        label,
                        key: const ValueKey('pico-city-short-label'),
                        style: style,
                      ),
                      Text(
                        configured ? 'Configurada' : 'Consulta temporal',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 14,
                          color: const Color(0xFFCCDEE8),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFFD9E7EF),
                        size: 24,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              label,
                              key: const ValueKey('pico-city-short-label'),
                              style: style,
                            ),
                            Text(
                              configured ? 'Configurada' : 'Consulta temporal',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 14,
                                color: const Color(0xFFCCDEE8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.expand_more,
                        color: Color(0xFFCCDEE8),
                        size: 22,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
    final freshness = Container(
      key: const ValueKey('pico-city-freshness'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        border: Border.all(color: Colors.white.withValues(alpha: .16)),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.event_available_outlined,
            size: 23,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_weekday(now)} ${now.day} ${_monthName(now.month).substring(0, 4).toLowerCase()}',
                  style: AppTextStyles.bodyStrong.copyWith(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                Text(
                  loading
                      ? 'Cargando datos'
                      : verified == null
                      ? 'Sin verificación'
                      : '${ruleSet.dataIsStale || !ruleSet.coverageKnown ? 'Por revisar' : 'Verificado'}\n${_shortDate(verified)}',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 14,
                    color: const Color(0xFFBDCEDC),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, bounds) {
        final textWidth = _cityTextSize(context, label, style).width;
        final inline =
            !largeText && textWidth + 54 + 144 + 8 <= bounds.maxWidth;
        if (!inline) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [selector, const SizedBox(height: 6), freshness],
          );
        }
        return Row(
          children: [
            Expanded(child: selector),
            const SizedBox(width: 8),
            SizedBox(width: 144, child: freshness),
          ],
        );
      },
    );
  }
}

Size _cityTextSize(
  BuildContext context,
  String text,
  TextStyle style, {
  double maxWidth = double.infinity,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.maybeLocaleOf(context),
  )..layout(maxWidth: maxWidth);
  final size = painter.size;
  painter.dispose();
  return size;
}

class _CityCategories extends StatelessWidget {
  const _CityCategories({
    required this.coverages,
    required this.selected,
    required this.loading,
    required this.onChanged,
  });
  final List<_CategoryCoverage> coverages;
  final PicoVehicleCategory selected;
  final bool loading;
  final ValueChanged<PicoVehicleCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('pico-city-category-segment'),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: .20)),
        color: Colors.white.withValues(alpha: .04),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final coverage in coverages)
            Expanded(
              child: _CityCategoryButton(
                coverage: coverage,
                selected: selected == coverage.category,
                loading: loading,
                onTap: () => onChanged(coverage.category),
              ),
            ),
        ],
      ),
    );
  }
}

class _CityCategoryButton extends StatelessWidget {
  const _CityCategoryButton({
    required this.coverage,
    required this.selected,
    required this.loading,
    required this.onTap,
  });
  final _CategoryCoverage coverage;
  final bool selected, loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.teal : const Color(0xFFCAD9E5);
    final label = coverage.category.label;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          key: ValueKey('pico-city-category-${coverage.category.name}'),
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final title = Text(
                    label,
                    style: AppTextStyles.bodyStrong.copyWith(
                      fontSize: 14,
                      color: color,
                    ),
                  );
                  final icon = Icon(
                    _categoryIcon(coverage.category),
                    size: 20,
                    color: color,
                  );
                  final compact =
                      _cityTextSize(
                            context,
                            label,
                            AppTextStyles.bodyStrong.copyWith(fontSize: 14),
                          ).width +
                          26 >
                      bounds.maxWidth;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (compact) ...[
                        icon,
                        title,
                      ] else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            icon,
                            const SizedBox(width: 4),
                            Flexible(child: title),
                          ],
                        ),
                      if (!loading && !coverage.ruleSet.coverageKnown)
                        Text(
                          'Sin cobertura',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 12,
                            color: color,
                          ),
                        ),
                      if (!loading && coverage.ruleSet.dataIsStale)
                        Text(
                          'Por revisar',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 12,
                            color: color,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CityScene extends StatelessWidget {
  const _CityScene({
    required this.category,
    required this.cityName,
    required this.summary,
    required this.loading,
    required this.failed,
    required this.height,
  });
  final PicoVehicleCategory category;
  final String cityName;
  final CityRestrictionDaySummary summary;
  final bool loading, failed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final informational =
        summary.publishedScheduleInformational && !loading && !failed;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.75;
    final textColumnFraction = largeText ? .70 : .54;
    final vehicleFraction = largeText ? .28 : .42;
    final label = loading
        ? 'Cargando cobertura'
        : informational
        ? 'Calendario oficial publicado'
        : _cityStatus(summary.status);
    final color = _statusColor(summary.status);
    final statusStyle = AppTextStyles.h1.copyWith(
      fontSize: informational ? 19 : (largeText ? 20 : 24),
      color: Colors.white,
    );
    return LayoutBuilder(
      builder: (context, bounds) {
        final textWidth = bounds.maxWidth * textColumnFraction - 64;
        final textHeight = _cityTextSize(
          context,
          label,
          statusStyle,
          maxWidth: textWidth,
        ).height;
        final detailStyle = AppTextStyles.bodyStrong.copyWith(
          color: Colors.white,
        );
        final informationalDetails = informational
            ? [
                _digitsOrRule(summary),
                if (summary.effectiveWindows.isNotEmpty)
                  _windows(summary.effectiveWindows),
                'Sujeto a vías y excepciones',
              ]
            : summary.status == RestrictionDayStatus.restricted && !loading
            ? [_digitsOrRule(summary)]
            : const <String>[];
        final detailsHeight = informationalDetails.fold<double>(
          0,
          (height, detail) =>
              height +
              _cityTextSize(
                context,
                detail,
                detailStyle,
                maxWidth: textWidth,
              ).height +
              4,
        );
        final requiredHeight = textHeight + detailsHeight + 36;
        final sceneHeight = height > requiredHeight ? height : requiredHeight;
        return SizedBox(
          key: const ValueKey('pico-city-hero'),
          height: sceneHeight,
          child: Semantics(
            key: const ValueKey('pico-city-status-semantics'),
            container: true,
            excludeSemantics: true,
            label: _citySceneSemantics(
              label: label,
              category: category,
              cityName: cityName,
              summary: summary,
              details: informationalDetails,
              loading: loading,
              failed: failed,
              informational: informational,
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/pico/pico_personal_city_background_owner_v1.png',
                    fit: BoxFit.cover,
                    cacheWidth:
                        (bounds.maxWidth *
                                MediaQuery.devicePixelRatioOf(context))
                            .ceil(),
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: AppColors.navy),
                  ),
                ),
                Positioned.fill(
                  child: ColoredBox(
                    color: AppColors.navy.withValues(alpha: .83),
                  ),
                ),
                Positioned(
                  left: 16,
                  top: 8,
                  width: bounds.maxWidth * textColumnFraction - 16,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: .25),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          loading || failed
                              ? Icons.help_outline_rounded
                              : _statusIcon(summary.status),
                          size: 29,
                          color: loading
                              ? Colors.white
                              : Color.lerp(color, Colors.white, .6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: statusStyle),
                            for (
                              var index = 0;
                              index < informationalDetails.length;
                              index += 1
                            )
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  informationalDetails[index],
                                  style:
                                      informational &&
                                          index ==
                                              informationalDetails.length - 1
                                      ? AppTextStyles.caption.copyWith(
                                          color: Colors.white,
                                          fontSize: 13,
                                        )
                                      : detailStyle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 10,
                  width: bounds.maxWidth * vehicleFraction,
                  height: sceneHeight - 16,
                  child: KeyedSubtree(
                    key: const ValueKey('pico-city-hero-art'),
                    child: Image.asset(
                      _cityHeroVehicleAsset(category),
                      key: ValueKey(
                        'pico-city-hero-vehicle-art-${category.name}',
                      ),
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomCenter,
                      cacheWidth:
                          (bounds.maxWidth *
                                  vehicleFraction *
                                  MediaQuery.devicePixelRatioOf(context))
                              .ceil(),
                      semanticLabel: category.label,
                      errorBuilder: (_, _, _) => Icon(
                        _categoryIcon(category),
                        color: Colors.white,
                        size: 54,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 12,
                  child: ClipPath(
                    clipper: const _CityWave(),
                    child: const ColoredBox(color: AppColors.background),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _citySceneSemantics({
  required String label,
  required PicoVehicleCategory category,
  required String cityName,
  required CityRestrictionDaySummary summary,
  required List<String> details,
  required bool loading,
  required bool failed,
  required bool informational,
}) {
  final date = summary.date;
  final dateLabel =
      '${_weekday(date)} ${date.day} de ${_monthName(date.month).toLowerCase()} de ${date.year}';
  final sourceUri = summary.sourceUrl == null
      ? null
      : Uri.tryParse(summary.sourceUrl!);
  final sourceHost =
      sourceUri != null &&
          sourceUri.scheme == 'https' &&
          sourceUri.host.isNotEmpty &&
          sourceUri.userInfo.isEmpty
      ? sourceUri.host
      : null;
  final uncertain =
      summary.status == RestrictionDayStatus.unknown ||
      summary.status == RestrictionDayStatus.stale;

  return [
    loading
        ? 'Cargando cobertura'
        : failed
        ? 'Cobertura sin confirmar'
        : label,
    'Resultado para la categoría ${category.label} en $cityName',
    '${loading ? 'Fecha de consulta' : 'Fecha evaluada'}: $dateLabel',
    ...details,
    if (informational) 'Consulta informativa; no confirma si puede circular',
    if (failed) 'No se pudo cargar la cobertura; el estado no está confirmado',
    if (!loading && uncertain) 'El estado de circulación no está confirmado',
    if (sourceHost != null) 'Fuente: $sourceHost',
    if (summary.verifiedAt != null)
      'Última verificación: ${_longCityDate(summary.verifiedAt!)}',
  ].join('. ');
}

String _longCityDate(DateTime date) =>
    '${_weekday(date)} ${date.day} de ${_monthName(date.month).toLowerCase()} de ${date.year}';

class _CityWave extends CustomClipper<Path> {
  const _CityWave();
  @override
  Path getClip(Size s) => Path()
    ..moveTo(0, s.height * .25)
    ..cubicTo(
      s.width * .20,
      -s.height * .6,
      s.width * .42,
      s.height * 1.3,
      s.width,
      s.height * .6,
    )
    ..lineTo(s.width, s.height)
    ..lineTo(0, s.height)
    ..close();
  @override
  bool shouldReclip(_CityWave oldClipper) => false;
}

class _CityWeek extends StatelessWidget {
  const _CityWeek({
    required this.week,
    required this.now,
    required this.showDates,
    required this.basis,
    required this.onRules,
  });
  final _CityWeekData week;
  final DateTime now;
  final bool showDates;
  final String basis;
  final VoidCallback onRules;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('pico-city-week-card'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LayoutBuilder(
        builder: (context, bounds) {
          final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.55;
          final heading = Text('Esta semana', style: AppTextStyles.h2);
          final action = Semantics(
            label: 'Ver regla y vigencia. $basis',
            button: true,
            excludeSemantics: true,
            child: TextButton(
              onPressed: onRules,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                foregroundColor: AppColors.teal,
              ),
              child: Text(
                largeText ? 'Ver regla ›' : '$basis ›',
                textAlign: largeText ? TextAlign.left : TextAlign.right,
                style: AppTextStyles.bodyStrong.copyWith(
                  fontSize: 14,
                  color: AppColors.teal,
                ),
              ),
            ),
          );
          if (MediaQuery.textScalerOf(context).scale(1) > 1.25) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, action],
            );
          }
          return Row(
            children: [
              Expanded(child: heading),
              Expanded(child: action),
            ],
          );
        },
      ),
      LayoutBuilder(
        builder: (context, bounds) {
          var minWidth = 48.0;
          final style = AppTextStyles.bodyStrong.copyWith(fontSize: 18);
          for (final day in week.days) {
            final label = _cityDayText(day);
            for (final word in label.split(' ')) {
              final width = _cityTextSize(context, word, style).width + 12;
              if (width > minWidth) minWidth = width;
            }
            if (day.status == RestrictionDayStatus.restricted ||
                day.publishedScheduleInformational) {
              final width = (_cityTextSize(context, label, style).width + 12)
                  .clamp(48.0, (bounds.maxWidth - 6) / 2);
              if (width > minWidth) minWidth = width;
            }
          }
          final columns = ((bounds.maxWidth + 6) / (minWidth + 6))
              .floor()
              .clamp(1, 5);
          final width = (bounds.maxWidth - (columns - 1) * 6) / columns;
          return Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var index = 0; index < 7; index++)
                SizedBox(
                  width: width,
                  child: _CityDayCell(
                    day: week.days[index],
                    index: index,
                    today: _isSameDay(week.days[index].date, now),
                    showDate: showDates,
                    weekend: index > 4,
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}

class _CityDayCell extends StatelessWidget {
  const _CityDayCell({
    required this.day,
    required this.index,
    required this.today,
    required this.showDate,
    this.weekend = false,
  });
  final CityRestrictionDaySummary day;
  final int index;
  final bool today, showDate, weekend;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(day.status);
    final value = _cityDayText(day, weekend: weekend);
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.55;
    final restricted = day.status == RestrictionDayStatus.restricted;
    final scheduleShown = restricted || day.publishedScheduleInformational;
    return Semantics(
      label:
          '${today ? 'Hoy. ' : ''}${_shortDate(day.date)}, '
          '${day.publishedScheduleInformational ? 'calendario oficial publicado, consulta informativa; no confirma circulación' : _dailyStatusText(day.status)}, $value'
          '${day.effectiveWindows.isEmpty ? '' : ', ${_windows(day.effectiveWindows)}'}',
      button: true,
      excludeSemantics: true,
      child: Material(
        color: Color.alphaBlend(color.withValues(alpha: .075), Colors.white),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: ValueKey('pico-city-week-day-$index'),
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showCityDay(context, day),
          child: Container(
            constraints: BoxConstraints(minHeight: weekend ? 48 : 56),
            padding: EdgeInsets.symmetric(
              horizontal: weekend ? 12 : 5,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: today ? AppColors.navy : color.withValues(alpha: .22),
                width: today ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: weekend
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Text(
                  '${_weekday(day.date)}${showDate ? ' ${day.date.day}' : ''}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyStrong.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  textAlign: weekend ? TextAlign.left : TextAlign.center,
                  style: AppTextStyles.bodyStrong.copyWith(
                    fontSize: scheduleShown
                        ? largeText
                              ? 14
                              : 18
                        : largeText
                        ? 13
                        : 14,
                    color: color,
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

class _CitySchedule extends StatelessWidget {
  const _CitySchedule({required this.week});
  final _CityWeekData week;
  @override
  Widget build(BuildContext context) {
    final groups = week.schedules;
    final informational = week.days.any(
      (day) => day.publishedScheduleInformational,
    );
    final uncertain = week.days.any(
      (d) =>
          d.status == RestrictionDayStatus.unknown ||
          d.status == RestrictionDayStatus.stale,
    );
    return Container(
      key: const ValueKey('pico-city-schedule'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.alarm_rounded, color: AppColors.navy, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (groups.isEmpty)
                  Text(
                    uncertain
                        ? 'Horario por verificar'
                        : 'Sin restricción esta semana',
                    style: AppTextStyles.bodyStrong.copyWith(fontSize: 14),
                  )
                else ...[
                  Text(
                    informational
                        ? 'Horario publicado · consulta informativa'
                        : 'Horario de aplicación',
                    style: AppTextStyles.caption.copyWith(fontSize: 14),
                  ),
                  for (final group in groups)
                    LayoutBuilder(
                      builder: (context, bounds) {
                        final textStyle = AppTextStyles.bodyStrong.copyWith(
                          fontSize: 14,
                        );
                        final needed =
                            _cityTextSize(
                              context,
                              group.hours,
                              textStyle,
                            ).width +
                            _cityTextSize(
                              context,
                              group.days,
                              textStyle,
                            ).width +
                            12;
                        if (needed > bounds.maxWidth) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(group.days, style: textStyle),
                              Text(group.hours, style: textStyle),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Text(group.days, style: textStyle),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                group.hours,
                                textAlign: TextAlign.right,
                                style: textStyle,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  if (uncertain)
                    Text(
                      'Hay días por verificar',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 14,
                        color: AppColors.orange,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CityAction extends StatelessWidget {
  const _CityAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    super.key,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  @override
  Widget build(BuildContext context) => Material(
    color: primary ? AppColors.teal : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: primary ? AppColors.teal : AppColors.border),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: primary ? Colors.white : AppColors.navy,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: primary ? Colors.white : AppColors.navy,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: primary ? Colors.white : AppColors.navy,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

List<Uri> _citySources(RestrictionRuleSet rules) {
  final unique = <String, Uri>{};
  for (final source in [
    ...rules.sourceUrls,
    ...rules.rules.map((r) => r.sourceUrl).whereType<String>(),
  ]) {
    final uri = Uri.tryParse(source);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      continue;
    }
    unique.putIfAbsent(uri.toString(), () => uri);
  }
  return unique.values.toList(growable: false);
}

String _citySourceName(RestrictionRuleSet rules) {
  final sources = _citySources(rules);
  if (sources.isEmpty) return 'Fuente por verificar';
  final host = sources.first.host;
  if (host == 'medellin.gov.co' || host == 'www.medellin.gov.co') {
    return 'Fuente: Alcaldía de Medellín';
  }
  return 'Fuente: $host';
}

class _CitySourceRow extends StatelessWidget {
  const _CitySourceRow({required this.ruleSet, required this.onTap});
  final RestrictionRuleSet ruleSet;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    key: const ValueKey('pico-city-source-row'),
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            const Icon(
              Icons.account_balance_outlined,
              color: AppColors.navy,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _citySourceName(ruleSet),
                    style: AppTextStyles.caption.copyWith(fontSize: 14),
                  ),
                  Text(
                    ruleSet.verifiedAt == null
                        ? 'Sin verificación registrada'
                        : 'Revisada el ${_shortDate(ruleSet.verifiedAt!)}',
                    style: AppTextStyles.caption.copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    ),
  );
}

void _showCityDay(BuildContext context, CityRestrictionDaySummary day) {
  final source = day.sourceUrl == null ? null : Uri.tryParse(day.sourceUrl!);
  final safeSource =
      source != null &&
          source.scheme == 'https' &&
          source.host.isNotEmpty &&
          source.userInfo.isEmpty
      ? source
      : null;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CitySheetBody(
      children: [
        Text(
          '${_weekday(day.date)} · ${_shortDate(day.date)}',
          style: AppTextStyles.h2,
        ),
        Text(
          _dailyStatusText(day.status),
          style: AppTextStyles.h2.copyWith(color: _statusColor(day.status)),
        ),
        if (!day.publishedScheduleInformational)
          Text(day.ruleLabel, style: AppTextStyles.body),
        if (day.publishedScheduleInformational) ...[
          const Text(
            'Calendario oficial publicado · consulta informativa. Este horario no confirma el resultado de circulación del vehículo.',
          ),
          Text(_digitsOrRule(day), style: AppTextStyles.bodyStrong),
          if (day.effectiveWindows.isNotEmpty)
            Text(
              _windows(day.effectiveWindows),
              style: AppTextStyles.bodyStrong,
            ),
          if (safeSource != null) ...[
            Text('Fuente oficial: ${safeSource.host}'),
            _CitySourceLink(uri: safeSource),
          ],
        ],
        if (day.status == RestrictionDayStatus.restricted)
          Text(
            day.effectiveWindows.isEmpty
                ? 'Horario por verificar'
                : _windows(day.effectiveWindows),
            style: AppTextStyles.bodyStrong,
          ),
        if (!day.publishedScheduleInformational &&
            (day.status == RestrictionDayStatus.unknown ||
                day.status == RestrictionDayStatus.stale))
          const Text('La cobertura disponible no permite confirmar este día.'),
      ],
    ),
  );
}

class _CitySheetBody extends StatelessWidget {
  const _CitySheetBody({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .8,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final child in children)
              Padding(padding: const EdgeInsets.only(bottom: 12), child: child),
          ],
        ),
      ),
    ),
  );
}

void _showCityRuleSheet(
  BuildContext context,
  RestrictionJurisdiction jurisdiction,
  RestrictionRuleSet rules,
  CityRestrictionRuleSummary summary, {
  required bool sources,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CityRuleSheet(
      jurisdiction: jurisdiction,
      rules: rules,
      summary: summary,
      sources: sources,
    ),
  );
}

class _CityRuleSheet extends StatefulWidget {
  const _CityRuleSheet({
    required this.jurisdiction,
    required this.rules,
    required this.summary,
    required this.sources,
  });
  final RestrictionJurisdiction jurisdiction;
  final RestrictionRuleSet rules;
  final CityRestrictionRuleSummary summary;
  final bool sources;
  @override
  State<_CityRuleSheet> createState() => _CityRuleSheetState();
}

class _CityRuleSheetState extends State<_CityRuleSheet> {
  late bool _sources = widget.sources;
  @override
  Widget build(BuildContext context) {
    final rules = widget.rules;
    final summary = widget.summary;
    return KeyedSubtree(
      key: const ValueKey('pico-city-rule-source-sheet'),
      child: _CitySheetBody(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('Regla y vigencia'),
                selected: !_sources,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: (_) => setState(() => _sources = false),
              ),
              ChoiceChip(
                label: const Text('Fuentes'),
                selected: _sources,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: (_) => setState(() => _sources = true),
              ),
            ],
          ),
          Text(widget.jurisdiction.name, style: AppTextStyles.h2),
          if (!_sources) ...[
            Text(
              '${summary.category.label} · ${_cityBasis(summary)}',
              style: AppTextStyles.bodyStrong,
            ),
            if (!summary.coverageKnown)
              const Text('Sin cobertura verificada')
            else if (summary.dataIsStale)
              const Text('Datos vencidos: requieren revisión.'),
            if (rules.coverageCompleteness == CoverageCompleteness.partial)
              const Text(
                'Cobertura parcial: estas reglas no confirman el resultado para los casos que no describen.',
              ),
            ...{for (final rule in rules.rules) rule.id: rule}.values.map(
              (rule) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_cityRuleText(rule), style: AppTextStyles.bodyStrong),
                  Text(
                    'Vigencia: ${_validity(rule.validFrom, rule.validUntil)}',
                  ),
                  Text(
                    rule.appliesOnHolidays
                        ? 'Aplica en festivos'
                        : rules.coverageCompleteness ==
                              CoverageCompleteness.partial
                        ? 'Festivos: dato no confirmado'
                        : 'No aplica en festivos',
                  ),
                ],
              ),
            ),
            if (rules.rules.isEmpty)
              const Text('No hay condiciones publicadas en esta cobertura.'),
          ] else ...[
            Text(_citySourceName(rules), style: AppTextStyles.bodyStrong),
            Text(
              rules.verifiedAt == null
                  ? 'Sin verificación registrada'
                  : 'Última verificación: ${_shortDate(rules.verifiedAt!)}',
            ),
            ...{
              for (final rule in rules.rules)
                _validity(rule.validFrom, rule.validUntil),
            }.map((value) => Text('Vigencia publicada: $value')),
            if (rules.staleAfter != null)
              Text('Revisión de datos: ${_shortDate(rules.staleAfter!)}'),
            const Text(
              'La fecha de revisión de datos no confirma un cambio de rotación.',
            ),
            for (final source in _citySources(rules))
              _CitySourceLink(uri: source),
            if (_citySources(rules).isEmpty)
              const Text('No hay enlaces verificables disponibles.'),
          ],
        ],
      ),
    );
  }
}

class _CitySourceLink extends StatefulWidget {
  const _CitySourceLink({required this.uri});
  final Uri uri;
  @override
  State<_CitySourceLink> createState() => _CitySourceLinkState();
}

class _CitySourceLinkState extends State<_CitySourceLink> {
  bool _opening = false, _failed = false;
  Future<void> _open() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _failed = false;
    });
    var opened = false;
    try {
      opened = await launchUrl(widget.uri);
    } catch (_) {
      opened = false;
    }
    if (mounted) {
      setState(() {
        _opening = false;
        _failed = !opened;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.uri.toString(),
        style: AppTextStyles.caption.copyWith(fontSize: 14),
      ),
      TextButton.icon(
        onPressed: _opening ? null : _open,
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        icon: const Icon(Icons.open_in_new),
        label: Text(
          _opening
              ? 'Abriendo…'
              : _failed
              ? 'Reintentar abrir fuente'
              : 'Abrir fuente',
        ),
      ),
      if (_failed)
        const Text(
          'No pudimos abrir el enlace. Comprueba tu conexión o reintenta.',
        ),
    ],
  );
}

typedef _CityVehicleSheetData = ({
  List<_VehicleShortcutData> items,
  List<_CategoryCoverage> coverages,
});

class _CityVehiclesSheet extends ConsumerStatefulWidget {
  const _CityVehiclesSheet({
    required this.load,
    required this.onVehicle,
    required this.onAdd,
  });
  final Future<_CityVehicleSheetData> Function() load;
  final ValueChanged<VehicleProfile> onVehicle;
  final VoidCallback onAdd;
  @override
  ConsumerState<_CityVehiclesSheet> createState() => _CityVehiclesSheetState();
}

class _CityVehiclesSheetState extends ConsumerState<_CityVehiclesSheet> {
  Object? _loadKey;
  Future<_CityVehicleSheetData>? _future;
  ProviderSubscription<int>? _expiry;
  int _revision = 0;

  @override
  void dispose() {
    _expiry?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final key = (
      ref.watch(bogotaDateProvider),
      ref.watch(bundledRestrictionsProvider),
      ref.watch(vehicleListProvider.future),
      _revision,
    );
    if (_loadKey != key) {
      _loadKey = key;
      _expiry?.close();
      _expiry = null;
      final instant = ref.read(currentInstantProvider);
      _future = widget.load().then((data) {
        if (mounted && _loadKey == key) {
          _expiry = _watchCoverageExpiry(
            ref,
            data.coverages.map((c) => c.ruleSet),
            instant,
            () => setState(() => _revision++),
          );
        }
        return data;
      });
    }
    return SafeArea(
      top: false,
      child: SizedBox(
        key: const ValueKey('pico-city-vehicles-sheet'),
        height: MediaQuery.sizeOf(context).height * .7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Mis vehículos', style: AppTextStyles.h2),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<_CityVehicleSheetData>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('No pudimos cargar tus vehículos.'),
                          TextButton(
                            onPressed: () {
                              ref.invalidate(vehicleListProvider);
                              setState(() => _revision++);
                            },
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    );
                  }
                  final items =
                      snapshot.data?.items ?? const <_VehicleShortcutData>[];
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length + 1,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      if (index == items.length) {
                        return _CityAction(
                          key: const ValueKey('pico-city-add-vehicle'),
                          icon: Icons.add,
                          label: 'Agregar vehículo',
                          onTap: widget.onAdd,
                        );
                      }
                      final item = items[index];
                      final vehicle = item.vehicle;
                      final name = vehicle.nickname?.trim();
                      final identity = name != null && name.isNotEmpty
                          ? name
                          : vehicleMakeModel(vehicle).isNotEmpty
                          ? vehicleMakeModel(vehicle)
                          : 'Mi vehículo';
                      return InkWell(
                        key: ValueKey('pico-city-vehicle-${vehicle.id}'),
                        onTap: () => widget.onVehicle(vehicle),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                    width: 64,
                                    height: 48,
                                    child: VehicleVisualImage(
                                      vehicle: vehicle,
                                      cacheWidth: 180,
                                      fallbackBuilder: (_) =>
                                          Icon(vehicleIcon(vehicle)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      identity,
                                      style: AppTextStyles.bodyStrong,
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  VehiclePlateBadge(
                                    vehicle: vehicle,
                                    compact: true,
                                  ),
                                  Text(
                                    _dailyStatusText(item.evaluation.status),
                                    style: AppTextStyles.body.copyWith(
                                      color: _statusColor(
                                        item.evaluation.status,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CityAdoptButton extends StatefulWidget {
  const _CityAdoptButton({required this.onAdopt});
  final Future<void> Function() onAdopt;
  @override
  State<_CityAdoptButton> createState() => _CityAdoptButtonState();
}

class _CityAdoptButtonState extends State<_CityAdoptButton> {
  bool _saving = false, _failed = false;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextButton.icon(
        key: const ValueKey('pico-city-adopt'),
        icon: const Icon(Icons.my_location_rounded),
        label: Text(_saving ? 'Guardando…' : 'Usar esta ciudad'),
        onPressed: _saving
            ? null
            : () async {
                setState(() {
                  _saving = true;
                  _failed = false;
                });
                try {
                  await widget.onAdopt();
                  if (context.mounted) Navigator.pop(context);
                } catch (_) {
                  if (mounted) {
                    setState(() {
                      _saving = false;
                      _failed = true;
                    });
                  }
                }
              },
      ),
      if (_failed)
        const Text('No pudimos guardar la ciudad. Puedes reintentar.'),
    ],
  );
}

class _CityEmptySelection extends StatelessWidget {
  const _CityEmptySelection({required this.invalid, required this.onSelect});
  final bool invalid;
  final VoidCallback onSelect;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const ColoredBox(color: AppColors.navy, child: _CityHeader()),
      Padding(
        padding: const EdgeInsets.all(16),
        child: _CityAction(
          key: const ValueKey('pico-city-change'),
          icon: Icons.location_on,
          label: 'Seleccionar ciudad',
          onTap: onSelect,
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          invalid
              ? 'No reconocemos la ciudad solicitada.'
              : 'Selecciona una ciudad para consultar su pico y placa.',
        ),
      ),
    ],
  );
}
