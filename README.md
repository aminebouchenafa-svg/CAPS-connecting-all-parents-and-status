# C.A.P.S. - Connecting All Parents & Status

Cockpit Familial pour pilotes. Suivez votre statut opérationnel en temps réel et partagez un calendrier familial.

**Webapp PWA** : fonctionne sur iPhone, iPad, Android et desktop via le navigateur. S'installe comme une app native depuis Safari.

## Accéder à l'app (utilisateurs)

1. Ouvre **Safari** sur ton iPhone/iPad
2. Va sur : `https://caps-family-app.web.app`
3. Tape sur **Partager** (icône carré + flèche) → **Sur l'écran d'accueil**
4. L'app C.A.P.S. apparaît comme une app native

## Setup Firebase (une seule fois, depuis un ordi)

### 1. Créer le projet Firebase

1. Va sur [console.firebase.google.com](https://console.firebase.google.com)
2. Crée un projet nommé `caps-family-app`
3. Active **Authentication** > **Email/Password**
4. Crée **Cloud Firestore** > Démarrer en **mode test**

### 2. Créer les comptes

Dans Firebase Console > Authentication > Ajouter un utilisateur :
- `amine@example.com` (pilote)
- `amina@example.com` (conjointe)

### 3. Ajouter les profils Firestore

Dans Firestore > Créer une collection `users` :

**Document ID = UID d'Amine** (copié depuis Authentication) :
```json
{
  "email": "amine@example.com",
  "displayName": "Amine",
  "role": "pilot",
  "householdId": "famille-bouchenafa",
  "createdAt": "<timestamp>"
}
```

**Document ID = UID d'Amina** :
```json
{
  "email": "amina@example.com",
  "displayName": "Amina",
  "role": "spouse",
  "householdId": "famille-bouchenafa",
  "createdAt": "<timestamp>"
}
```

### 4. Configurer et déployer (depuis un ordi)

```bash
git clone https://github.com/aminebouchenafa-svg/caps-connecting-all-parents-and-status.git
cd caps-connecting-all-parents-and-status
git checkout claude/caps-flutter-architecture-bqskkk

# Setup Flutter
flutter create . --project-name caps --platforms web
flutter pub get

# Connecter Firebase
dart pub global activate flutterfire_cli
flutterfire configure

# Build et déployer
flutter build web --release --web-renderer canvaskit
firebase deploy --only hosting
```

L'app est maintenant en ligne sur `https://caps-family-app.web.app`

### 5. Déploiement automatique (optionnel)

Le workflow GitHub Actions (`.github/workflows/deploy.yml`) déploie automatiquement à chaque push. Pour l'activer :

1. Dans Firebase Console > Paramètres > Comptes de service > Générer une clé
2. Dans GitHub > Settings > Secrets > Ajouter `FIREBASE_SERVICE_ACCOUNT` avec la clé JSON

## Architecture

```
lib/
├── config/         # Firebase config + Routes (GoRouter)
├── core/           # Theme, widgets réutilisables, erreurs, extensions
└── features/
    ├── auth/       # Authentification Email/Password
    ├── dashboard/  # Statut pilote temps réel + countdown
    └── calendar/   # Calendrier familial partagé
```

Chaque feature : `domain/` (entities, repositories) → `data/` (models, datasources) → `presentation/` (pages, providers, widgets)

## Stack

- **Flutter 3.29+** / Dart 3.7+
- **Firebase** (Auth, Firestore, Hosting)
- **Riverpod** (state management)
- **GoRouter** (navigation)
- **PWA** (installable sur iOS/Android)
- **Clean Architecture**
