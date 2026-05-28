/// Poste d'entretien préconfiguré (bibliothèque §5.6). Sert à **initialiser le
/// catalogue** d'un utilisateur et à **suggérer des intervalles** à l'émergence
/// d'un plan récurrent (cf. saisie d'opération).
class CatalogDefault {
  final String name;
  final int? defaultIntervalKm;
  final int? defaultIntervalMonths;

  const CatalogDefault(
    this.name, {
    this.defaultIntervalKm,
    this.defaultIntervalMonths,
  });
}

/// Catalogue de référence (vidange, filtres, freins, distribution, CT…).
const catalogDefaults = <CatalogDefault>[
  CatalogDefault('Vidange', defaultIntervalKm: 15000, defaultIntervalMonths: 12),
  CatalogDefault('Filtre à air', defaultIntervalKm: 30000),
  CatalogDefault('Filtre habitacle', defaultIntervalMonths: 12),
  CatalogDefault('Plaquettes de frein', defaultIntervalKm: 40000),
  CatalogDefault('Distribution', defaultIntervalKm: 100000, defaultIntervalMonths: 120),
  CatalogDefault('Pneumatiques', defaultIntervalKm: 40000),
  CatalogDefault('Contrôle technique', defaultIntervalMonths: 24),
];
