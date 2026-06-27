#!/bin/bash
set -e

echo "=== C.A.P.S. - Setup ==="
echo ""

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo "ERREUR: Flutter n'est pas installé."
    echo "Installe Flutter: https://docs.flutter.dev/get-started/install"
    exit 1
fi

echo "[1/4] Génération des fichiers platform..."
flutter create . --project-name caps --org com.caps --platforms android,ios,web

echo ""
echo "[2/4] Installation des dépendances..."
flutter pub get

echo ""
echo "[3/4] Configuration Firebase..."
if command -v flutterfire &> /dev/null; then
    echo "Lance: flutterfire configure"
    echo "Puis remplace lib/config/firebase/firebase_options.dart"
else
    echo "ATTENTION: FlutterFire CLI non installé."
    echo "Installe-le: dart pub global activate flutterfire_cli"
    echo "Puis lance: flutterfire configure"
fi

echo ""
echo "[4/4] Setup Firestore..."
echo "Dans Firebase Console (https://console.firebase.google.com) :"
echo "  1. Active Authentication > Email/Password"
echo "  2. Crée Cloud Firestore (mode test pour commencer)"
echo "  3. Crée un utilisateur dans Authentication"
echo "  4. Ajoute un document dans Firestore:"
echo ""
echo "     Collection: users"
echo "     Document ID: <UID de l'utilisateur créé>"
echo "     Champs:"
echo "       email: 'ton@email.com'"
echo "       displayName: 'Amine'"
echo "       role: 'pilot'"
echo "       householdId: 'famille-bouchenafa'"
echo "       createdAt: <timestamp>"
echo ""
echo "=== Setup terminé ! ==="
echo "Lance: flutter run -d chrome   (web)"
echo "Lance: flutter run              (mobile)"
