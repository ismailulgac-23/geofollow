#!/bin/bash
set -e

echo "🔙 1/3 - Önceden yapılmış hatalı commit'leri geçmişten temizliyoruz..."
git reset --soft origin/main

echo "🧹 2/3 - JSON key gibi gizli dosyaları dizinden çıkarıyoruz..."
git rm -r --cached api/src/config/service-account.json 2>/dev/null || true
git add .

echo "📝 3/3 - Commit oluşturuluyor ve Force Push yapılıyor..."
git commit -m "update code and secure secrets" || true
git push origin HEAD --force

echo "✅ Başarılı! Tüm backend güncellemelerin tertemiz bir şekilde GitHub'a iletildi."
