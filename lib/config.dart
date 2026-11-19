/// Réglages globaux de l'application.
class AppConfig {
  static const appName = 'Caillou';
  static const version = '0.2.0';

  /// Open Food Facts demande un User-Agent identifiant l'app et un contact.
  /// Remplacez l'URL par une adresse e-mail de contact avant une diffusion publique.
  static const userAgent = '$appName/$version (https://github.com/remigl/caillou)';

  /// En dessous de ce seuil, un aliment reconnu est marqué « à vérifier ».
  static const recognitionConfidenceThreshold = 0.60;

  /// Durée pendant laquelle un produit en cache est réutilisé sans appel réseau.
  static const productCacheFreshness = Duration(days: 7);
}
