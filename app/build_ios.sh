#!/bin/bash
set -e

echo "=========================================="
echo "🍏 iOS Build & Archive Script "
echo "=========================================="

# 1. Flutter önbelleğini temizle (Eski sürüm numaralarından kurtulmak için)
echo "🧹 1/4 - Önbellek temizleniyor (flutter clean)..."
flutter clean

# 2. Paketleri yeniden indir
echo "📦 2/4 - Paketler alınıyor (flutter pub get)..."
flutter pub get

# 3. iOS için release build al. (Bu adım pubspec.yaml'daki yeni sürümü Info.plist ve xcconfig dosyalarına otomatik yazar)
echo "🔨 3/4 - iOS Release derlemesi yapılıyor (Sürüm numaraları güncelleniyor)..."
flutter build ios --release --no-codesign

# 4. Xcode'u açarak Arşivleme (Archive) işlemi için hazır hale getir
echo "🚀 4/4 - Derleme başarılı! Xcode projesi açılıyor..."
open ios/Runner.xcworkspace

echo "=========================================="
echo "✅ Bitti! Şimdi Xcode üzerinden 'Product' -> 'Archive' tıklayarak yeni sürümle gönderim yapabilirsiniz."
echo "=========================================="
